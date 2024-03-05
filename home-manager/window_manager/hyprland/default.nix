{ config, pkgs, lib, ... }: {
  wayland.windowManager.hyprland = {
    enableNvidiaPatches = true;
    enable = true;
  };
}
