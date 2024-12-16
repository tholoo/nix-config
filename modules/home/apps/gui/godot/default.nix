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
  name = "godot";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "game"
    ];
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      godot_4-mono
    ];
  };
}
