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
  name = "gpg-agent";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "service"
      "password"
    ];
  };

  config = mkIf cfg.enable {
    services.${name} = {
      enable = true;
      pinentryPackage = pkgs.pinentry-gnome3;
    };
  };
}
