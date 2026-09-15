"""Small lifecycle controller; no host directories or network listeners enter the VM."""

import argparse
import json
import os
from pathlib import Path
import socket
import subprocess
import sys


def prepare(cfg):
    state = Path(cfg["stateDir"])
    state.mkdir(parents=True, exist_ok=True, mode=0o700)
    os.umask(0o077)
    disk = state / "state.qcow2"
    if disk.exists():
        return  # Never overwrite persistent data on configuration changes.
    raw = state / "state.raw.pending"
    pending = state / "state.qcow2.pending"
    try:
        with raw.open("wb") as stream:
            stream.truncate(cfg["diskGiB"] * 1024**3)
        subprocess.run([cfg["mkfs"], "-q", "-F", "-L", "hermes-state", str(raw)], check=True)
        subprocess.run([cfg["qemuImg"], "convert", "-f", "raw", "-O", "qcow2", str(raw), str(pending)], check=True)
        pending.replace(disk)
    finally:
        raw.unlink(missing_ok=True)
        pending.unlink(missing_ok=True)


def vm_command(cfg, credential_dir=None):
    state = Path(cfg["stateDir"])
    cmd = [
        cfg["qemu"], "-name", "hermes", "-enable-kvm", "-machine", "q35",
        "-cpu", "host", "-smp", str(cfg["cpus"]), "-m", str(cfg["memoryMiB"]),
        "-display", "none", "-monitor", "none", "-no-reboot",
        "-serial", f"unix:{state / 'console.sock'},server=on,wait=off",
        "-qmp", f"unix:{state / 'qmp.sock'},server=on,wait=off",
        "-kernel", cfg["kernel"], "-initrd", cfg["initrd"],
        "-append", f"console=ttyS0 init={cfg['init']} panic=1",
        "-drive", f"file={state / 'state.qcow2'},format=qcow2,if=virtio,throttling.bps-total=20971520",
        "-drive", f"file={cfg['storeImage']},format=raw,if=virtio,readonly=on",
        "-netdev", f"user,id=net0,ipv6=off,restrict=on,guestfwd=tcp:10.0.2.100:3128-cmd:{cfg['socat']} STDIO UNIX-CONNECT:{cfg['proxySocket']}",
        "-device", "virtio-net-pci,netdev=net0",
        "-device", "virtio-rng-pci",
    ]
    if cfg["hasCredential"]:
        credential = Path(credential_dir or "") / "telegram"
        if not credential.is_file():
            raise ValueError("Configured Telegram credential is unavailable.")
        cmd += ["-fw_cfg", f"name=opt/hermes/telegram,file={credential}"]
    return cmd


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
                    raise ValueError("QEMU rejected the shutdown request.")
                if "return" in response:
                    break
        sock.settimeout(100)
        while stream.readline():
            pass


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", required=True)
    parser.add_argument("command", choices=["console", "status", "prepare", "run", "poweroff"])
    args = parser.parse_args()
    cfg = json.loads(Path(args.config).read_text())
    if args.command == "console":
        print("Guest root console. Press Ctrl+] to detach.", flush=True)
        os.execv(cfg["socat"], [cfg["socat"], "STDIO,raw,echo=0,escape=0x1d", f"UNIX-CONNECT:{cfg['stateDir']}/console.sock"])
    elif args.command == "status":
        subprocess.run(["systemctl", "--no-pager", "status", "hermes-vm.service"], check=True)
    elif args.command == "prepare":
        prepare(cfg)
    elif args.command == "run":
        cmd = vm_command(cfg, os.environ.get("CREDENTIALS_DIRECTORY"))
        os.execv(cmd[0], cmd)
    else:
        poweroff(cfg)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, subprocess.CalledProcessError):
        print("hermes-vm: operation failed; check service status and permissions.", file=sys.stderr)
        sys.exit(1)
