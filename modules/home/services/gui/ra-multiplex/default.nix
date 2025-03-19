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
  name = "ra-multiplex";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "service"
      "gui"
      "develop"
      "rust"
    ];
  };

  config = mkIf cfg.enable {
    systemd.user.services.ra-multiplex = {
      Install.WantedBy = [ "default.target" ];
      Unit.description = "ra-multiplex service";
      Service = {
        Type = "simple";
        ExecStart = "${lib.getExe pkgs.ra-multiplex} server";
        Restart = "on-failure";
      };
    };
  };
}
