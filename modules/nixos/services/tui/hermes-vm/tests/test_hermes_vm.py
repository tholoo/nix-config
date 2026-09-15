import importlib.util
import io
import json
import os
from pathlib import Path
import socket
import threading
import unittest
from unittest.mock import patch
import tempfile


ROOT = Path(__file__).resolve().parents[1]


def load(name, filename):
    spec = importlib.util.spec_from_file_location(name, ROOT / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


host = load("host", "host.py")
admin = load("admin", "guest-admin.py")
egress = load("egress", "egress.py")
TOKEN = "12345:" + "a" * 30  # Synthetic; never used against Telegram.


class Credentials(unittest.TestCase):
    def test_single_private_owner_required(self):
        for value in ["", "*", "-10012345", "123,456", "@someone", "0"]:
            with self.subTest(value=value), self.assertRaises(ValueError):
                admin.parse_settings(f"TELEGRAM_BOT_TOKEN={TOKEN}\nTELEGRAM_ALLOWED_USERS={value}")

    def test_untrusted_environment_keys_and_duplicate_keys_rejected(self):
        good = f"TELEGRAM_BOT_TOKEN={TOKEN}\nTELEGRAM_ALLOWED_USERS=12345\n"
        for extra in ["TELEGRAM_GUEST_MODE=true", "HTTPS_PROXY=http://example.test", "TELEGRAM_ALLOWED_USERS=67890", "TZ=../UTC"]:
            with self.subTest(extra=extra), self.assertRaises(ValueError):
                admin.parse_settings(good + extra)
        self.assertEqual(admin.parse_settings(good)["TZ"], "UTC")

    def test_atomic_write_replaces_symlink_without_touching_target(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "target"
            target.write_text("original")
            link = Path(tmp) / "private"
            link.symlink_to(target)
            admin.private_write(link, "replacement")
            self.assertEqual(target.read_text(), "original")
            self.assertEqual(link.read_text(), "replacement")
            self.assertEqual(link.stat().st_mode & 0o777, 0o600)


class VirtualMachine(unittest.TestCase):
    def test_network_is_restricted_and_has_no_host_shares_or_listeners(self):
        cfg = dict(stateDir="/tmp/vm", cpus=2, memoryMiB=3072, qemu="qemu", kernel="kernel", initrd="initrd", init="/init", storeImage="store.img", hasCredential=False, socat="socat", proxySocket="/tmp/proxy.sock")
        cmd = host.vm_command(cfg)
        text = " ".join(cmd)
        self.assertIn("restrict=on", text)
        self.assertIn("UNIX-CONNECT:/tmp/proxy.sock", text)
        self.assertNotIn("hostfwd", text)
        self.assertNotIn("-virtfs", text)
        self.assertNotIn("-fsdev", text)
        self.assertNotIn("-fw_cfg", text)
        cfg["hasCredential"] = True
        with self.assertRaises(ValueError):
            host.vm_command(cfg, "/nonexistent")

    def test_existing_disk_is_preserved(self):
        with tempfile.TemporaryDirectory() as tmp:
            disk = Path(tmp) / "state.qcow2"
            disk.write_bytes(b"existing state")
            host.prepare({"stateDir": tmp})
            self.assertEqual(disk.read_bytes(), b"existing state")


class EgressPolicy(unittest.TestCase):
    def test_private_reserved_and_local_addresses_rejected(self):
        for ip in ["0.0.0.0", "10.2.3.4", "127.0.0.1", "169.254.169.254", "172.16.0.1", "192.168.1.1", "100.64.0.1", "198.18.0.1", "192.0.2.1", "224.0.0.1", "255.255.255.255", "::1", "::ffff:127.0.0.1", "8.8.8.8"]:
            with self.subTest(ip=ip):
                self.assertFalse(egress.public_ip(ip, {"8.8.8.8"}))
        self.assertTrue(egress.public_ip("9.9.9.9"))

    def test_only_https_authorities_accepted(self):
        for target in ["example.test:80", "example.test:22", "example.test:443\r\nX:a", "user@example.test:443", "[::1]:443", "example.test/path:443"]:
            with self.subTest(target=target), self.assertRaises(ValueError):
                egress.parse_target(target)
        self.assertEqual(egress.parse_target("example.test:443"), "example.test")

    def test_dns_mixed_public_private_answers_fail_closed(self):
        relay = egress.Relay("http://127.0.0.1:7890")
        answer = {"Status": 0, "Answer": [{"type": 1, "data": "9.9.9.9"}, {"type": 1, "data": "10.0.0.1"}]}
        with patch.object(relay.opener, "open", return_value=io.BytesIO(json.dumps(answer).encode())):
            with self.assertRaises(ValueError):
                relay.resolve("example.test")

    def test_upstream_receives_pinned_ip_not_another_dns_lookup(self):
        client, server = socket.socketpair()
        seen = []

        def upstream():
            with server:
                seen.append(egress.response_headers(server))
                server.sendall(b"HTTP/1.1 200 OK\r\n\r\n")

        thread = threading.Thread(target=upstream)
        thread.start()
        relay = egress.Relay("http://127.0.0.1:7890")
        with patch.object(egress.socket, "create_connection", return_value=client) as dial:
            relay.connect("9.9.9.9").close()
        thread.join(timeout=5)
        self.assertFalse(thread.is_alive())
        self.assertTrue(seen[0].startswith(b"CONNECT 9.9.9.9:443 HTTP/1.1\r\n"))
        dial.assert_called_once_with(("127.0.0.1", 7890), timeout=15)

    def test_unavailable_proxy_has_no_direct_fallback(self):
        relay = egress.Relay("http://127.0.0.1:7890")
        with patch.object(egress.socket, "create_connection", side_effect=ConnectionRefusedError) as dial:
            with self.assertRaises(ConnectionRefusedError):
                relay.connect("9.9.9.9")
        dial.assert_called_once_with(("127.0.0.1", 7890), timeout=15)

    def test_dns_service_redirects_are_not_followed(self):
        handler = egress.NoRedirect()
        self.assertIsNone(handler.redirect_request(None, None, 302, "Found", {}, "http://example.test"))

    def test_unix_relay_carries_bytes_and_rejects_private_destination(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = str(Path(tmp) / "proxy.sock")
            server = egress.Server(path, egress.Handler)
            relay = egress.Relay("http://127.0.0.1:7890")
            server.relay = relay
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            try:
                with socket.socket(socket.AF_UNIX) as client:
                    client.settimeout(5)
                    client.connect(path)
                    client.sendall(b"CONNECT 127.0.0.1:443 HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n")
                    self.assertIn(b"502", egress.response_headers(client).split(b"\r\n")[0])
                one, two = socket.socketpair()
                with patch.object(relay, "connect", return_value=one):
                    with socket.socket(socket.AF_UNIX) as client:
                        client.settimeout(5)
                        two.settimeout(5)
                        client.connect(path)
                        client.sendall(b"CONNECT 9.9.9.9:443 HTTP/1.1\r\nHost: 9.9.9.9\r\n\r\n")
                        self.assertIn(b"200", egress.response_headers(client).split(b"\r\n")[0])
                        client.sendall(b"opaque request")
                        self.assertEqual(two.recv(100), b"opaque request")
                        two.sendall(b"opaque response")
                        self.assertEqual(client.recv(100), b"opaque response")
                two.close()
            finally:
                server.shutdown()
                server.server_close()
                thread.join(timeout=5)


if __name__ == "__main__":
    unittest.main()
