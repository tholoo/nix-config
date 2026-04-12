# CLAUDE.md - NixOS Configuration Reference

## Overview

Personal NixOS/home-manager configuration for user **tholo** (Ali Mohammadzadeh). Uses the **Snowfall Lib** framework to organize a multi-host, multi-user Nix flake with a custom tag-based module system. Timezone is `Asia/Tehran`.

## Architecture

### Framework: Snowfall Lib

The flake uses `snowfall-lib` which dictates directory structure conventions:
- `systems/` - NixOS system configurations (one per host)
- `homes/` - Home-manager configurations (one per user@host)
- `modules/` - Shared modules (split into `nixos/` and `home/`)
- `packages/` - Custom Nix packages
- `overlays/` - Nixpkgs overlays
- `shells/` - Dev shells
- `lib/` - Custom library functions

The namespace is `mine` — all custom options live under `config.mine.*`.

### Tag System (Core Pattern)

Every module uses a tag-based enable/disable system defined in `lib/modules/default.nix`:

```nix
# Module pattern — every module follows this exact structure:
{ config, lib, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "module-name";
in
{
  options.mine.${name} = mkEnable config {
    tags = [ "tui" "cli-tools" ];  # tags that control auto-enable
  };
  config = mkIf cfg.enable {
    # ... module config
  };
}
```

**How it works:**
- Suites (`mine.tui`, `mine.gui`) add tags to `mine.tags.include`
- `mkEnable` auto-enables a module if ANY of its tags appear in `include` AND NONE in `exclude`
- Hosts/homes can override with `mine.tags.exclude` or explicit `mine.moduleName.enable = false`

### Hosts

| Host | Type | Arch | Boot | Notes |
|------|------|------|------|-------|
| **elderwood** | Desktop | x86_64 | GRUB | Intel CPU, GUI+TUI, excludes `server` tag |
| **glacier** | Laptop | x86_64 | GRUB | AMD CPU+GPU, GUI+TUI, excludes `server` tag, IdeaPad Slim 5 |
| **granite** | Server | x86_64 | systemd-boot disabled | Hetzner Cloud, TUI only, excludes `game`/`gui`/`develop`/`mount`/`proxy`/`vpn`, uses disko for disk management, deployed via `deploy-rs` |

### User Configuration

User `tholo` on all hosts. Email varies by host:
- elderwood: `ali.mohamadza@gmail.com`
- glacier: `ali0mhmz@gmail.com`
- granite: no email set (uses default)

Default shell: **nushell** (`pkgs.nushell`)

### Secrets Management

Uses **agenix** for secret encryption:
- Secrets stored as `.age` files in `secrets/`
- `secrets/secrets.nix` defines which public keys can decrypt each secret
- Identity paths: `~/.ssh/id_ed25519`
- Secret categories: IPs, singbox VPN config, jellyfin/media stack credentials

## Key Directories

```
flake.nix                          # Main entry point
lib/default.nix                    # getNixFiles helper
lib/modules/default.nix            # mkEnable, listContainsList
modules/
  home/
    home/default.nix               # User account options (mine.user.*)
    tags/default.nix               # Tag include/exclude options
    suites/{tui,gui}/              # Suite toggles
    apps/
      tui/                         # ~40 TUI app modules
      gui/                         # ~25 GUI app modules
      stylix/                      # Theme (currently commented out)
    services/
      tui/                         # gpg-agent, udiskie
      gui/                         # ~15 GUI services
  nixos/
    nixos/default.nix              # Base OS config (hostname, timezone, SSH, kernel)
    users/default.nix              # User accounts, groups, authorized SSH keys
    tags/default.nix               # NixOS-level tag options
    suites/{tui,gui}/              # NixOS suite toggles
    apps/
      tui/                         # docker, nix, fish, gpg, networkmanager, etc.
      gui/                         # hyprland, portal, proxy, virt-manager, etc.
    services/
      tui/                         # syncthing, tailscale, k8s, mount, etc.
      gui/                         # pipewire, greetd, keyd, battery, etc.
    {grub,systemd-boot,plymouth}/  # Boot configuration
    {nvidia,opengl,bluetooth}/     # Hardware
    security/                      # polkit, rtkit, PAM
systems/x86_64-linux/
  {elderwood,glacier,granite}/     # Per-host config + hardware-configuration.nix
homes/x86_64-linux/
  tholo@{elderwood,glacier,granite}/ # Per-user@host home config
packages/                          # Custom packages (plymouth theme, zellij plugins)
overlays/floorp/                   # Pins floorp to stable channel
secrets/                           # agenix encrypted secrets (.age files)
resources/                         # Static resources (wallpapers, old nvim lua config)
```

