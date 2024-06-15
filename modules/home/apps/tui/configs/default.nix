{ config, lib, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "configs";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "cli-tools"
      "config"
    ];
  };

  config = mkIf cfg.enable {
    home.file = {
      ".ipython/profile_default/ipython_config.py".source = ./ipython_config.py;
    };
  };
}
