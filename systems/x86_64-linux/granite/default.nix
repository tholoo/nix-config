{ modulesPath, ... }:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disk-config.nix
  ];
  mine = {
    host = {
      name = "granite";
      location = "Asia/Tehran";
    };

    tui.enable = true;
    tags.exclude = [
      "game"
      "gui"
      "develop"
    ];

    systemd-boot.enable = false;
    syncthing.enable = false;
  };

  security.sudo.wheelNeedsPassword = false;
  # services.minecraft-server.serverProperties.jvmOpts = "-Xmx512M -Xms512M";
  virtualisation.docker.daemon.settings.registry-mirrors = [ ]; # disable ir mirror
}
