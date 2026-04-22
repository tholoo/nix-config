{
  lib,
  pkgs,
  inputs,

  system, # The system architecture for this host (eg. `x86_64-linux`).
  target, # The Snowfall Lib target for this system (eg. `x86_64-iso`).
  format, # A normalized name for the system target (eg. `iso`).
  virtual, # A boolean to determine whether this system is a virtual target using nixos-generators.
  systems, # An attribute map of your defined hosts.

  config,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
  ];
  mine = {
    host = {
      name = "elderwood";
      location = "Asia/Tehran";
    };

    tags.exclude = [
      "gui"
      "game"
      "develop"
    ];

    gui.enable = false;
    tui.enable = true;

    grub.enable = true;
    systemd-boot.enable = false;

    mihomo = {
      enable = true;
      webui = pkgs.metacubexd;
      subscriptions = [
        {
          name = "main";
          urlFile = config.age.secrets.mihomo-sub-url-main.path;
        }
      ];
      directDomains = [
        "runflare.com"
      ];
    };

    dokploy.enable = false;
  };

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD";
  }; # Force intel-media-driver
}
