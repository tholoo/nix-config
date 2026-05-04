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
  name = "audacity";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "audio"
      "edit"
    ];
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [ audacity ];
  };
}
