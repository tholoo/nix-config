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
  name = "tox";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "chat"
    ];
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      toxic
    ];
  };
}
