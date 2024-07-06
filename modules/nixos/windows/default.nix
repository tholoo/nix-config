{
  pkgs,
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "windows";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "windows"
      "emulation"
    ];
  };

  config = mkIf cfg.enable {
    boot.binfmt.emulatedSystems = [ "x86_64-windows" ];
    environment.systemPackages = with pkgs; [
      wineWowPackages.waylandFull
      winetricks
    ];
  };
}
