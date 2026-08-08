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

  iranV2rayRulesBase = "https://raw.githubusercontent.com/Chocolate4U/Iran-v2ray-rules/release";
  iranGeoip = pkgs.fetchurl {
    url = "${iranV2rayRulesBase}/geoip.dat";
    sha256 = "0wb9qgx904nmqa8iagw0vxrliiq0p3v4lxv1lxxm5n1papbg60nk";
  };
  iranGeosite = pkgs.fetchurl {
    url = "${iranV2rayRulesBase}/geosite.dat";
    sha256 = "1144n5gvdm672957z9vwingp6llc30gs1ybl8x9w8457r8wrcf5b";
  };
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
      "v2rayN/bin/geoip.dat".source = iranGeoip;
      "v2rayN/bin/geosite.dat".source = iranGeosite;
    };
  };
}
