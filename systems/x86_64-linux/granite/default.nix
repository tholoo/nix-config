{ modulesPath, ... }:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disk-config.nix
  ];
  mine = {
    host = {
      name = "elderwood";
      location = "Asia/Tehran";
    };

    gui.enable = true;
    tui.enable = true;
  };

  security.sudo.wheelNeedsPassword = false;
}
