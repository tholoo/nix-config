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
      "calendar"
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
        # Host: flint
        You are on **flint**, a Parspack KVM VPS in Tehran (x86_64, 4 vCPUs, 8GB RAM, 100GB disk).
        This is a remote production server. Be extra cautious — changes here affect live services.
        Prefer `deploy-rs` over direct `nixos-rebuild`.
      '';
    };

  };
}
