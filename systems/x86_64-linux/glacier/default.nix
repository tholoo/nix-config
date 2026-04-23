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

  networking.hosts = {
    "192.168.1.101" = [ "elderwood" ];
  };

  systemd.services.nix-daemon.environment = {
    http_proxy = "socks5h://127.0.0.1:10808";
    https_proxy = "socks5h://127.0.0.1:10808";
    NIX_CURL_FLAGS = "-x socks5h://127.0.0.1:10808";
  };

  # Disable speaker buzzing sound
  boot.extraModprobeConfig = ''
    snd_hda_intel power_save=0
  '';
}
