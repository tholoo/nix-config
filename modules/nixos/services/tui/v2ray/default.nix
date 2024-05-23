{ config, lib, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "v2ray";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "service"
      "tui"
      "proxy"
      "vpn"
    ];
  };

  config = mkIf cfg.enable {
    # systemd.services.vpn = {
    # wantedBy = [ "multi-user.target" ];
    # after = [ "network.target" ];
    # description = "V2Ray Service";
    # serviceConfig = {
    # Type = "simple";
    # User = "${username}";
    # ExecStart = "${pkgs.v2ray}/bin/v2ray run --config=/home/${username}/v2ray/config.json";
    # Restart = "on-failure";
    # };
    # };
  };
}