## Flake Inputs (Key Dependencies)

- **nixpkgs** (unstable), **nixpkgs-stable** (25.05)
- **snowfall-lib** - Framework
- **home-manager** - User environment
- **nixvim** - Neovim configuration via Nix
- **agenix** - Secret management
- **disko** - Declarative disk partitioning (granite)
- **deploy-rs** - Remote deployment (granite)
- **stylix** - Theming (module exists but mostly commented out)
- **nixos-hardware** - Hardware-specific modules (glacier)
- **srvos** - Server/desktop profiles (glacier=desktop, granite=server+hetzner)
- **fenix** - Rust toolchain
- **nix-index-database** - Command-not-found database
- **zen-browser** - Browser
- **nixflix** - Media stack (Jellyfin, Sonarr, Radarr, etc.)
- **nix-dokploy** - Dokploy deployment platform
- **NixVirt** - Libvirt/QEMU management

## Build & Deploy Commands

```bash
# Rebuild local NixOS
nixos-rebuild switch --flake . --accept-flake-config

# Home-manager standalone
nix run home-manager/master -- switch --flake .

# Deploy to granite (remote server)
# Uses deploy-rs; configured in flake.nix deploy.nodes
nix run github:serokell/deploy-rs -- .#granite

# Format code
nix fmt

# Dev shell (includes deploy-rs + agenix CLI)
nix develop
# or via direnv (`.envrc` contains `use flake`)

# Generate ISO
nix build .#nixosConfigurations.glacier.config.formats.iso

# Provision new server with nixos-anywhere
nix run github:nix-community/nixos-anywhere -- --flake .#granite root@granite --build-on-remote

# Secret management
agenix -e secret.age    # Create/edit
agenix --rekey          # Re-encrypt after key changes
```

## Module Conventions

1. **One module per directory** — each is a `default.nix` inside a named folder
2. **Consistent structure** — all use `mkEnable config { tags = [...]; }` pattern
3. **Tag categories**: `tui`, `gui`, `cli-tools`, `shell`, `editor`, `deploy`, `service`, `game`, `proxy`, `vpn`, `server`, `develop`, `media`, etc.
4. **Extra options** go inside the `mkEnable` attrs (e.g., `helix` has `enableLSP`)
5. **NixOS vs Home modules** may share names (e.g., both have `security`, `docker`, `fish`) — the NixOS one configures system services, the home one configures user programs

## Editor Setup

- **Primary editor**: Helix (`hx`) — configured with extensive LSP support for Nix (nixd), Python (ruff, ty/basedpyright), Rust (rust-analyzer), Go (gopls), TypeScript, and more
- **Secondary editor**: Nixvim (currently `enable = false` in the config) — full LazyVim-style setup with 30+ plugins
- **Formatter**: `nixfmt` for Nix files

## Proxy/VPN Infrastructure

The config has extensive proxy/VPN tooling (user is in Iran):
- **sing-box** configuration (commented out but fully defined in `modules/nixos/apps/gui/proxy/`)
- **v2rayn** GUI client with xray and sing-box backends
- **Throne** VPN with TUN mode
- **Tailscale** for mesh networking
- Various proxy tools: `go-graft`, `sshuttle`, `tun2socks`
- Docker registry mirror: `registry.docker.ir`
- Nix substituter: Tsinghua University mirror (priority 1)
- YouTube Music proxy: `socks5://127.0.0.1:2080`

## Media Stack (granite server)

Uses **nixflix** module for self-hosted media:
- Jellyfin (media server)
- Sonarr (TV), Radarr (movies), Lidarr (music)
- Prowlarr (indexer manager)
- Jellyseerr (request management)
- All credentials managed via agenix secrets

## Notable Patterns

- **Nushell as default shell** with zellij auto-start, vi mode, abbreviations, and custom completers (carapace, fish, zoxide)
- **Zellij** as terminal multiplexer with custom plugins (monocle, room) and keybindings
- **Hyprland** as Wayland compositor with hyprpanel, hypridle, hyprlock
- **Ghostty** as primary terminal emulator
- **Zen Browser** as primary browser (with Tridactyl for vim keybindings)
- **Floorp** as secondary browser
- **Git worktree workflow** — custom `git clone-bare` and `wt` helper functions
- **Starship** prompt with Kubernetes context awareness
- **direnv + nix-direnv** for per-project environments with `load_dotenv = true`

## Formatting

Run `nix fmt` — uses `nixfmt` (the official formatter, not `nixpkgs-fmt`).
