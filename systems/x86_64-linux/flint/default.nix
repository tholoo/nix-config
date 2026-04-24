{ pkgs, modulesPath, ... }:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disk-config.nix
  ];
  mine = {
    host = {
      name = "flint";
      location = "Asia/Tehran";
    };

    tui.enable = true;
    tags.exclude = [
      "game"
      "gui"
      "develop"
      "mount"
      "proxy"
      "vpn"
      "personal"
      "emulation"
    ];

    tui-misc.enable = false;

    systemd-boot.enable = false;
    syncthing.enable = false;

    k8s.enable = false;
    n8n.enable = false;
    llama-cpp.enable = false;
    homepage-dashboard.enable = false;
    uptime-kuma.enable = false;
    dokploy.enable = false;
  };

  security.sudo.wheelNeedsPassword = false;
  virtualisation.docker.daemon.settings.registry-mirrors = [ ];

  networking.firewall.allowedTCPPorts = [
    80
    443
    3000
  ];
}
