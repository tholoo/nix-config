"""Private, console-only onboarding. Sensitive values never appear in arguments."""

import argparse
import getpass
import json
import os
from pathlib import Path
import pwd
import re
import subprocess
import sys
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

HOME = Path("/var/lib/hermes")
PRIVATE = Path("/var/lib/hermes-private")
RUNTIME = Path("/run/hermes")
FW_ENV = Path("/sys/firmware/qemu_fw_cfg/by_name/opt/hermes/telegram/raw")


def parse_settings(text):
    values = {}
    for line in text.splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        key, sep, value = line.partition("=")
        if not sep or key not in {"TELEGRAM_BOT_TOKEN", "TELEGRAM_ALLOWED_USERS", "TZ"} or key in values:
            raise ValueError("Only one each of TELEGRAM_BOT_TOKEN, TELEGRAM_ALLOWED_USERS and TZ is allowed.")
        values[key] = value.strip()
    if not re.fullmatch(r"[0-9]+:[A-Za-z0-9_-]{20,}", values.get("TELEGRAM_BOT_TOKEN", "")):
        raise ValueError("A valid Telegram bot token is required.")
    if not re.fullmatch(r"[1-9][0-9]*", values.get("TELEGRAM_ALLOWED_USERS", "")):
        raise ValueError("Exactly one positive numeric Telegram owner ID is required.")
    zone = values.setdefault("TZ", "UTC")
    try:
        ZoneInfo(zone)
    except (ZoneInfoNotFoundError, ValueError):
        raise ValueError("TZ must be an IANA timezone, such as UTC.") from None
    return values


def private_write(path, text, owner=None):
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    pending = path.with_name(path.name + ".pending")
    # Root owns the private/runtime directories. For agent-owned HOME, avoid
    # following a pre-existing symlink when publishing managed files.
    pending.unlink(missing_ok=True)
    fd = os.open(pending, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, "w") as stream:
        if owner is not None:
            os.fchown(stream.fileno(), owner.pw_uid, owner.pw_gid)
        stream.write(text)
    pending.replace(path)


def prepare():
    owner = pwd.getpwnam("hermes")
    cfg = json.loads(Path(os.environ["HERMES_BASE_CONFIG"]).read_text())
    source = FW_ENV if FW_ENV.exists() else PRIVATE / "telegram.env"
    env = ""
    if source.exists():
        values = parse_settings(source.read_text())
        owner_id = values["TELEGRAM_ALLOWED_USERS"]
        values.update({
            "TELEGRAM_ALLOWED_CHATS": owner_id,
            "TELEGRAM_HOME_CHANNEL": owner_id,
            "TELEGRAM_ALLOW_ALL_USERS": "false",
            "TELEGRAM_GUEST_MODE": "false",
        })
        cfg["telegram"]["allowed_chats"] = [owner_id]
        env = "".join(f"{key}={value}\n" for key, value in values.items())
        private_write(RUNTIME / "telegram.env", env)
    else:
        (RUNTIME / "telegram.env").unlink(missing_ok=True)
    private_write(HOME / "config.yaml", json.dumps(cfg, indent=2) + "\n", owner)
    private_write(HOME / ".env", env, owner)
    private_write(HOME / "SOUL.md", Path("/etc/hermes/SOUL.md").read_text(), owner)


def as_agent(args):
    subprocess.run([
        "runuser", "-u", "hermes", "--", "env", "HOME=/var/lib/hermes",
        "HERMES_HOME=/var/lib/hermes", os.environ["HERMES_EXECUTABLE"], *args,
    ], check=True, cwd=HOME / "workspace")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["telegram", "login", "start", "stop", "status", "prepare"])
    args = parser.parse_args()
    os.umask(0o077)
    if args.command == "telegram":
        if FW_ENV.exists():
            raise ValueError("Telegram settings are managed by the host credential; update its agenix source.")
        token = getpass.getpass("Telegram bot token: ")
        owner = getpass.getpass("Your numeric Telegram user ID: ")
        zone = input("IANA timezone [UTC]: ").strip() or "UTC"
        values = parse_settings(f"TELEGRAM_BOT_TOKEN={token}\nTELEGRAM_ALLOWED_USERS={owner}\nTZ={zone}\n")
        private_write(PRIVATE / "telegram.env", "".join(f"{k}={v}\n" for k, v in values.items()))
        print("Private Telegram settings saved. Run hermes-admin login, then hermes-admin start.")
    elif args.command == "login":
        prepare()
        as_agent(["auth", "add", "openai-codex", "--type", "oauth", "--no-browser"])
    elif args.command == "prepare":
        prepare()
    elif args.command == "start":
        # Stop before replacing bind-mounted settings; a running process keeps
        # the old inode until the service's mount namespace is recreated.
        subprocess.run(["systemctl", "stop", "hermes-gateway"], check=True)
        prepare()
        if not (RUNTIME / "telegram.env").exists():
            raise ValueError("Configure Telegram first with hermes-admin telegram.")
        subprocess.run(["systemctl", "start", "hermes-gateway"], check=True)
    else:
        subprocess.run(["systemctl", "--no-pager", args.command, "hermes-gateway"], check=True)


if __name__ == "__main__":
    try:
        main()
    except ValueError as exc:
        print(f"hermes-admin: {exc}", file=sys.stderr)
        sys.exit(1)
    except (OSError, subprocess.CalledProcessError):
        print("hermes-admin: operation failed; check the guest service status.", file=sys.stderr)
        sys.exit(1)
