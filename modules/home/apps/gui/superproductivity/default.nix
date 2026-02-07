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
  name = "superproductivity";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "todo"
      "time"
    ];
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      super-productivity
    ];
  };
}
