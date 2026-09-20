{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.mine.tholo;
in
{
  options.mine.tholo = lib.mine.mkEnable config {
    tags = [
      "tui"
      "develop"
    ];
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.mine.tholo ];
  };
}
