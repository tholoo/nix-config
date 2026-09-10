"""Generic VM lifecycle and private GitHub runner registration."""

import argparse
import getpass
import json
import os
import re
import shlex
import socket
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlsplit, urlunsplit


def run(args, **kwargs):
    return subprocess.run(args, check=True, text=True, **kwargs)


def validate_repo(value):
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", value):
        raise ValueError("Expected an owner/repository name.")
    return value


def validate_proxy(value):
    if not isinstance(value, str):
        raise ValueError("Proxy must be a URL string.")
    if value and (
        urlsplit(value).scheme not in {"http", "https"}
        or not urlsplit(value).hostname
        or any(c in value for c in '\r\n"\\')
    ):
        raise ValueError(
            "Proxy must be an HTTP(S) URL without quotes, backslashes or newlines."
        )
    return value


def proxy_from_environment(environ):
    value = next(
        (
            environ[key]
            for key in ["https_proxy", "HTTPS_PROXY", "http_proxy", "HTTP_PROXY"]
            if environ.get(key)
        ),
        "",
    )
    if not value:
        raise ValueError("No HTTP(S) proxy is set in this shell.")
    parsed = urlsplit(validate_proxy(value))
    if parsed.hostname in {"localhost", "127.0.0.1", "::1"}:
        credentials = (
            parsed.netloc.rsplit("@", 1)[0] + "@" if "@" in parsed.netloc else ""
        )
        netloc = credentials + "10.0.2.2" + (f":{parsed.port}" if parsed.port else "")
        value = urlunsplit(parsed._replace(netloc=netloc))
    return value


def private_run(cfg, action, payload=None):
    # The GitHub credential stays in the invoking user's gh credential store.
    # Only short-lived registration/removal tokens cross stdin into the VM.
    return run(
        [
            "/run/wrappers/bin/sudo",
            "-u",
            "home-ci",
            "--",
            sys.executable,
            __file__,
            "--config",
            os.environ["HOME_CI_CONFIG"],
            action,
        ],
        input=json.dumps(payload) if payload is not None else None,
    )


def ssh(cfg, command, payload=None):
    state = Path(cfg["stateDir"])
    return run(
        [
            cfg.get("ssh", "ssh"),
            "-F",
            "/dev/null",
            "-i",
            str(state / "admin-key"),
            "-p",
            str(cfg["sshPort"]),
            "-o",
            "BatchMode=yes",
            "-o",
            "ConnectTimeout=10",
            "-o",
            "IdentitiesOnly=yes",
            "-o",
            "StrictHostKeyChecking=yes",
            "-o",
            f"UserKnownHostsFile={state / 'known_hosts'}",
            "ci-admin@127.0.0.1",
            shlex.join(command),
        ],
        input=json.dumps(payload) if payload is not None else None,
    )


