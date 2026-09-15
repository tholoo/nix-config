# Hermes guest

`mine.hermes-vm` runs the pinned `llm-agents` Hermes package in a dedicated
NixOS VM. The host enables it explicitly and connects `proxyPort` to its existing
Mihomo configuration. No new flake input or source build of Hermes is needed.

## Boundaries and resources

- The guest receives no host directory shares, SSH keys, browser profiles,
  Docker socket, or Nix daemon socket. Administration uses a root-only host Unix
  console socket; there are no forwarded ports or guest network logins.
- Hermes runs as an unprivileged guest user. Its workspace, memory, conversations,
  OAuth credentials and jobs persist on a private virtual disk. Nix provides the
  guest software on a separate read-only store image.
- Defaults: two virtual CPUs, 3 GiB guest RAM, a 24 GiB sparse data disk, and
  20 MiB/s combined data-disk I/O. Host systemd limits VM CPU to 150% of one core
  and memory to 3.75 GiB including QEMU overhead. The small proxy relay has its
  own 192 MiB / 25% CPU limits. The VM has an elevated OOM score so it is a
  preferred victim under host memory pressure. These limits bound consumption;
  they do not reserve capacity or eliminate contention with other services.
- QEMU runs in a private network namespace containing only its own loopback.
  This lets libslirp create the internal TCP socket pair required by command
  forwarding without reaching host services. QEMU's restricted user network,
  a dedicated host nftables table, and cgroup IP restrictions block direct
  network access. The only outward connection is a
  Unix socket relay to the existing Mihomo HTTP proxy. It resolves names with
  Cloudflare DNS-over-HTTPS through Mihomo and pins validated public IPv4
  destinations. Private, loopback, link-local, fake-IP and local interface
  addresses are rejected. There is no direct fallback if Mihomo is unavailable.
- The relay permits HTTPS CONNECT on port 443 only. Plain HTTP pages, arbitrary
  TCP/UDP services, private websites and IPv6-only destinations are unavailable.
  Mihomo still chooses the route using its existing rules; this module does not
  change its selected proxy. Keep destination-overriding proxy sniffing disabled.
- The owner allowlist accepts exactly one numeric Telegram user ID. Only that
  user's private chat is enabled. Guest-bot invocation and group chats are off.
  Use BotFather to disable joining groups as an additional account-side setting.
- Tools cover web research, local files and commands, memory, reminders and
  scheduled checks. PDF, spreadsheet, archive, OCR and media utilities are
  installed. Browser automation, other chat platforms, voice transcription and
  automatic skill/package installation are not configured.
- Web search uses DDGS. Page extraction uses Firecrawl's anonymous service;
  it receives the requested URLs and page content and is subject to its free
  service limits. No Firecrawl key or paid fallback is configured.
- Flagged interactive commands use smart approval through the configured main
  model and existing subscription login. Review failures escalate to the owner.
- Telegram shows brief tool progress, suppressing consecutive repeats of the
  same tool, and removes progress bubbles after successful replies. Responses
  use native draft streaming with rich previews and rich final messages, with
  upstream fallback when Telegram cannot accept rich content or drafts.
  Processing reactions are enabled, link previews and
  response footers are disabled, and only important messages notify the owner.
- Scheduled agents cannot schedule further agents. Dangerous-command approvals
  fail closed in unattended jobs. Ordinary requested reminders and monitoring
  jobs remain available; exact sources and schedules are created privately.
  Scheduled jobs have an explicit default tool list, without interactive
  clarification or further scheduling tools.

The guest is a containment boundary, not a guarantee that an agent cannot make
mistakes. It can modify its own workspace and access its own authentication
material. Content submitted for reasoning goes to OpenAI; bot messages/files go
through Telegram, search queries go to search providers, page-extraction URLs
and content go through Firecrawl, and DNS names go to the resolver. This does
not provide entirely local inference or encrypted guest
storage. Host root and anyone holding a disk backup can access guest data.

## Manual activation and onboarding

Review and activate the host's NixOS configuration using the normal deployment
workflow. Home Manager does not manage this service. KVM must be available at
`/dev/kvm`; without it, the VM service is skipped. Activation starts the guest,
but the Telegram gateway stays stopped until private settings are supplied.

On the host:

```sh
sudo hermes-vm status
sudo hermes-vm console
```

The guest console automatically logs in as root. Press Enter if the prompt is
not visible. Run these commands **inside the guest**:

```sh
hermes-admin telegram
hermes-admin login
hermes-admin start
hermes-admin status
```

