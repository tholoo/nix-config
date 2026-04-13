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

  # Disable speaker buzzing sound
  boot.extraModprobeConfig = ''
    snd_hda_intel power_save=0
  '';

  # Use s2idle instead of S3 deep sleep so Bluetooth controller stays
  # powered enough to receive wake signals from BT keyboard
  boot.kernelParams = [ "mem_sleep_default=s2idle" ];
}
