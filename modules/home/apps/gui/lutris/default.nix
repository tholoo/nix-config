{
  inputs,
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "lutris";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "game"
      "emulator"
    ];
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      heroic
      mangohud
      winetricks
      gamescope
      gamemode
      umu-launcher
      vulkan-tools
      dxvk
      vkd3d
      wineWowPackages.staging
    ];

    programs.${name} = {
      enable = true;
      # package = pkgs.lutris.override {
      # steamSupport = true;
      # };
      # steamPackage = pkgs.steam;
      extraPackages = with pkgs; [
        mangohud
        winetricks
        gamescope
        gamemode
        umu-launcher
        vulkan-tools
        dxvk
        vkd3d
      ];
      winePackages = with pkgs; [
        wineWow64Packages.full
        wineWowPackages.staging
      ];
      runners = {
        wine = {
          package = pkgs.wineWow64Packages.staging;
          settings = {
            runner = {
              WINEFSYNC = "1";
              WINEESYNC = "1";
            };
            system = {
              disable_screen_saver = true;
              sandbox = false;
            };
          };
        };
      };
      protonPackages = with pkgs; [
        proton-ge-bin
      ];
    };
  };
}
