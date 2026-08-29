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
      "ai"
      "mount"
      "tui-misc"
      "vpn"
      "download"
      "productivity"
      "nix-index"
      "cli-cool"
      "calendar"
      "personal"
    ];

    irc.enable = false;
    codex.enable = false;
    claude-code.enable = false;
    pi.enable = false;
    git.enableCopilot = false;
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

  };
}
