{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "caffeine";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "window-manager"
    ];
  };

  config = mkIf cfg.enable {
    services.caffeine.enable = true;
  };
}
