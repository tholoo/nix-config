#!/usr/bin/python3
"""Privileged guest management. Repository details are never part of the Nix build."""

import fcntl
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import uuid
from pathlib import Path

STATE = Path("/var/lib/home-ci")
CONFIG = Path("/etc/home-ci.json")
UNIT_DIR = Path("/etc/systemd/system")
CACHE = Path("/var/cache/home-ci/downloads")


def worker_environment(path):
    return {
        "HOME": str(path / "home"),
        "DOCKER_CONFIG": str(path / ".docker"),
        "UV_CACHE_DIR": "/var/cache/home-ci/uv",
        "UV_PYTHON_INSTALL_DIR": "/var/cache/home-ci/python",
    }


def configure_worker(path, settings):
    (path / "home").mkdir(mode=0o750, parents=True, exist_ok=True)
    docker = path / ".docker" / "config.json"
    config = json.loads(docker.read_text()) if docker.exists() else {}
    proxies = config.setdefault("proxies", {})
    if settings.get("proxy"):
        proxies["default"] = {
            "httpProxy": settings["proxy"],
            "httpsProxy": settings["proxy"],
            "noProxy": "localhost,127.0.0.1,::1",
        }
    else:
        proxies.pop("default", None)
    write_private(docker, config)
    run(
        [
            "chown",
            "-R",
            "ci-runner:ci-runner",
            str(path / "home"),
            str(path / ".docker"),
        ]
    )


def run(args, **kwargs):
    return subprocess.run(args, check=True, text=True, **kwargs)


def runner_id(repository):
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repository):
        raise ValueError("Expected owner/repository.")
    return hashlib.sha256(repository.lower().encode()).hexdigest()[:20]


def write_private(path, value):
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    pending = path.with_suffix(".pending")
    pending.write_text(json.dumps(value))
    pending.chmod(0o600)
    pending.replace(path)


def proxy():
    settings = json.loads(CONFIG.read_text())
    url = settings.get("proxy", "")
    STATE.mkdir(mode=0o700, parents=True, exist_ok=True)
    # GitHub validates listing access to every runner ancestor, not only
    # traversal. Private file contents remain root-owned and mode 0600.
    STATE.chmod(0o755)
    variables = {
        "http_proxy": url,
        "https_proxy": url,
        "HTTP_PROXY": url,
        "HTTPS_PROXY": url,
        "no_proxy": "localhost,127.0.0.1,::1",
        "NO_PROXY": "localhost,127.0.0.1,::1",
    }
    # Validate at the host boundary; keep proxy values out of unit text and logs.
    env = (
        "\n".join(f"{key}={json.dumps(value)}" for key, value in variables.items())
        + "\n"
    )
    (STATE / "proxy.env").write_text(env)
    (STATE / "proxy.env").chmod(0o600)
    apt = Path("/etc/apt/apt.conf.d/80-home-ci-proxy")
    apt.write_text(
        f'Acquire::http::Proxy "{url}";\nAcquire::https::Proxy "{url}";\n'
        if url
        else ""
    )
    apt.chmod(0o600)
    dropin = Path("/etc/systemd/system/docker.service.d")
    dropin.mkdir(parents=True, exist_ok=True)
    (dropin / "home-ci.conf").write_text(
        "[Service]\nEnvironmentFile=/var/lib/home-ci/proxy.env\n"
    )
    registry = STATE / "registrations.json"
    if registry.exists():
        for ident in json.loads(registry.read_text()):
            path = STATE / "runners" / ident
            configure_worker(path, settings)
            write_unit(path, UNIT_DIR / f"home-ci-runner-{ident}.service")


