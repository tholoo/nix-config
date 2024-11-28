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
  name = "dbus";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "service"
      "tui"
    ];
  };

  config = mkIf cfg.enable {
    services.${name} = {
      packages = with pkgs; [ gcr ];
    };
  };
}
