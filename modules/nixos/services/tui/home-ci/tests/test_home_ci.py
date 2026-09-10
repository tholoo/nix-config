"""Exercise privacy, persistent-disk and service-registration boundaries."""

import csv
import hashlib
import importlib.util
import io
import json
import os
import subprocess
import tarfile
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


def load(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


host = load("host")
guest = load("guest")
docker = load("docker")


class HomeCITest(unittest.TestCase):
    def test_bootstrap_allows_runner_parent_listing_but_keeps_private_files_unreadable(
        self,
    ):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            state = root / "state"
            settings = root / "settings.json"
            settings.write_text(
                json.dumps({"proxy": "http://user:synthetic@proxy.example"})
            )
            apt = root / "apt-proxy"
            dropin = root / "docker-dropin"
            paths = {
                "/etc/apt/apt.conf.d/80-home-ci-proxy": apt,
                "/etc/systemd/system/docker.service.d": dropin,
            }
            with (
                patch.object(guest, "STATE", state),
                patch.object(guest, "CONFIG", settings),
                patch.object(guest, "Path", side_effect=lambda value: paths[value]),
            ):
                guest.proxy()
                guest.write_private(state / "registrations.json", {})
                guest.proxy()
            # GitHub validates directory listing, not just traversal, for every
            # runner ancestor. A root-owned parent must grant both to ci-runner.
            self.assertEqual(state.stat().st_mode & 0o055, 0o055)
            self.assertEqual(state.stat().st_mode & 0o022, 0)
            for private in (state / "proxy.env", state / "registrations.json", apt):
                self.assertEqual(private.stat().st_mode & 0o077, 0)

    @unittest.skipIf(
        os.geteuid() == 0,
        "Filesystem permission probe requires an unprivileged test user",
    )
    def test_doctor_detects_unlistable_runner_ancestor_with_real_filesystem_access(
        self,
    ):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            state = root / "state"
            (state / "runners").mkdir(parents=True)
            (state / "bootstrap-ready").touch()
            settings = root / "settings.json"
            settings.write_text("{}")
            execute = subprocess.run

            def probe(argv, **kwargs):
                if argv[0] == "runuser":
                    # Exercise the real access probe as this unprivileged test
                    # user; only Ubuntu's account switching is substituted.
                    return execute(argv[argv.index("--") + 1 :], **kwargs)
                return subprocess.CompletedProcess(argv, 0, stdout="", stderr="")

            with (
                patch.object(guest, "STATE", state),
                patch.object(guest, "CONFIG", settings),
                patch.object(guest.subprocess, "run", side_effect=probe),
            ):
                state.chmod(0o300)  # Traverse/write, but cannot list as this user.
                try:
                    output = io.StringIO()
                    with patch("sys.stdout", output), self.assertRaises(ValueError):
                        guest.doctor()
                    report = json.loads(output.getvalue())
                    self.assertIn(
                        {"check": "runner-directory-access", "ok": False},
                        report["checks"],
                    )
                finally:
                    state.chmod(0o700)
                output = io.StringIO()
                with patch("sys.stdout", output):
                    guest.doctor()
                self.assertIn(
                    {"check": "runner-directory-access", "ok": True},
                    json.loads(output.getvalue())["checks"],
                )

    def test_failed_network_diagnostics_report_status_without_proxy_values(self):
        with tempfile.TemporaryDirectory() as directory:
            state = Path(directory)
            (state / "bootstrap-ready").touch()
            settings = state / "settings.json"
            settings.write_text(
                json.dumps({"proxy": "http://user:synthetic-secret@proxy.example"})
            )
            output = io.StringIO()
            result = subprocess.CompletedProcess(
                [], 1, stdout="", stderr="synthetic-secret"
            )
            with (
                patch.object(guest, "STATE", state),
                patch.object(guest, "CONFIG", settings),
                patch.object(guest.subprocess, "run", return_value=result),
                patch("sys.stdout", output),
            ):
                with self.assertRaises(ValueError):
                    guest.doctor(network=True)
            report = json.loads(output.getvalue())
            self.assertTrue(report["proxy_configured"])
            self.assertIn({"check": "github", "ok": False}, report["checks"])
            self.assertNotIn("synthetic-secret", output.getvalue())
            self.assertNotIn("proxy.example", output.getvalue())

    def test_failed_service_start_recovers_without_registering_again(self):
        with tempfile.TemporaryDirectory() as directory:
            state = Path(directory)
            units = state / "units"
            units.mkdir()
            (state / "bootstrap-ready").touch()
            settings = state / "settings.json"
            settings.write_text("{}")
            payload = {
                "operation": "add",
                "repository": "example/project",
                "token": "synthetic",
                "workers": 1,
            }
            with (
                patch.object(guest, "STATE", state),
                patch.object(guest, "CONFIG", settings),
                patch.object(guest, "UNIT_DIR", units),
                patch.object(guest, "install_runner"),
                patch.object(guest, "as_runner") as configure,
                patch.object(guest, "run") as execute,
            ):

                def fail_start(argv, **kwargs):
                    if argv[:3] == ["systemctl", "enable", "--now"]:
                        raise subprocess.CalledProcessError(1, argv)

                execute.side_effect = fail_start
                with self.assertRaises(subprocess.CalledProcessError):
                    guest.request(payload)
                self.assertEqual(
                    len(json.loads((state / "registrations.json").read_text())), 1
                )

                def inactive_then_start(argv, **kwargs):
                    if argv[:2] == ["systemctl", "is-active"]:
                        raise subprocess.CalledProcessError(3, argv)

                execute.side_effect = inactive_then_start
                guest.request(payload)
                self.assertEqual(configure.call_count, 1)
                self.assertEqual(
                    execute.call_args.args[0][:3], ["systemctl", "enable", "--now"]
                )

    def test_proxy_from_shell_translates_host_loopback_without_printing_credentials(
        self,
    ):
        value = host.proxy_from_environment(
            {"HTTPS_PROXY": "http://user:synthetic@127.0.0.1:8080"}
        )
        self.assertEqual(value, "http://user:synthetic@10.0.2.2:8080")
        self.assertEqual(
            host.proxy_from_environment({"http_proxy": "http://proxy.example:3128"}),
            "http://proxy.example:3128",
        )

    def test_buildkit_receives_proxy_and_csv_no_proxy_without_changing_login(self):
        env = {
            "https_proxy": "http://proxy.example:8080",
            "no_proxy": "localhost,127.0.0.1,::1",
        }
        original = [
            "buildx",
            "create",
            "--name",
            "test",
            "--driver",
            "docker-container",
        ]
        result = docker.arguments(original, env)
        options = [
            next(csv.reader([result[i + 1]]))[0]
            for i, value in enumerate(result)
            if value == "--driver-opt"
        ]
        self.assertIn("env.https_proxy=http://proxy.example:8080", options)
        self.assertIn("env.no_proxy=localhost,127.0.0.1,::1", options)
        login = ["login", "--password-stdin", "registry.example"]
        self.assertEqual(docker.arguments(login, env), login)
        remote = ["buildx", "create", "--driver=remote", "tcp://builder.example:1234"]
        self.assertEqual(docker.arguments(remote, env), remote)

    def test_explicit_buildkit_proxy_option_wins(self):
        original = [
            "buildx",
            "create",
            "--driver-opt",
            "env.https_proxy=http://custom.example",
        ]
        result = docker.arguments(original, {"https_proxy": "http://default.example"})
        self.assertEqual(sum("env.https_proxy=" in value for value in result), 1)
        self.assertIn("env.https_proxy=http://custom.example", result)

    def test_worker_proxy_configuration_preserves_auth_and_isolates_logins(self):
        with tempfile.TemporaryDirectory() as directory:
            first, second = Path(directory) / "one", Path(directory) / "two"
            guest.write_private(
                first / ".docker/config.json",
                {"auths": {"registry.example": {"auth": "synthetic"}}},
            )
            with patch.object(guest, "run"):
                guest.configure_worker(first, {"proxy": "http://proxy.example:8080"})
                guest.configure_worker(second, {"proxy": "http://proxy.example:8080"})
            one = json.loads((first / ".docker/config.json").read_text())
            two = json.loads((second / ".docker/config.json").read_text())
            self.assertEqual(one["auths"]["registry.example"]["auth"], "synthetic")
            self.assertNotIn("auths", two)
            self.assertEqual(
                one["proxies"]["default"]["httpProxy"], "http://proxy.example:8080"
            )
            with patch.object(guest, "run"):
                guest.configure_worker(first, {"proxy": ""})
            self.assertNotIn(
                "default",
                json.loads((first / ".docker/config.json").read_text())["proxies"],
            )

    def test_verified_runner_archive_is_reused_for_second_worker(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            cache = root / "downloads"
            cache.mkdir()
            archive = cache / "runner-test.tar.gz"
            with tarfile.open(archive, "w:gz") as bundle:
                entry = tarfile.TarInfo("run.sh")
                content = b"#!/bin/sh\nexit 0\n"
                entry.size = len(content)
                bundle.addfile(entry, io.BytesIO(content))
            settings = {
                "runnerVersion": "test",
                "runnerSha256": hashlib.sha256(archive.read_bytes()).hexdigest(),
            }
            with (
                patch.object(guest, "CACHE", cache),
                patch.object(guest, "run") as execute,
            ):
                guest.install_runner(root / "one", settings)
                guest.install_runner(root / "two", settings)
                self.assertTrue((root / "one/run.sh").exists())
                self.assertTrue((root / "two/run.sh").exists())
                self.assertTrue(
                    all(call.args[0][0] == "chown" for call in execute.call_args_list)
                )

    def test_parallel_workers_share_label_but_have_separate_workspaces(self):
        with tempfile.TemporaryDirectory() as directory:
            state = Path(directory)
            units = state / "units"
            units.mkdir()
            (state / "bootstrap-ready").touch()
            settings = state / "settings.json"
            settings.write_text("{}")
            with (
                patch.object(guest, "STATE", state),
                patch.object(guest, "CONFIG", settings),
                patch.object(guest, "UNIT_DIR", units),
                patch.object(guest, "install_runner"),
                patch.object(guest, "as_runner") as configure,
                patch.object(guest, "run"),
            ):
                guest.request(
                    {
                        "operation": "add",
                        "repository": "example/project",
                        "token": "synthetic-secret",
                        "workers": 2,
                    }
                )
                self.assertEqual(configure.call_count, 2)
                workspaces = {call.args[0] for call in configure.call_args_list}
                self.assertEqual(len(workspaces), 2)
                for call in configure.call_args_list:
                    argv = call.args[1]
                    self.assertEqual(argv[argv.index("--labels") + 1], "home-ci")
                self.assertEqual(len(list(units.glob("*.service"))), 2)
                registry = json.loads((state / "registrations.json").read_text())
                self.assertEqual(len(registry), 2)
                for file in units.iterdir():
                    self.assertNotIn("example/project", file.read_text())
                    self.assertNotIn("synthetic-secret", file.read_text())
                self.assertNotIn(
                    "synthetic-secret", (state / "registrations.json").read_text()
                )
                guest.request(
                    {
                        "operation": "remove",
                        "repository": "example/project",
                        "token": "synthetic-secret",
                    }
                )
                self.assertEqual(
                    json.loads((state / "registrations.json").read_text()), {}
                )
                self.assertEqual(list(units.glob("*.service")), [])

    def test_repository_validation_rejects_option_and_shell_injection(self):
        for value in [
            "--help",
            "org/repo;echo secret",
            "org/repo\n",
            "../x/y",
            "https://github.com/org/repo",
        ]:
            with self.subTest(value=value), self.assertRaises(ValueError):
                host.validate_repo(value)
        self.assertEqual(
            host.validate_repo("example/project.two"), "example/project.two"
        )

    def test_repo_token_is_not_sent_as_a_command_argument(self):
        response = subprocess.CompletedProcess([], 0, stdout="synthetic-token\n")
        with patch.object(host, "run", return_value=response) as execute:
            payload = host.github_payload("add", "example/private-project")
            self.assertEqual(
                execute.call_args.args[0][4],
                "repos/example/private-project/actions/runners/registration-token",
            )
        with (
            patch.object(host, "run") as execute,
            patch.dict(os.environ, HOME_CI_CONFIG="/config.json"),
        ):
            host.private_run({}, "_request", payload)
            argv = execute.call_args.args[0]
            self.assertNotIn("synthetic-token", " ".join(argv))
            self.assertNotIn("private-project", " ".join(argv))
            self.assertEqual(json.loads(execute.call_args.kwargs["input"]), payload)

    def test_proxy_rejects_config_file_injection(self):
        for value in [
            'http://proxy/"; dangerous',
            "http://proxy/\n",
            "file:///etc/passwd",
        ]:
            with self.subTest(value=value), self.assertRaises(ValueError):
                host.validate_proxy(value)

    def test_existing_vm_disk_is_never_overwritten_by_prepare(self):
        with tempfile.TemporaryDirectory() as directory:
            state = Path(directory)
            for name in ["admin-key", "guest-key"]:
                (state / name).write_text("synthetic-private-key")
                (state / f"{name}.pub").write_text(
                    "ssh-ed25519 synthetic-public-key test"
                )
            disk = state / "ubuntu.qcow2"
            disk.write_bytes(b"existing guest disk and registrations")
            cfg = {
                "stateDir": directory,
                "sshPort": 22222,
                "image": "/missing/base-image",
                "guest": str(ROOT / "guest.py"),
                "bootstrap": str(ROOT / "bootstrap.sh"),
                "dockerWrapper": str(ROOT / "docker.py"),
                "jobHook": str(ROOT / "job-start.sh"),
                "runnerVersion": "test",
                "runnerSha256": "test",
            }
            with patch.object(host, "run") as execute:
                host.prepare(cfg)
                self.assertEqual(
                    [call.args[0][0] for call in execute.call_args_list],
                    ["genisoimage"],
                )
            self.assertEqual(
                disk.read_bytes(), b"existing guest disk and registrations"
            )
            cloud = json.loads((state / "seed/user-data").read_text().split("\n", 1)[1])
            self.assertEqual(
                cloud["ssh_keys"]["ed25519_private"], "synthetic-private-key"
            )
            self.assertNotIn("token", (state / "seed/guest-settings.json").read_text())

    def test_vm_only_publishes_ssh_to_loopback(self):
        cmd = host.vm_command(
            {
                "stateDir": "/var/lib/home-ci",
                "cpus": 4,
                "memoryMiB": 4096,
                "sshPort": 22222,
            }
        )
        self.assertEqual(
            cmd[cmd.index("-netdev") + 1],
            "user,id=net0,hostfwd=tcp:127.0.0.1:22222-:22",
        )
        self.assertNotIn("-virtfs", cmd)

    def test_duplicate_registration_does_not_contact_github_or_restart(self):
        with tempfile.TemporaryDirectory() as directory:
            state = Path(directory)
            repository = "example/private-project"
            (state / "registrations.json").write_text(
                json.dumps({guest.runner_id(repository) + "-1": repository})
            )
            with (
                patch.object(guest, "STATE", state),
                patch.object(guest, "run") as execute,
            ):
                guest.request(
                    {
                        "operation": "add",
                        "repository": repository,
                        "token": "synthetic",
                        "workers": 1,
                    }
                )
                self.assertEqual(execute.call_count, 1)
                self.assertEqual(
                    execute.call_args.args[0][:3], ["systemctl", "is-active", "--quiet"]
                )


if __name__ == "__main__":
    unittest.main()