def install_runner(path, settings):
    if (path / "run.sh").exists():
        return
    version = settings["runnerVersion"]
    url = f"https://github.com/actions/runner/releases/download/v{version}/actions-runner-linux-x64-{version}.tar.gz"
    env = os.environ.copy()
    if settings.get("proxy"):
        env.update(https_proxy=settings["proxy"], http_proxy=settings["proxy"])
    CACHE.mkdir(mode=0o700, parents=True, exist_ok=True)
    archive = CACHE / f"runner-{version}.tar.gz"
    if not archive.exists():
        pending = archive.with_suffix(".pending")
        run(
            [
                "curl",
                "--fail",
                "--location",
                "--silent",
                "--show-error",
                "--retry",
                "5",
                "--output",
                str(pending),
                url,
            ],
            env=env,
        )
        with pending.open("rb") as stream:
            if (
                hashlib.file_digest(stream, "sha256").hexdigest()
                != settings["runnerSha256"]
            ):
                raise ValueError("Runner download checksum mismatch.")
        pending.replace(archive)
    with archive.open("rb") as stream:
        if (
            hashlib.file_digest(stream, "sha256").hexdigest()
            != settings["runnerSha256"]
        ):
            raise ValueError(
                "Cached runner checksum mismatch; remove the damaged archive explicitly."
            )
    # Extract atomically so an interruption cannot leave a partial installation
    # that a later add mistakes for a complete runner.
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".install-", dir=path.parent) as directory:
        extracted = Path(directory) / "runner"
        extracted.mkdir()
        with tarfile.open(archive) as bundle:
            bundle.extractall(extracted, filter="data")
        if path.exists():
            raise ValueError(
                "Incomplete runner directory exists; inspect it before retrying."
            )
        extracted.replace(path)
    run(["chown", "-R", "ci-runner:ci-runner", str(path)])


def as_runner(path, args):
    settings = json.loads(CONFIG.read_text())
    env = os.environ.copy()
    env.update(worker_environment(path))
    env.update(USER="ci-runner", LOGNAME="ci-runner")
    if settings.get("proxy"):
        env.update(http_proxy=settings["proxy"], https_proxy=settings["proxy"])
    # GitHub's config script requires its short-lived token as an argument.
    # Capture its output so neither tokens nor private repository URLs reach logs.
    return run(
        ["runuser", "--preserve-environment", "-u", "ci-runner", "--", *args],
        cwd=path,
        env=env,
        capture_output=True,
    )


def write_unit(path, unit_path):
    unit_path.write_text(f"""[Unit]
Description=GitHub Actions runner
Requires=home-ci-bootstrap.service docker.service
After=home-ci-bootstrap.service docker.service network-online.target
[Service]
User=ci-runner
Group=ci-runner
SupplementaryGroups=docker
WorkingDirectory={path}
Environment=HOME={path}/home
Environment=DOCKER_CONFIG={path}/.docker
Environment=UV_CACHE_DIR=/var/cache/home-ci/uv
Environment=UV_PYTHON_INSTALL_DIR=/var/cache/home-ci/python
Environment=ACTIONS_RUNNER_HOOK_JOB_STARTED=/usr/local/lib/home-ci/job-start.sh
EnvironmentFile=/var/lib/home-ci/proxy.env
ExecStart={path}/run.sh
Restart=always
RestartSec=5
KillSignal=SIGINT
KillMode=mixed
TimeoutStopSec=300
[Install]
WantedBy=multi-user.target
""")


