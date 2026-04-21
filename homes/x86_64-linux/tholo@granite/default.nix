{ ... }:
{
  mine = {
    user = {
      name = "tholo";
      fullName = "tholo";
    };

    tui.enable = true;
    tags.exclude = [
      "game"
      "gui"
      "develop"
      "mount"
      "tui-misc"
      "vpn"
      "download"
      "productivity"
      "nix-index"
      "mcfly"
      "cli-cool"
      "calender"
      "personal"
    ];

    irc.enable = false;
    tox.enable = false;
    cli-cool.enable = false;
    kube.enable = false;
    nixvim.enable = false;
    proxy.enable = false;
    translate-shell.enable = false;

    helix = {
      enable = true;
      enableLSP = false;
    };

    claude-code = {
      enable = true;
      hostContext = ''
        # Host: granite
        You are on **granite**, a Hetzner Cloud server (x86_64, systemd-boot).
        This is a remote production server running media stack (nixflix), dokploy, and other services.
        Be extra cautious — changes here affect live services. Prefer `deploy-rs` over direct `nixos-rebuild`.
      '';
    };

  };
}
