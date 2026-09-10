# Ubuntu CI at home

`mine.home-ci` declares one Ubuntu 24.04 VM and the `home-ci` management command.
The module is disabled by default. It does not declare repositories, GitHub
accounts, tokens, or project-specific services. Enabling it starts a dedicated
QEMU/KVM systemd service; it does not manage or replace libvirt domains.

## Enable manually

Add this to the desired **NixOS host** configuration, not Home Manager:

```nix
mine.home-ci = {
  enable = true;
  cpus = 4;
  memoryMiB = 4096;
  diskGiB = 80;
};
```

Include new files in Git before evaluating a Git-backed flake. Build and activate
through your usual NixOS workflow when ready. Activation starts `home-ci.service`.
Initial boot installs the generic Ubuntu tooling and may take several minutes.
No repository is registered automatically. The VM needs KVM and outbound network
access; its only forwarded port is SSH on host loopback, default `127.0.0.1:22222`.
There is no inbound router/firewall change and no shared desktop home directory.

```bash
systemctl status home-ci
home-ci status
```

The first command checks QEMU on the host. The second checks guest provisioning;
it requires the VM's SSH service to have started. `home-ci shell` opens an
administrative shell in the guest. Use `sudo journalctl -u home-ci-bootstrap`
there to diagnose provisioning. Host console output lives privately in
`/var/lib/home-ci/console.log`.

After provisioning, run `home-ci doctor` to check Docker, Buildx, free space and
runner directory access. The access probe runs as `ci-runner` and checks that it
can list each parent directory, as GitHub requires during registration.
`home-ci doctor --network` also checks GitHub, Python packages, the container
registry and a disposable BuildKit build with a networked `RUN` instruction.
That explicit diagnostic may take several minutes and download images; it never
pushes an image or registers a repository. It removes its named probe builder and
output image afterward. Results report check names and status, not proxy values.

## Register projects privately

Log in with GitHub CLI on the host (`gh auth login`). From a project's checkout:

```bash
home-ci add
```

This infers the repository with `gh repo view`, gets a short-lived runner
registration token, and registers **two** independent runner instances inside
the VM. Both advertise `home-ci`. To supply a repository explicitly or choose
another count:

```bash
home-ci add example/project --workers 2
home-ci list
home-ci remove example/project
```

The command uses sudo for the private VM management identity. It uses the
invoking user's existing `gh` authentication; no long-lived GitHub token is
copied into the VM. Short-lived tokens cross stdin instead of host command-line
arguments. GitHub's own registration script receives the short-lived token as
an argument **inside the guest**. Registration output is not copied into host logs.

Repository mappings and runner credentials live only on the private guest disk.
They do not enter Git, a Nix expression, a derivation, or the Nix store. Re-running
`add` preserves existing workers and adds missing ones. To reduce worker count,
remove that repository's runners and add it again with the desired count.
Removal unregisters every local worker for that repository, but retains work
directories and caches for explicit cleanup. Stop ongoing jobs before removal.
If a registration succeeded but starting its service was interrupted, retry `add`:
the command reconciles the local service without registering a duplicate runner.

Inside the guest, `/var/lib/home-ci` is root-owned with mode `0755` because the
runner validates read/list access to all its parent directories. Private proxy
and registration files remain root-owned with mode `0600`; runner credentials
stay within their worker directories. The host's `/var/lib/home-ci` remains
mode `0700`, protecting the VM disk and management keys.

Each project's workflow must select the runner:

```yaml
runs-on: [self-hosted, Linux, X64, home-ci]
```

Change all relevant jobs; jobs that retain `ubuntu-latest` still consume hosted
minutes. Two registered workers allow two jobs to execute at once. Additional
repositories can use the same label without a Nix rebuild or another VM.

## Performance and concurrency

Runner workers and test workers serve different purposes. Runner workers let
independent Actions jobs overlap. Test workers divide tests within a single job;
keep the project's existing test parallelism and tune it to the VM's capacity.
Four virtual CPUs are a starting point, not a promise of four times the speed.
All repositories and their test processes share the VM's CPU and memory budget.

The guest disk, workspaces, Python download caches and Docker data persist across
jobs and reboots. Workers share uv's package cache and Python installations, while
each has its own home directory and Docker client configuration. Parallel logins
therefore do not overwrite one another. The verified runner archive is downloaded
once and reused when adding workers. Dependencies are installed once during bootstrap. Individual
Actions can still clear their own caches/builders; the VM does not override them.
With more available desktop memory, raise CPU/memory limits before adding many
workers. Increasing worker count alone can slow CPU-heavy concurrent test suites.

