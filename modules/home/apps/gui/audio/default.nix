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
  name = "audio";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "sound"
      "media"
    ];
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      qpwgraph
      helvum
    ];
  };
}
