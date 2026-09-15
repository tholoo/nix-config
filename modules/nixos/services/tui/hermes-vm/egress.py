"""HTTPS CONNECT relay: resolve public destinations, then pin their IP through Mihomo.

The guest only sees a Unix-socket-backed forwarding endpoint. DNS is resolved
over HTTPS through the same upstream proxy, avoiding host fake-IP DNS answers.
No TLS interception, URL/content logging, or direct-connection fallback.
"""

import argparse
import base64
import http.server
import ipaddress
import json
import os
from pathlib import Path
import select
import socket
import socketserver
import subprocess
import threading
import time
import urllib.parse
import urllib.request


def public_ip(value, local_addresses=()):
    ip = ipaddress.ip_address(value)
    return ip.version == 4 and ip.is_global and not ip.is_multicast and str(ip) not in local_addresses


def parse_target(authority):
    host, sep, port = authority.rpartition(":")
    if not sep or port != "443" or not host or any(c not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-" for c in host):
        raise ValueError("Only HTTPS destinations on port 443 are supported.")
    if len(host) > 253:
        raise ValueError("Invalid hostname.")
    return host.rstrip(".")


def proxy_settings(url):
    parsed = urllib.parse.urlsplit(url.strip())
    if parsed.scheme != "http" or not parsed.hostname or parsed.path not in {"", "/"} or parsed.query or parsed.fragment:
        raise ValueError("An HTTP upstream proxy URL is required.")
    auth = None
    if parsed.username is not None:
        pair = urllib.parse.unquote(parsed.username) + ":" + urllib.parse.unquote(parsed.password or "")
        auth = base64.b64encode(pair.encode()).decode()
    return parsed.hostname, parsed.port or 80, auth


def response_headers(sock):
    data = bytearray()
    while not data.endswith(b"\r\n\r\n"):
        byte = sock.recv(1)
        if not byte or len(data) >= 16384:
            raise ValueError("Invalid upstream response.")
        data.extend(byte)
    return bytes(data)


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *_args, **_kwargs):
        return None


class Relay:
    def __init__(self, proxy_url, local_addresses=()):
        self.proxy_url = proxy_url
        self.proxy_host, self.proxy_port, self.auth = proxy_settings(proxy_url)
        self.local_addresses = set(local_addresses)
        self.opener = urllib.request.build_opener(
            urllib.request.ProxyHandler({"http": proxy_url, "https": proxy_url}),
            NoRedirect(),
        )
        self.cache = {}
        self.lock = threading.Lock()

    def resolve(self, host):
        try:
            literal = ipaddress.ip_address(host)
        except ValueError:
            literal = None
        if literal is not None:
            addresses = [str(literal)]
        else:
            with self.lock:
                cached = self.cache.get(host)
                if cached and cached[0] > time.monotonic():
                    return cached[1]
            query = urllib.parse.urlencode({"name": host, "type": "A"})
            request = urllib.request.Request(
                "https://cloudflare-dns.com/dns-query?" + query,
                headers={"Accept": "application/dns-json"},
            )
            with self.opener.open(request, timeout=15) as response:
                result = json.loads(response.read(65536))
            if result.get("Status") != 0:
                raise ValueError("DNS lookup failed.")
            addresses = [a["data"] for a in result.get("Answer", []) if a.get("type") == 1]
        if not addresses or not all(public_ip(a, self.local_addresses) for a in addresses):
            raise ValueError("Destination is not a public IPv4 address.")
        with self.lock:
            if len(self.cache) >= 1024:
                self.cache.clear()
            self.cache[host] = (time.monotonic() + 60, addresses[0])
        return addresses[0]

    def connect(self, ip):
        if not public_ip(ip, self.local_addresses):
            raise ValueError("Destination is not public.")
        sock = socket.create_connection((self.proxy_host, self.proxy_port), timeout=15)
        try:
            header = f"CONNECT {ip}:443 HTTP/1.1\r\nHost: {ip}:443\r\n"
            if self.auth:
                header += f"Proxy-Authorization: Basic {self.auth}\r\n"
            sock.sendall((header + "\r\n").encode("ascii"))
            status = response_headers(sock).split(b"\r\n", 1)[0].split()
            if len(status) < 2 or status[1] != b"200":
                raise ValueError("Upstream proxy refused the connection.")
            return sock
        except Exception:
            sock.close()
            raise


class Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *_args):
        pass  # Requests can contain private domains and account details.

    def setup(self):
        self.request.settimeout(30)
        super().setup()

    def do_CONNECT(self):
        try:
            host = parse_target(self.path)
            upstream = self.server.relay.connect(self.server.relay.resolve(host))
        except (ValueError, OSError):
            self.send_error(502, "Destination blocked or upstream unavailable")
            return
        with upstream:
            self.send_response(200, "Connection established")
            self.end_headers()
            self.wfile.flush()
            self.close_connection = True
            self.connection.settimeout(30)
            upstream.settimeout(30)
            # Bound each connection's lifetime and idle time.
            deadline = time.monotonic() + 900
            try:
                while time.monotonic() < deadline:
                    ready, _, _ = select.select([self.connection, upstream], [], [], 90)
                    if not ready:
                        break
                    for src in ready:
                        data = src.recv(65536)
                        if not data:
                            return
                        (upstream if src is self.connection else self.connection).sendall(data)
            except OSError:
                return


class Server(socketserver.ThreadingMixIn, socketserver.UnixStreamServer):
    daemon_threads = True
    request_queue_size = 16
    slots = threading.BoundedSemaphore(24)

    def process_request(self, request, client_address):
        if not self.slots.acquire(blocking=False):
            request.close()
            return
        try:
            super().process_request(request, client_address)
        except Exception:
            self.slots.release()
            raise

    def process_request_thread(self, request, client_address):
        try:
            super().process_request_thread(request, client_address)
        finally:
            self.slots.release()

    def handle_error(self, *_args):
        pass


def main():
    # urllib otherwise honors ambient proxy bypass lists even with an explicit
    # ProxyHandler. Every DNS lookup must use the configured upstream.
    os.environ.pop("no_proxy", None)
    os.environ.pop("NO_PROXY", None)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--socket", required=True)
    parser.add_argument("--port", type=int, required=True)
    args = parser.parse_args()
    credential = Path(os.environ.get("CREDENTIALS_DIRECTORY", "/nonexistent")) / "upstream"
    proxy_url = credential.read_text().strip() if credential.exists() else f"http://127.0.0.1:{args.port}"
    interfaces = json.loads(subprocess.check_output(["ip", "-json", "address", "show"], text=True))
    local = [a["local"] for interface in interfaces for a in interface.get("addr_info", [])]
    relay = Relay(proxy_url, local)
    path = Path(args.socket)
    path.unlink(missing_ok=True)
    os.umask(0o007)
    with Server(str(path), Handler) as server:
        server.relay = relay
        server.serve_forever()


if __name__ == "__main__":
    main()
