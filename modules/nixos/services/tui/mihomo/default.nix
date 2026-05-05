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

  # Chocolate4U/Iran-clash-rules: daily-updated mihomo .mrs rule sets covering
  # Iranian domains, Iranian IP CIDRs, Iranian hosting providers, and security lists.
  iranRuleBase = "https://github.com/Chocolate4U/Iran-clash-rules/releases/latest/download";

  mkHttpProvider =
    {
      url,
      behavior,
      format ? "mrs",
      interval ? 86400,
    }:
    {
      type = "http";
      inherit
        behavior
        format
        url
        interval
        ;
      path = "./rules/${baseNameOf url}";
    };

  iranProviders =
    lib.optionalAttrs cfg.iranRules.enable {
      "ir-domains" = mkHttpProvider {
        url = "${iranRuleBase}/ir.mrs";
        behavior = "domain";
      };
      "ir-cidrs" = mkHttpProvider {
        url = "${iranRuleBase}/ircidr.mrs";
        behavior = "ipcidr";
      };
      "ir-arvancloud" = mkHttpProvider {
        url = "${iranRuleBase}/arvancloud.mrs";
        behavior = "ipcidr";
      };
      "ir-derakcloud" = mkHttpProvider {
        url = "${iranRuleBase}/derakcloud.mrs";
        behavior = "ipcidr";
      };
      "ir-iranserver" = mkHttpProvider {
        url = "${iranRuleBase}/iranserver.mrs";
        behavior = "ipcidr";
      };
      "ir-parspack" = mkHttpProvider {
        url = "${iranRuleBase}/parspack.mrs";
        behavior = "ipcidr";
      };
    }
    // lib.optionalAttrs cfg.iranRules.blockAds {
      # Iran-only ad list (~640 bytes); much narrower than category-ads-all,
      # very unlikely to break legitimate sites.
      "ir-ads" = mkHttpProvider {
        url = "${iranRuleBase}/ads.mrs";
        behavior = "domain";
      };
    }
    // lib.optionalAttrs cfg.iranRules.blockMalware {
      "malware" = mkHttpProvider {
        url = "${iranRuleBase}/malware.mrs";
        behavior = "domain";
      };
      "malware-ip" = mkHttpProvider {
        url = "${iranRuleBase}/malware-ip.mrs";
        behavior = "ipcidr";
      };
      "phishing" = mkHttpProvider {
        url = "${iranRuleBase}/phishing.mrs";
        behavior = "domain";
      };
      "phishing-ip" = mkHttpProvider {
        url = "${iranRuleBase}/phishing-ip.mrs";
        behavior = "ipcidr";
      };
      "cryptominers" = mkHttpProvider {
        url = "${iranRuleBase}/cryptominers.mrs";
        behavior = "domain";
      };
    };

  userProviders = lib.listToAttrs (
    map (
      rp:
      lib.nameValuePair rp.name (mkHttpProvider {
        inherit (rp) url behavior;
        format = rp.format;
        interval = rp.interval;
      })
    ) cfg.ruleProviders
  );

  allProviders = iranProviders // userProviders;

  # REJECT rules first so blocked traffic is dropped even if a later DIRECT rule would match.
  # IP-based rule sets need ,no-resolve to avoid a DNS round-trip for every connection.
  iranRejectRules =
    lib.optionals cfg.iranRules.blockAds [ "RULE-SET,ir-ads,REJECT" ]
    ++ lib.optionals cfg.iranRules.blockMalware [
      "RULE-SET,malware,REJECT"
      "RULE-SET,phishing,REJECT"
      "RULE-SET,cryptominers,REJECT"
      "RULE-SET,malware-ip,REJECT,no-resolve"
      "RULE-SET,phishing-ip,REJECT,no-resolve"
    ];

  iranDirectRules = lib.optionals cfg.iranRules.enable [
    "RULE-SET,ir-domains,DIRECT"
    "RULE-SET,ir-cidrs,DIRECT,no-resolve"
    "RULE-SET,ir-arvancloud,DIRECT,no-resolve"
    "RULE-SET,ir-derakcloud,DIRECT,no-resolve"
    "RULE-SET,ir-iranserver,DIRECT,no-resolve"
    "RULE-SET,ir-parspack,DIRECT,no-resolve"
  ];

  userRules = map (
    rp: "RULE-SET,${rp.name},${rp.target}" + lib.optionalString (rp.behavior == "ipcidr") ",no-resolve"
  ) cfg.ruleProviders;

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
        ]
        ++ iranRejectRules
        ++ iranDirectRules
        ++ userRules
        ++ [
          "DOMAIN-SUFFIX,ir,DIRECT"
          "GEOIP,IR,DIRECT,no-resolve"
          "MATCH,PROXY"
        ];
    }
    // lib.optionalAttrs (allProviders != { }) {
      "rule-providers" = allProviders;
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

    iranRules = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Pull Chocolate4U/Iran-clash-rules .mrs rule sets and route them DIRECT.
          Covers Iranian domains (ir.mrs), Iranian IP CIDRs (ircidr.mrs), and
          major Iranian hosting providers (Arvan, Derak, Iranserver, Parspack).
          Catches the long tail that GEOIP,IR misses (.com sites hosted in Iran,
          and Iranian IPs not yet in the v2ray geoip database).
        '';
      };
      blockAds = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Add the Iran-only ads list (ads.mrs, ~640 bytes) and REJECT matches.
          Narrow scope — only Iranian ad networks — so very unlikely to break
          legitimate sites. Does not include the broader category-ads-all list.
        '';
      };
      blockMalware = mkOption {
        type = types.bool;
        default = true;
        description = "REJECT known malware, phishing, and cryptominer domains/IPs.";
      };
    };

    ruleProviders = mkOption {
      type =
        with types;
        listOf (submodule {
          options = {
            name = mkOption {
              type = str;
              description = "Identifier used in the RULE-SET reference";
            };
            url = mkOption {
              type = str;
              description = "HTTP(S) URL to fetch the rule set from";
            };
            behavior = mkOption {
              type = enum [
                "domain"
                "ipcidr"
                "classical"
              ];
              description = "Rule behavior — must match the file's contents";
            };
            format = mkOption {
              type = enum [
                "mrs"
                "yaml"
                "text"
              ];
              default = "mrs";
              description = "On-disk format of the rule set";
            };
            target = mkOption {
              type = str;
              default = "DIRECT";
              description = "Action for matches (DIRECT, REJECT, PROXY, etc.)";
            };
            interval = mkOption {
              type = ints.positive;
              default = 86400;
              description = "Refresh interval in seconds";
            };
          };
        });
      default = [ ];
      description = ''
        Additional rule providers, fetched by mihomo on the configured interval.
        Injected into the rule chain after the iranRules sets and before the
        DOMAIN-SUFFIX,ir / GEOIP,IR fallback.
      '';
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

        ExecStartPost = "+${pkgs.systemd}/bin/systemctl restart mihomo.service";
      };

      script = ''
        fail=0
      ''
      + lib.concatMapStringsSep "\n" (sub: ''
        URL="$(cat "$CREDENTIALS_DIRECTORY/${sub.name}")"
        if ! ${pkgs.curl}/bin/curl -sSkL --connect-timeout 15 --max-time 60 --retry 3 --retry-delay 2 -o /var/lib/mihomo/provider-${sub.name}.yaml "$URL"; then
          echo "[mihomo-sub-update] failed to fetch ${sub.name}" >&2
          fail=1
        fi
      '') cfg.subscriptions
      + ''
        exit $fail
      '';
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
