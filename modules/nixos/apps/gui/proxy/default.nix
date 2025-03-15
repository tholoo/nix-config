{
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

    services.sing-box = {
      enable = true;
      settings = {
        dns = {
          final = "dns-remote";
          independent_cache = true;
          rules = [
            {
              domain = {
                _secret = config.age.secrets.singbox-domain.path;
              };
              server = "dns-direct";
            }
            {
              domain = "cp.cloudflare.com";
              rewrite_ttl = 3000;
              server = "dns-remote";
            }
            {
              domain_suffix = ".ir";
              server = "dns-direct";
            }
            {
              rule_set = [
                "geoip-ir"
                "geosite-ir"
              ];
              server = "dns-direct";
            }
          ];
          servers = [
            {
              address = "udp://1.1.1.1";
              address_resolver = "dns-direct";
              tag = "dns-remote";
            }
            {
              address = "1.1.1.1";
              address_resolver = "dns-local";
              detour = "direct";
              tag = "dns-direct";
            }
            {
              address = "local";
              detour = "direct";
              tag = "dns-local";
            }
            {
              address = "rcode://success";
              tag = "dns-block";
            }
          ];
        };
        experimental = {
          cache_file = {
            enabled = true;
            path = "clash.db";
          };
          clash_api = {
            external_controller = "127.0.0.1:16756";
            secret = {
              _secret = config.age.secrets.singbox-clash-pass.path;
            };
          };
        };
        inbounds = [
          {
            address = [ "172.19.0.1/28" ];
            auto_route = true;
            domain_strategy = "ipv4_only";
            endpoint_independent_nat = true;
            mtu = 9000;
            sniff = true;
            stack = "gvisor";
            tag = "tun-in";
            type = "tun";
          }
          {
            domain_strategy = "ipv4_only";
            listen = "127.0.0.1";
            listen_port = 12334;
            sniff = true;
            sniff_override_destination = true;
            tag = "mixed-in";
            type = "mixed";
          }
          {
            listen = "127.0.0.1";
            listen_port = 16450;
            tag = "dns-in";
            type = "direct";
          }
        ];
        log = {
          level = "debug";
          timestamp = true;
        };
        outbounds = [
          {
            default = "auto";
            interrupt_exist_connections = true;
            outbounds = [
              "auto"
              "hys2 § 0"
            ];
            tag = "select";
            type = "selector";
          }
          {
            idle_timeout = "3h0m0s";
            interrupt_exist_connections = true;
            interval = "1h0m0s";
            outbounds = [ "hys2 § 0" ];
            tag = "auto";
            tolerance = 1;
            type = "urltest";
            url = "http://cp.cloudflare.com";
          }
          {
            obfs = {
              password = {
                _secret = config.age.secrets.singbox-obfs-pass.path;
              };
              type = "salamander";
            };
            password = {
              _secret = config.age.secrets.singbox-pass.path;
            };
            server = {
              _secret = config.age.secrets.singbox-domain.path;
            };
            server_port = 33735;
            tag = "hys2 § 0";
            tls = {
              enabled = true;
            };
            type = "hysteria2";
          }
          {
            tag = "dns-out";
            type = "dns";
          }
          {
            tag = "direct";
            type = "direct";
          }
          {
            tag = "direct-fragment";
            type = "direct";
          }
          {
            tag = "bypass";
            type = "direct";
          }
        ];
        route = {
          auto_detect_interface = true;
          final = "select";
          override_android_vpn = true;
          rule_set = [
            {
              format = "binary";
              tag = "geoip-ir";
              type = "remote";
              update_interval = "120h0m0s";
              url = "https://raw.githubusercontent.com/hiddify/hiddify-geo/rule-set/country/geoip-ir.srs";
            }
            {
              format = "binary";
              tag = "geosite-ir";
              type = "remote";
              update_interval = "120h0m0s";
              url = "https://raw.githubusercontent.com/hiddify/hiddify-geo/rule-set/country/geosite-ir.srs";
            }
          ];
          rules = [
            {
              inbound = "dns-in";
              outbound = "dns-out";
            }
            {
              outbound = "dns-out";
              port = 53;
            }
            {
              ip_is_private = true;
              outbound = "bypass";
            }
            {
              domain_suffix = ".ir";
              outbound = "direct";
            }
            {
              outbound = "direct";
              rule_set = [
                "geoip-ir"
                "geosite-ir"
              ];
            }
          ];
        };
      };
    };
  };
}
