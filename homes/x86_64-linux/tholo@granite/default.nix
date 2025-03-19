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
    ];

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