def prepare(cfg):
    state = Path(cfg["stateDir"])
    state.mkdir(mode=0o700, parents=True, exist_ok=True)
    os.umask(0o077)
    for name in ["admin-key", "guest-key"]:
        key = state / name
        if not key.exists():
            run(["ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-f", str(key)])
    host_key = (state / "guest-key.pub").read_text().split()
    (state / "known_hosts").write_text(
        f"[127.0.0.1]:{cfg['sshPort']} {host_key[0]} {host_key[1]}\n"
    )
    disk = state / "ubuntu.qcow2"
    if not disk.exists():
        # Atomic publication prevents an interrupted first copy from becoming
        # an apparently valid persistent disk. Never recreate an existing disk.
        pending = state / "ubuntu.qcow2.pending"
        run(["cp", "--reflink=auto", cfg["image"], str(pending)])
        pending.chmod(0o600)
        run(["qemu-img", "resize", str(pending), f"{cfg['diskGiB']}G"])
        pending.replace(disk)
    private_path = (
        Path(os.environ["CREDENTIALS_DIRECTORY"]) / "settings"
        if cfg.get("settingsFile")
        else state / "settings.json"
    )
    if cfg.get("settingsFile") and not private_path.exists():
        raise ValueError("The configured private settings credential is missing.")
    private = json.loads(private_path.read_text()) if private_path.exists() else {}
    proxy = validate_proxy(private.get("proxy", ""))
    seed = state / "seed"
    seed.mkdir(exist_ok=True, mode=0o700)
    unit = """[Unit]
Description=Reconcile Ubuntu CI guest configuration
Wants=network-online.target
After=network-online.target
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash -c 'mkdir -p /mnt/home-ci; mountpoint -q /mnt/home-ci || mount -o ro /dev/disk/by-label/CIDATA /mnt/home-ci; exec /bin/bash /mnt/home-ci/bootstrap.sh'
TimeoutStartSec=1800
Restart=on-failure
RestartSec=30
[Install]
WantedBy=multi-user.target
"""
    (seed / "bootstrap.service").write_text(unit)
    cloud = {
        "hostname": "home-ci",
        "manage_etc_hosts": True,
        "ssh_pwauth": False,
        "disable_root": True,
        "ssh_keys": {
            "ed25519_private": (state / "guest-key").read_text(),
            "ed25519_public": (state / "guest-key.pub").read_text(),
        },
        "users": [
            {
                "name": "ci-admin",
                "shell": "/bin/bash",
                "sudo": "ALL=(ALL) NOPASSWD:ALL",
                "lock_passwd": True,
                "ssh_authorized_keys": [(state / "admin-key.pub").read_text().strip()],
            }
        ],
        "write_files": [
            {
                "path": "/etc/systemd/system/home-ci-bootstrap.service",
                "content": unit,
                "permissions": "0644",
            }
        ],
        "runcmd": [
            ["systemctl", "daemon-reload"],
            ["systemctl", "enable", "--now", "--no-block", "home-ci-bootstrap.service"],
        ],
    }
    (seed / "user-data").write_text("#cloud-config\n" + json.dumps(cloud))
    (seed / "meta-data").write_text(json.dumps({"instance-id": "home-ci-v1"}))
    (seed / "guest.py").write_text(Path(cfg["guest"]).read_text())
    (seed / "bootstrap.sh").write_text(Path(cfg["bootstrap"]).read_text())
    (seed / "docker.py").write_text(Path(cfg["dockerWrapper"]).read_text())
    (seed / "job-start.sh").write_text(Path(cfg["jobHook"]).read_text())
    (seed / "guest-settings.json").write_text(
        json.dumps(
            {
                "proxy": proxy,
                "runnerVersion": cfg["runnerVersion"],
                "runnerSha256": cfg["runnerSha256"],
            }
        )
    )
    run(
        [
            "genisoimage",
            "-quiet",
            "-output",
            str(state / "seed.iso"),
            "-volid",
            "CIDATA",
            "-joliet",
            "-rock",
            str(seed),
        ]
    )


def vm_command(cfg):
    state = Path(cfg["stateDir"])
    return [
        "qemu-system-x86_64",
        "-name",
        "home-ci",
        "-enable-kvm",
        "-machine",
        "q35",
        "-cpu",
        "host",
        "-smp",
        str(cfg["cpus"]),
        "-m",
        str(cfg["memoryMiB"]),
        "-display",
        "none",
        "-serial",
        f"file:{state / 'console.log'}",
        "-monitor",
        "none",
        "-qmp",
        f"unix:{state / 'qmp.sock'},server=on,wait=off",
        "-drive",
        f"file={state / 'ubuntu.qcow2'},format=qcow2,if=virtio",
        "-drive",
        f"file={state / 'seed.iso'},format=raw,media=cdrom,readonly=on",
        "-netdev",
        f"user,id=net0,hostfwd=tcp:127.0.0.1:{cfg['sshPort']}-:22",
        "-device",
        "virtio-net-pci,netdev=net0",
        "-device",
        "virtio-rng-pci",
    ]


def poweroff(cfg):
    with socket.socket(socket.AF_UNIX) as sock:
        sock.settimeout(10)
        sock.connect(str(Path(cfg["stateDir"]) / "qmp.sock"))
        stream = sock.makefile("rwb")
        stream.readline()
        for action in ["qmp_capabilities", "system_powerdown"]:
            stream.write(json.dumps({"execute": action}).encode() + b"\n")
            stream.flush()
            while True:
                response = json.loads(stream.readline())
                if "error" in response:
                    raise RuntimeError("QEMU rejected graceful shutdown.")
                if "return" in response:
                    break
        # Wait for QEMU to exit before systemd sends its final termination signal.
        sock.settimeout(160)
        while stream.readline():
            pass


def github_payload(operation, repo):
    if repo is None:
        repo = run(
            ["gh", "repo", "view", "--json", "nameWithOwner", "--jq", ".nameWithOwner"],
            capture_output=True,
        ).stdout.strip()
    repo = validate_repo(repo)
    endpoint = "registration-token" if operation == "add" else "remove-token"
    token = run(
        [
            "gh",
            "api",
            "--method",
            "POST",
            f"repos/{repo}/actions/runners/{endpoint}",
            "--jq",
            ".token",
        ],
        capture_output=True,
    ).stdout.strip()
    if not token or token == "null":
        raise ValueError("GitHub did not return a runner token.")
    return {"operation": operation, "repository": repo, "token": token}


