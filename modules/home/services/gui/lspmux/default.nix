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
  name = "lspmux";
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
    systemd.user.services.lspmux = {
      Install.WantedBy = [ "default.target" ];
      Unit.description = "lspmux service";
      Service = {
        Type = "simple";
        ExecStart = "${lib.getExe pkgs.lspmux} server";
        Restart = "on-failure";
      };
    };
  };
}