Workers have separate checkout and Docker login directories but share one guest and Docker daemon.
Concurrent jobs must not bind the same fixed host port. For Docker service jobs,
use dynamically assigned ports and the Actions service port context, or serialize
those particular jobs. Limit this shared persistent VM to trusted repositories
and workflows; it does not isolate repositories from one another.

The desktop must remain awake and connected. This module does not change your
sleep policy. Run disruptive configuration changes while jobs are idle.

## Optional private proxy settings

The VM does not inherit the desktop shell's proxy. If outbound access needs one:

```bash
sudo systemctl stop home-ci
home-ci proxy
sudo systemctl start home-ci
```

If the current host shell already has a working HTTP(S) proxy, use
`home-ci proxy --from-env` instead of the prompt. It copies the setting privately
and translates host loopback (`localhost`, `127.0.0.1`, or `::1`) to the QEMU host
gateway. It does not print the URL or credentials.

The prompt stores the URL in `/var/lib/home-ci/settings.json`, outside Git and the
Nix store. Under QEMU user networking, `10.0.2.2` refers to the host; a guest URL
must use an address reachable from the guest, not guest loopback. Use an HTTP(S)
proxy. The setting applies to apt, the Docker daemon, runner registration,
runner jobs, Docker client build arguments and containerized BuildKit. Enter an empty URL to disable it. A failed first provisioning attempt
can be retried after configuring the proxy and restarting the VM.

Inside the guest, a small `/usr/local/bin/docker` wrapper forwards proxy variables
only when creating a `docker-container` Buildx builder. Explicit driver proxy
options take precedence, and other Docker commands and driver types pass through
unchanged. Worker-specific Docker client files provide the proxy settings for
ordinary containers and build steps. A job-start hook masks inherited proxy URLs
in Actions logs. Workflows that deliberately invoke `/usr/bin/docker` directly,
replace `DOCKER_CONFIG`, or use a remote builder must configure that path themselves.
This is HTTP(S) proxy support, not a VPN for arbitrary guest protocols.

For settings managed through agenix, use a generic encrypted JSON secret and
reference its **runtime path**:

```nix
mine.home-ci.settingsFile = config.age.secrets.ci-settings.path;
```

The JSON format is `{"proxy":"http://proxy.example:8080"}`. The host service reads
it through a systemd credential. Do not use `builtins.readFile` on decrypted
settings. When `settingsFile` is set, `home-ci proxy` refuses to overwrite it;
update the encrypted source and restart the VM instead. No repository list belongs
in this file either.

## Updates and recovery

The Ubuntu base image and initial runner archive are pinned by SHA-256. The guest
uses Ubuntu apt repositories during first boot, so package resolution is not a
bit-for-bit Nix build. GitHub runner automatic updates remain enabled. Install
Ubuntu security updates periodically from `home-ci shell` while jobs are idle.

The generic guest management scripts and proxy settings are reconciled from a
runtime config disk on **every guest boot**. A host module update restarts the VM
when its payload changes. Cloud-init only establishes the initial user, pinned
SSH host identity and bootstrap service. Existing guest disks are never replaced
by configuration updates. The desired apt package list is fingerprinted: changes retry package installation
on the next boot, while unchanged boots reuse the installed tooling. Interrupted
dpkg configuration is retried before installation. Packages removed from that
list are not automatically uninstalled.

Nix rollback restores the host service configuration, not the mutable guest disk.
Changing `diskGiB` or the pinned base image affects newly created disks only;
existing disks are never implicitly shrunk, resized, or reset. Back up the private
state directory with the VM stopped before an explicit guest rebuild. It contains
repository metadata, credentials, VM SSH keys and the complete guest disk.

Disabling the module stops the service but retains its disk. Re-enabling it
resumes the same registrations. Do not delete state as an automatic repair.

## Validation

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover \
  -s modules/nixos/services/tui/home-ci/tests -v
```

The tests exercise token transport, interrupted registration recovery, multiple worker
registration/removal, worker credential isolation, BuildKit proxy forwarding,
archive caching, runner parent-directory access and private-file permissions,
loopback-only forwarding, input validation and preservation
of existing guest disks. They do not boot a VM or contact GitHub.

Build the command without enabling the service:

```bash
nix build --no-link .#nixosConfigurations.example-host.config.mine.home-ci.package
```

Replace the example host with your configured host. Evaluation/build success is
separate from activation and a successful real workflow run.

References: [GitHub runner setup](https://docs.github.com/en/actions/how-tos/manage-runners/self-hosted-runners/add-runners),
[QEMU invocation](https://www.qemu.org/docs/master/system/invocation.html),
[cloud-init NoCloud](https://docs.cloud-init.io/en/latest/reference/datasources/nocloud.html).