def main():
    parser = argparse.ArgumentParser(prog="home-ci", description=__doc__)
    parser.add_argument(
        "--config", default=os.environ.get("HOME_CI_CONFIG"), help=argparse.SUPPRESS
    )
    parser.add_argument(
        "command",
        metavar="COMMAND",
        help="add, remove, list, status, shell, proxy, doctor",
        choices=[
            "add",
            "remove",
            "list",
            "status",
            "shell",
            "proxy",
            "doctor",
            "_prepare",
            "_run",
            "_poweroff",
            "_request",
            "_proxy",
            "_shell",
            "_status",
        ],
    )
    parser.add_argument(
        "repository",
        nargs="?",
        help="owner/repository; defaults to the current Git repository",
    )
    parser.add_argument(
        "--workers",
        type=int,
        choices=range(1, 5),
        default=2,
        help="runner instances per repository (default: 2)",
    )
    parser.add_argument(
        "--from-env",
        action="store_true",
        help="copy the shell proxy, translating host loopback for the guest",
    )
    parser.add_argument(
        "--network",
        action="store_true",
        help="doctor: also test HTTPS and a disposable container build",
    )
    args = parser.parse_args()
    os.environ["HOME_CI_CONFIG"] = args.config
    cfg = json.loads(Path(args.config).read_text())
    if args.command == "_prepare":
        prepare(cfg)
    elif args.command == "_run":
        cmd = vm_command(cfg)
        os.execvp(cmd[0], cmd)
    elif args.command == "_poweroff":
        poweroff(cfg)
    elif args.command == "_request":
        ssh(
            cfg,
            ["sudo", "/usr/local/sbin/home-ci-guest", "request"],
            json.load(sys.stdin),
        )
    elif args.command == "_status":
        ssh(
            cfg,
            ["sudo", "systemctl", "--no-pager", "status", "home-ci-bootstrap.service"],
        )
    elif args.command == "_shell":
        # Shell is deliberately interactive; no repository or credential arguments.
        state = Path(cfg["stateDir"])
        run(
            [
                cfg.get("ssh", "ssh"),
                "-t",
                "-F",
                "/dev/null",
                "-i",
                str(state / "admin-key"),
                "-p",
                str(cfg["sshPort"]),
                "-o",
                "IdentitiesOnly=yes",
                "-o",
                "StrictHostKeyChecking=yes",
                "-o",
                f"UserKnownHostsFile={state / 'known_hosts'}",
                "ci-admin@127.0.0.1",
            ]
        )
    elif args.command == "_proxy":
        if cfg.get("settingsFile"):
            raise ValueError(
                "Private settings are managed through settingsFile; update that source instead."
            )
        proxy = validate_proxy(json.load(sys.stdin)["proxy"])
        state = Path(cfg["stateDir"])
        state.mkdir(mode=0o700, parents=True, exist_ok=True)
        os.umask(0o077)
        (state / "settings.json").write_text(json.dumps({"proxy": proxy}))
        print("Private proxy setting saved. Restart home-ci to apply it.")
    elif args.command in {"add", "remove"}:
        # Authenticate sudo before creating the short-lived token.
        run(["/run/wrappers/bin/sudo", "-v"])
        payload = github_payload(args.command, args.repository)
        payload["workers"] = args.workers
        private_run(cfg, "_request", payload)
    elif args.command == "list":
        private_run(cfg, "_request", {"operation": "list"})
    elif args.command == "proxy":
        proxy = (
            proxy_from_environment(os.environ)
            if args.from_env
            else validate_proxy(
                getpass.getpass("Guest HTTP(S) proxy URL (empty disables): ")
            )
        )
        private_run(cfg, "_proxy", {"proxy": proxy})
    elif args.command == "doctor":
        private_run(cfg, "_request", {"operation": "doctor", "network": args.network})
    else:
        private_run(cfg, "_" + args.command)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, RuntimeError, subprocess.CalledProcessError) as exc:
        # CalledProcessError command/output may include sensitive data. Never echo it.
        if isinstance(exc, subprocess.CalledProcessError):
            print(
                "home-ci: command failed; check VM status and GitHub permissions.",
                file=sys.stderr,
            )
        else:
            print(f"home-ci: {exc}", file=sys.stderr)
        sys.exit(1)
