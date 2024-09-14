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
  imports = [ ./hardware-configuration.nix ];
  mine = {
    host = {
      name = "elderwood";
      location = "Asia/Tehran";
    };

    tags.exclude = [ "server" ];

    gui.enable = true;
    tui.enable = true;

    grub.enable = true;
    systemd-boot.enable = false;
  };
}
