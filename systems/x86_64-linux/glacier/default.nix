{ ... }:
{
  imports = [ ./hardware-configuration.nix ];
  mine = {
    host = {
      name = "glacier";
      location = "Asia/Tehran";
    };

    tags.exclude = [ "server" ];

    gui.enable = true;
    tui.enable = true;

    grub.enable = true;
    systemd-boot.enable = false;
  };
}
