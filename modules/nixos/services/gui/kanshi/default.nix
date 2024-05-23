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
  name = "kanshi";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "sway"
      "wayland"
    ];
  };
  config = mkIf cfg.enable {

    # for sway
    systemd.user.services.kanshi = {
      description = "kanshi daemon";
      serviceConfig = {
        Type = "simple";
        ExecStart = "${lib.getExe pkgs.kanshi} -c kanshi_config_file";
      };
    };
  };
}