`telegram` privately prompts for the BotFather token, your positive numeric user
ID, and an IANA timezone. `login` starts the OpenAI Codex OAuth device flow;
complete it in your own browser with the intended subscription account. Enable
device-code authentication in the account if the login flow requests it. OAuth
state stays inside the guest. No API key or fallback paid provider is configured.

Press **Ctrl+]** to detach from the console. Open the bot's private chat and send
`/start`, then try a link summary or a small file. A synthetic reminder request:
“Remind me in five minutes to check this setup.” Verify the scheduled time and
delivery before relying on longer-running jobs. Creating a bot and authenticating
do not provision any monitoring targets automatically.

Changing the model and tool policy belongs in Nix. The gateway sees its managed
`config.yaml`, `.env` and `SOUL.md` as read-only; chat commands that try to save
those settings may fail. Memory, sessions, job definitions and OAuth refreshes
remain writable. `hermes-admin start` regenerates managed settings and restarts
the gateway. Use the console for account changes.

## Optional agenix input

Console onboarding needs no checked-in secret. For an existing agenix workflow,
point `mine.hermes-vm.environmentFile` at `config.age.secrets.<name>.path`.
Its decrypted runtime contents must have exactly these keys, with unquoted
values (angle-bracket placeholders below are not valid credentials):

```dotenv
TELEGRAM_BOT_TOKEN=<bot-token>
TELEGRAM_ALLOWED_USERS=<one-positive-numeric-owner-id>
TZ=UTC
```

The module uses systemd credentials and QEMU firmware configuration to deliver
the file at boot; it never reads plaintext into a Nix expression. When present,
this input takes precedence and `hermes-admin telegram` refuses local changes.
Restarting the host VM service is required after rotating that credential.

For authenticated upstream proxies, `mine.hermes-vm.proxyUrlFile` can reference
another agenix runtime path containing one HTTP proxy URL. That credential is
read by the host relay only. Leave it null for the existing unauthenticated
loopback Mihomo listener. Never put a credential-bearing URL directly in Nix.

## Operations and backups

On the host, `sudo systemctl stop hermes-vm` shuts down the entire guest.
Inside the guest, `hermes-admin stop` stops just the gateway. Logs are available
with `journalctl -u hermes-vm -u hermes-egress` on the host and
`journalctl -u hermes-gateway` in the guest. Treat guest logs as private.

Stop the VM before backing up `/var/lib/hermes-vm/state.qcow2`; store the backup
privately and encrypted. This disk contains credentials as well as conversations.
The separate guest store image is reproducible from the flake. Keep a data backup
before updating Hermes: restoring an older Nix generation does not roll back
application data migrations. Disk size is set when first created; changing
`diskGiB` does not resize or replace an existing disk.

There is no automatic activation, OAuth login, bot registration, or self-update.
Use the normal flake update/build/review process for software upgrades.

## Validation

From the repository, run the synthetic policy and lifecycle tests:

```sh
python3 -m unittest discover -s modules/nixos/services/tui/hermes-vm/tests -v
```

Check the pinned package against its generated, non-secret base configuration
by passing the package directory, base configuration and bundled locales as
three Nix store paths to `tests/check-packaged-config.py`. This exercises the
Telegram configuration parser, draft sending and status handler, scheduled
tool resolution and page extraction with mocked API responses; it needs local
socket access for Python's async event loop. The guest bundles catalogs from
the same pinned Hermes source and sets
`HERMES_BUNDLED_LOCALES` for both console commands and the gateway.

Inside the live guest, this check exercises QEMU command forwarding and confirms
that the relay rejects a private destination without contacting it:

```sh
python3 - <<'PY'
import http.client
import os
from urllib.parse import urlsplit
proxy = urlsplit(os.environ["HTTPS_PROXY"])
connection = http.client.HTTPConnection(proxy.hostname, proxy.port, timeout=10)
connection.request("CONNECT", "127.0.0.1:443")
assert connection.getresponse().status == 502
print("Guest forwarding and private-destination rejection passed")
PY
```

Evaluate the affected host and build its `config.mine.hermes-vm.package` before
activation. That package depends on the full guest system and store image.
New module files must be visible to the Git-backed flake, for example with
`git add -N` (intent-to-add, without staging their contents). Tests use synthetic
IDs, mock upstream connections and temporary files; they never contact Telegram
or authenticate an account. Host KVM, actual Mihomo routing, subscription login
and real message delivery must be checked after manual activation.

Implementation validation covered 12 passing synthetic tests, the packaged
Hermes config parser and Telegram allowlist, and nftables syntax in a disposable
network namespace. A software-emulated guest exercised boot, skipped startup
without credentials, proxy forwarding to a mock upstream, workspace writes,
read-only managed configuration, and clean QMP shutdown. KVM was unavailable
in that test environment; no production host services were activated.
