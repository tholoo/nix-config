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
  name = "gui-proxy";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "proxy"
      "vpn"
    ];
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      v2rayn
    ];

    xdg.dataFile = {
      "v2rayN/bin/sing_box/sing-box".source = "${pkgs.sing-box}/bin/sing-box";
      "v2rayN/bin/xray/xray".source = "${pkgs.xray}/bin/xray";
      "v2rayN/bin/geoip.dat".source = "${pkgs.v2ray-geoip}/share/v2ray/geoip.dat";
      "v2rayN/bin/geosite.dat".source = "${pkgs.v2ray-domain-list-community}/share/v2ray/geosite.dat";
    };
  };
}
