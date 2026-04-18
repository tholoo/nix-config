{
  pkgs,
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf mkOption types;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "mihomo";

  configFile = (pkgs.formats.yaml { }).generate "config.yaml" (
    {
      "mixed-port" = cfg.port;
      "allow-lan" = true;
      "bind-address" = "0.0.0.0";
      mode = "rule";
      "log-level" = "info";
      ipv6 = false;
      "unified-delay" = true;
      "find-process-mode" = "off";
      "client-fingerprint" = "chrome";

      "external-controller" = "0.0.0.0:${toString cfg.apiPort}";
      secret = "";

      profile = {
        "store-selected" = true;
        "store-fake-ip" = true;
      };

      "geodata-mode" = true;
      "geo-auto-update" = false;

      tun = {
        enable = true;
        device = "mihomo";
        stack = "mixed";
        "dns-hijack" = [ "any:53" ];
        "auto-route" = true;
        "auto-detect-interface" = true;
      };

      dns = {
        enable = true;
        ipv6 = false;
        "enhanced-mode" = "fake-ip";
        "fake-ip-range" = "198.18.0.1/16";
        "fake-ip-filter" = [
          "*.lan"
          "*.local"
          "+.ir"
          "+.pool.ntp.org"
        ];
        "default-nameserver" = [
          "1.1.1.1"
          "8.8.8.8"
        ];
        nameserver = [
          "tls://1.1.1.1:853"
          "tls://8.8.8.8:853"
        ];
        "nameserver-policy" = {
          "+.ir" = [
            "78.157.42.100"
            "10.202.10.10"
          ];
        };
        fallback = [ "tls://1.0.0.1:853" ];
        "fallback-filter" = {
          geoip = true;
          "geoip-code" = "IR";
          domain = [ "+.ir" ];
        };
      };

      # proxy-providers injected at runtime from agenix secrets via preStart

      "proxy-groups" = [
        {
          name = "PROXY";
          type = "select";
          proxies =
            (lib.concatMap (sub: [
              "${sub.name}-Auto"
              "${sub.name}-Pick"
            ]) cfg.subscriptions)
            ++ [ "DIRECT" ];
        }
      ]
      ++ (map (sub: {
        name = "${sub.name}-Auto";
        type = "url-test";
        use = [ sub.name ];
        url = "http://cp.cloudflare.com/generate_204";
        interval = 300;
        tolerance = 50;
        lazy = true;
      }) cfg.subscriptions)
      ++ (map (sub: {
        name = "${sub.name}-Pick";
        type = "select";
        use = [ sub.name ];
      }) cfg.subscriptions);

      rules =
        (map (cidr: "IP-CIDR,${cidr},DIRECT") cfg.directCIDRs)
        ++ (map (domain: "DOMAIN-SUFFIX,${domain},DIRECT") cfg.directDomains)
        ++ [
          "IP-CIDR,127.0.0.0/8,DIRECT"
          "IP-CIDR,10.0.0.0/8,DIRECT"
          "IP-CIDR,172.16.0.0/12,DIRECT"
          "IP-CIDR,192.168.0.0/16,DIRECT"
          "DOMAIN-SUFFIX,ir,DIRECT"
          "GEOIP,IR,DIRECT,no-resolve"
          "MATCH,PROXY"
        ];
    }
    // lib.optionalAttrs (cfg.webui != null) {
      "external-ui" = "ui";
    }
  );

  providerScript = lib.concatMapStringsSep "\n" (sub: ''
    URL="$(cat "$CREDENTIALS_DIRECTORY/${sub.name}")"
    ${pkgs.curl}/bin/curl -sk --connect-timeout 15 -o /var/lib/mihomo/provider-${sub.name}.yaml "$URL" || true
    ${lib.getExe pkgs.yq-go} -i '.proxy-providers."${sub.name}" = {
      "type": "file",
      "path": "provider-${sub.name}.yaml",
      "health-check": {
        "enable": true,
        "url": "http://cp.cloudflare.com/generate_204",
        "interval": 300
      }
    }' /var/lib/mihomo/config.yaml
  '') cfg.subscriptions;
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "service"
      "server"
      "proxy"
      "vpn"
    ];

    port = mkOption {
      type = types.port;
      default = 7890;
      description = "Mixed HTTP/SOCKS5 listen port";
    };

    apiPort = mkOption {
      type = types.port;
      default = 9090;
      description = "Clash API port";
    };

    webui = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Web UI package (e.g. pkgs.metacubexd)";
    };

    subscriptions = mkOption {
      type =
        with types;
        listOf (submodule {
          options = {
            name = mkOption {
              type = str;
              description = "Display name for this subscription";
            };
            urlFile = mkOption {
              type = path;
              description = "Path to file containing the subscription URL (agenix secret)";
            };
          };
        });
      default = [ ];
      description = "Proxy subscriptions. Each gets Auto (url-test) and Pick (select) groups.";
    };

    directCIDRs = mkOption {
      type = with types; listOf str;
      default = [ ];
      description = "Extra CIDRs to route directly";
    };

    directDomains = mkOption {
      type = with types; listOf str;
      default = [ ];
      description = "Extra domain suffixes to route directly";
    };
  };

  config = mkIf cfg.enable {
    services.resolved.enable = true;
    networking = {
      firewall = {
        trustedInterfaces = [ "mihomo" ];
        checkReversePath = "loose";
        allowedTCPPorts = [
          cfg.port
          cfg.apiPort
        ];
      };
    };

    environment.systemPackages = [ pkgs.mihomo ];

    systemd.services.mihomo-sub-update = {
      description = "Refresh mihomo subscriptions";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        DynamicUser = true;
        StateDirectory = "mihomo";
        LoadCredential = map (sub: "${sub.name}:${sub.urlFile}") cfg.subscriptions;
      };
      script = lib.concatMapStringsSep "\n" (sub: ''
        URL="$(cat "$CREDENTIALS_DIRECTORY/${sub.name}")"
        ${pkgs.curl}/bin/curl -sk --connect-timeout 15 -o /var/lib/mihomo/provider-${sub.name}.yaml "$URL" || true
      '') cfg.subscriptions;
      postStart = "${pkgs.systemd}/bin/systemctl restart mihomo.service || true";
    };

    systemd.timers.mihomo-sub-update = {
      description = "Periodic mihomo subscription refresh";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5min";
        OnUnitActiveSec = "6h";
        RandomizedDelaySec = "5min";
      };
    };

    systemd.services.mihomo = {
      description = "Mihomo proxy daemon";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      preStart = ''
        install -m 0600 ${configFile} /var/lib/mihomo/config.yaml
        ln -sfn ${pkgs.v2ray-geoip}/share/v2ray/geoip.dat /var/lib/mihomo/GeoIP.dat
        ln -sfn ${pkgs.v2ray-domain-list-community}/share/v2ray/geosite.dat /var/lib/mihomo/GeoSite.dat
        ${lib.optionalString (cfg.webui != null) ''
          ln -sfn ${cfg.webui} /var/lib/mihomo/ui
        ''}
        ${providerScript}
      '';

      serviceConfig = {
        ExecStart = "${pkgs.mihomo}/bin/mihomo -d /var/lib/mihomo";
        Restart = "on-failure";
        RestartSec = "5s";
        DynamicUser = true;
        StateDirectory = "mihomo";
        LoadCredential = map (sub: "${sub.name}:${sub.urlFile}") cfg.subscriptions;
        AmbientCapabilities = [
          "CAP_NET_ADMIN"
          "CAP_NET_BIND_SERVICE"
          "CAP_NET_RAW"
        ];
        CapabilityBoundingSet = [
          "CAP_NET_ADMIN"
          "CAP_NET_BIND_SERVICE"
          "CAP_NET_RAW"
        ];
        PrivateDevices = false;
        PrivateUsers = false;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_NETLINK"
          "AF_UNIX"
        ];
      };
    };
  };
}