def doctor(network=False):
    settings = json.loads(CONFIG.read_text())
    env = os.environ.copy()
    if settings.get("proxy"):
        env.update(http_proxy=settings["proxy"], https_proxy=settings["proxy"])
    checks = []

    def check(name, argv, timeout=30, statuses=None, **kwargs):
        try:
            result = subprocess.run(
                argv, text=True, capture_output=True, timeout=timeout, env=env, **kwargs
            )
            ok = result.returncode == 0 and (
                statuses is None or result.stdout.strip() in statuses
            )
        except (OSError, subprocess.TimeoutExpired):
            ok = False
        checks.append({"check": name, "ok": ok})
        return ok

    checks.append({"check": "bootstrap", "ok": (STATE / "bootstrap-ready").exists()})
    check("docker", ["docker", "info", "--format", "{{.ServerVersion}}"])
    check("buildx", ["docker", "buildx", "version"])
    # Match the runner's parent-directory validation as its actual service user.
    # Report only success/failure; never expose directory contents or private logs.
    runner_root = STATE / "runners"
    runner_paths = [
        runner_root,
        *sorted(p for p in runner_root.glob("*") if p.is_dir()),
    ]
    check(
        "runner-directory-access",
        [
            "runuser",
            "-u",
            "ci-runner",
            "--",
            sys.executable,
            "-c",
            "import os, sys\n"
            "from pathlib import Path\n"
            "for argument in sys.argv[1:]:\n"
            "    path = Path(argument)\n"
            "    for directory in (path, *path.parents):\n"
            "        with os.scandir(directory) as entries:\n"
            "            next(entries, None)\n",
            *map(str, runner_paths),
        ],
    )
    if network:
        for name, url, statuses in [
            ("github", "https://api.github.com", {"200"}),
            ("python-packages", "https://pypi.org/simple/pip/", {"200"}),
            ("container-registry", "https://ghcr.io/v2/", {"200", "401"}),
        ]:
            check(
                name,
                [
                    "curl",
                    "--silent",
                    "--output",
                    "/dev/null",
                    "--write-out",
                    "%{http_code}",
                    "--max-time",
                    "20",
                    url,
                ],
                statuses=statuses,
            )
        ident = "home-ci-probe-" + uuid.uuid4().hex[:12]
        # Exercise the same wrapper, client proxy file and container driver that
        # Actions uses. Keep all diagnostics private; publish no registry image.
        with tempfile.TemporaryDirectory(prefix="home-ci-probe-") as directory:
            context = Path(directory)
            env["DOCKER_CONFIG"] = str(context / ".docker")
            client = {
                "proxies": {
                    "default": {
                        "httpProxy": settings.get("proxy", ""),
                        "httpsProxy": settings.get("proxy", ""),
                        "noProxy": "localhost,127.0.0.1,::1",
                    }
                }
            }
            write_private(context / ".docker/config.json", client)
            (context / ".dockerignore").write_text(".docker\n")
            (context / "Dockerfile").write_text(
                "FROM alpine:3.22\nRUN wget -q -O /dev/null https://pypi.org/simple/pip/\n"
            )
            try:
                ready = check(
                    "container-builder",
                    [
                        "docker",
                        "buildx",
                        "create",
                        "--name",
                        ident,
                        "--driver",
                        "docker-container",
                        "--bootstrap",
                    ],
                    timeout=180,
                )
                if ready:
                    check(
                        "container-build-network",
                        [
                            "docker",
                            "buildx",
                            "build",
                            "--builder",
                            ident,
                            "--load",
                            "--progress=quiet",
                            "--tag",
                            f"{ident}:check",
                            str(context),
                        ],
                        timeout=240,
                    )
            finally:
                for argv in [
                    ["docker", "buildx", "rm", "--force", ident],
                    ["docker", "image", "rm", f"{ident}:check"],
                ]:
                    try:
                        subprocess.run(argv, env=env, capture_output=True, timeout=60)
                    except (OSError, subprocess.TimeoutExpired):
                        checks.append({"check": "probe-cleanup", "ok": False})
    report = {
        "cpus": os.cpu_count(),
        "disk_free_gib": round(shutil.disk_usage(STATE).free / 2**30, 1),
        "proxy_configured": bool(settings.get("proxy")),
        "checks": checks,
    }
    print(json.dumps(report, indent=2))
    if any(not item["ok"] for item in checks):
        raise ValueError("Some diagnostics failed.")


def request(payload):
    registry_path = STATE / "registrations.json"
    registry = json.loads(registry_path.read_text()) if registry_path.exists() else {}
    operation = payload["operation"]
    if operation == "doctor":
        doctor(payload.get("network", False))
        return
    if operation == "list":
        result = []
        for ident, repository in registry.items():
            status = subprocess.run(
                ["systemctl", "is-active", f"home-ci-runner-{ident}"],
                capture_output=True,
                text=True,
            ).stdout.strip()
            result.append(
                {
                    "repository": repository,
                    "service": status,
                    "label": "home-ci",
                    "worker": ident,
                }
            )
        print(json.dumps(result, indent=2))
        return
    if operation not in {"add", "remove"}:
        raise ValueError("Unsupported operation.")
    repository = payload["repository"]
    prefix = runner_id(repository) + "-"
    workers = payload.get("workers", 2)
    if type(workers) is not int or not 1 <= workers <= 4:
        raise ValueError("Choose between one and four runner workers.")
    if operation == "add":
        identities = [prefix + str(worker) for worker in range(1, workers + 1)]
    else:
        identities = [
            ident
            for ident, repo in registry.items()
            if repo.lower() == repository.lower()
        ]
        if not identities:
            raise ValueError("This repository is not registered here.")
    for ident in identities:
        manage_one(payload, registry_path, registry, ident)


