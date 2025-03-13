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
  name = "proxy";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "vpn"
    ];
  };

  config = mkIf cfg.enable {
    # https://github.com/MatsuriDayo/nekoray/issues/1437
    services.resolved.enable = true;
    networking.firewall.checkReversePath = "loose";
    networking.firewall.trustedInterfaces = [ "tun0" ];
    # networking.proxy.default = "http://127.0.0.1:12334";
    environment.systemPackages = with pkgs; [
      hiddify-app
    ];
  };
}