def manage_one(payload, registry_path, registry, ident):
    operation = payload["operation"]
    repository = payload["repository"]
    path = STATE / "runners" / ident
    unit_name = f"home-ci-runner-{ident}.service"
    unit_path = UNIT_DIR / unit_name
    if operation == "add":
        if ident in registry:
            try:
                run(
                    ["systemctl", "is-active", "--quiet", unit_name],
                    capture_output=True,
                )
            except subprocess.CalledProcessError:
                configure_worker(path, json.loads(CONFIG.read_text()))
                write_unit(path, unit_path)
                run(["systemctl", "daemon-reload"])
                run(["systemctl", "enable", "--now", unit_name])
            print("This repository is already registered.")
            return
        if not (STATE / "bootstrap-ready").exists():
            raise ValueError("Guest setup is not ready; check home-ci status.")
        install_runner(path, json.loads(CONFIG.read_text()))
        configure_worker(path, json.loads(CONFIG.read_text()))
        if (path / ".runner").exists():
            receipt = json.loads((path / ".runner").read_text())
            if (
                receipt.get("gitHubUrl", "").rstrip("/").lower()
                != f"https://github.com/{repository}".lower()
                or receipt.get("agentName") != f"home-ci-{ident}"
                or not (path / ".credentials").exists()
            ):
                raise ValueError(
                    "An inconsistent registration exists; inspect the guest before retrying."
                )
        else:
            as_runner(
                path,
                [
                    "./config.sh",
                    "--unattended",
                    "--url",
                    f"https://github.com/{repository}",
                    "--token",
                    payload["token"],
                    "--name",
                    f"home-ci-{ident}",
                    "--labels",
                    "home-ci",
                    "--work",
                    "_work",
                ],
            )
        registry[ident] = repository
        write_private(registry_path, registry)
        write_unit(path, unit_path)
        run(["systemctl", "daemon-reload"])
        run(["systemctl", "enable", "--now", unit_name])
        print("Runner registered with label home-ci.")
    else:
        if ident not in registry:
            raise ValueError("This repository is not registered here.")
        run(["systemctl", "stop", unit_name])
        as_runner(
            path, ["./config.sh", "remove", "--unattended", "--token", payload["token"]]
        )
        run(["systemctl", "disable", unit_name])
        unit_path.unlink()
        run(["systemctl", "daemon-reload"])
        del registry[ident]
        write_private(registry_path, registry)
        print("Runner removed. Its work directory is retained for explicit cleanup.")


def main():
    os.umask(0o077)
    if sys.argv[1:] == ["proxy"]:
        proxy()
    elif sys.argv[1:] == ["resume"]:
        registry = STATE / "registrations.json"
        if registry.exists():
            for ident in json.loads(registry.read_text()):
                run(
                    [
                        "systemctl",
                        "start",
                        "--no-block",
                        f"home-ci-runner-{ident}.service",
                    ]
                )
    elif sys.argv[1:] == ["request"]:
        if not STATE.exists():
            raise ValueError("Guest bootstrap has not started.")
        with (STATE / "management.lock").open("w") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            request(json.load(sys.stdin))
    else:
        raise ValueError("Unknown guest command.")


if __name__ == "__main__":
    try:
        main()
    except (KeyError, ValueError, OSError, subprocess.CalledProcessError):
        print(
            "home-ci: guest operation failed; inspect bootstrap/service status inside the VM.",
            file=sys.stderr,
        )
        sys.exit(1)
