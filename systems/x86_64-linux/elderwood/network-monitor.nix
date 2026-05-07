{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "network-monitor";

  runtimeDir = "/run/network-monitor";
  prometheusPort = 9091;

  mkStat =
    {
      id,
      title,
      expr,
      x,
    }:
    {
      inherit id title;
      type = "stat";
      datasource.uid = "prometheus";
      gridPos = {
        inherit x;
        y = 0;
        w = 4;
        h = 4;
      };
      targets = [
        {
          refId = "A";
          inherit expr;
        }
      ];
      fieldConfig.defaults = {
        unit = "bool";
        thresholds = {
          mode = "absolute";
          steps = [
            {
              color = "red";
              value = null;
            }
            {
              color = "green";
              value = 1;
            }
          ];
        };
      };
      options = {
        colorMode = "background";
        graphMode = "none";
        reduceOptions = {
          calcs = [ "lastNotNull" ];
          fields = "";
          values = false;
        };
      };
    };

  dashboardDir =
    let
      dashboard = pkgs.writeText "network-health-dashboard.json" (
        builtins.toJSON {
          title = "Network Health";
          uid = "network-health";
          schemaVersion = 39;
          version = 1;
          refresh = "10s";
          tags = [
            "network"
            "mikrotik"
          ];
          time = {
            from = "now-6h";
            to = "now";
          };
          templating.list = [ ];
          annotations.list = [ ];
          panels = [
            (mkStat {
              id = 1;
              title = "Router";
              x = 0;
              expr = ''probe_success{job="blackbox-icmp",role="router"}'';
            })
            (mkStat {
              id = 2;
              title = "Upstream Gateway";
              x = 4;
              expr = ''probe_success{job="blackbox-icmp",role="upstream_gateway"}'';
            })
            (mkStat {
              id = 3;
              title = "MikroTik DNS";
              x = 8;
              expr = ''probe_success{job="blackbox-dns-mikrotik",role="mikrotik_dns"}'';
            })
            {
              id = 4;
              type = "timeseries";
              title = "Interface Throughput";
              datasource.uid = "prometheus";
              gridPos = {
                x = 0;
                y = 4;
                w = 12;
                h = 8;
              };
              targets = [
                {
                  refId = "A";
                  legendFormat = "down {{ifName}}";
                  expr = ''sum by (ifName) (8 * rate(ifHCInOctets{job="mikrotik-snmp"}[5m]))'';
                }
                {
                  refId = "B";
                  legendFormat = "up {{ifName}}";
                  expr = ''sum by (ifName) (8 * rate(ifHCOutOctets{job="mikrotik-snmp"}[5m]))'';
                }
              ];
              fieldConfig.defaults.unit = "bps";
              options.legend = {
                displayMode = "list";
                placement = "bottom";
              };
            }
            {
              id = 5;
              type = "timeseries";
              title = "Probe Success";
              datasource.uid = "prometheus";
              gridPos = {
                x = 12;
                y = 0;
                w = 12;
                h = 6;
              };
              targets = [
                {
                  refId = "A";
                  legendFormat = "{{job}} {{role}}";
                  expr = ''probe_success{job=~"blackbox-.*"}'';
                }
              ];
              fieldConfig.defaults = {
                min = 0;
                max = 1;
                unit = "bool";
              };
            }
            {
              id = 6;
              type = "timeseries";
              title = "Probe Latency";
              datasource.uid = "prometheus";
              gridPos = {
                x = 12;
                y = 6;
                w = 12;
                h = 6;
              };
              targets = [
                {
                  refId = "A";
                  legendFormat = "{{job}} {{role}}";
                  expr = ''probe_duration_seconds{job=~"blackbox-.*"}'';
                }
              ];
              fieldConfig.defaults.unit = "s";
            }
          ];
        }
      );
    in
    pkgs.runCommand "network-health-grafana-dashboards" { } ''
      mkdir -p "$out"
      cp ${dashboard} "$out/network-health.json"
    '';
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "service"
      "tui"
      "server"
      "monitoring"
    ];
  };

  config = mkIf cfg.enable {
    age.secrets = {
      network-monitor-grafana-secret-key = {
        file = inputs.self + /secrets/network-monitor/grafana-secret-key.age;
        owner = "grafana";
      };
      network-monitor-config.file = inputs.self + /secrets/network-monitor/config.age;
    };

    systemd.services.network-monitor-runtime = {
      description = "Render Network Monitor runtime configuration";
      wantedBy = [
        "prometheus.service"
        "prometheus-blackbox-exporter.service"
        "prometheus-snmp-exporter.service"
      ];
      before = [
        "prometheus.service"
        "prometheus-blackbox-exporter.service"
        "prometheus-snmp-exporter.service"
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        RuntimeDirectory = "network-monitor";
        RuntimeDirectoryMode = "0755";
      };
      script =
        let
          jq = lib.getExe pkgs.jq;
        in
        ''
          set -eu

          config_file="${config.age.secrets.network-monitor-config.path}"
          router="$(${jq} -r '.router' "$config_file")"
          upstream_gateway="$(${jq} -r '.upstream_gateway' "$config_file")"
          isp_dns_servers="$(${jq} -c '.isp_dns_servers' "$config_file")"
          dns_probe_domain="$(${jq} -r '.dns_probe_domain' "$config_file")"
          snmp_community="$(${jq} -r '.snmp_community' "$config_file")"

          ${jq} -n \
            --arg router "$router" \
            --arg upstream_gateway "$upstream_gateway" \
            --argjson isp_dns_servers "$isp_dns_servers" \
            '[
              { targets: [$router], labels: { role: "router" } },
              { targets: [$upstream_gateway], labels: { role: "upstream_gateway" } },
              { targets: $isp_dns_servers, labels: { role: "isp_dns" } }
            ]' \
            > ${runtimeDir}/blackbox-icmp.json

          ${jq} -n \
            --arg router "$router" \
            '[{ targets: [($router + ":53")], labels: { role: "mikrotik_dns" } }]' \
            > ${runtimeDir}/blackbox-dns-mikrotik.json

          ${jq} -n \
            --arg router "$router" \
            '[{ targets: [$router], labels: { role: "router" } }]' \
            > ${runtimeDir}/mikrotik-snmp.json

          ${jq} -n \
            --arg domain "$dns_probe_domain" \
            '{
              modules: {
                icmp_ipv4: {
                  prober: "icmp",
                  timeout: "5s",
                  icmp: { preferred_ip_protocol: "ip4" }
                },
                dns_via_mikrotik: {
                  prober: "dns",
                  timeout: "5s",
                  dns: {
                    query_name: $domain,
                    query_type: "A",
                    valid_rcodes: ["NOERROR"],
                    transport_protocol: "udp",
                    preferred_ip_protocol: "ip4",
                    recursion_desired: true
                  }
                }
              }
            }' \
            > ${runtimeDir}/blackbox.yml

          ${jq} -n \
            --arg community "$snmp_community" \
            '{
              auths: {
                public_v2: {
                  community: $community,
                  version: 2
                }
              },
              modules: {
                if_mib: {
                  walk: [
                    "1.3.6.1.2.1.2.2.1.8",
                    "1.3.6.1.2.1.31.1.1.1.1",
                    "1.3.6.1.2.1.31.1.1.1.6",
                    "1.3.6.1.2.1.31.1.1.1.10"
                  ],
                  metrics: [
                    {
                      name: "ifName",
                      oid: "1.3.6.1.2.1.31.1.1.1.1",
                      type: "DisplayString",
                      help: "Interface name",
                      indexes: [{ labelname: "ifIndex", type: "gauge" }]
                    },
                    {
                      name: "ifOperStatus",
                      oid: "1.3.6.1.2.1.2.2.1.8",
                      type: "gauge",
                      help: "Interface operational status",
                      indexes: [{ labelname: "ifIndex", type: "gauge" }],
                      lookups: [{
                        labels: ["ifIndex"],
                        labelname: "ifName",
                        oid: "1.3.6.1.2.1.31.1.1.1.1",
                        type: "DisplayString"
                      }]
                    },
                    {
                      name: "ifHCInOctets",
                      oid: "1.3.6.1.2.1.31.1.1.1.6",
                      type: "counter",
                      help: "Inbound high capacity octets",
                      indexes: [{ labelname: "ifIndex", type: "gauge" }],
                      lookups: [{
                        labels: ["ifIndex"],
                        labelname: "ifName",
                        oid: "1.3.6.1.2.1.31.1.1.1.1",
                        type: "DisplayString"
                      }]
                    },
                    {
                      name: "ifHCOutOctets",
                      oid: "1.3.6.1.2.1.31.1.1.1.10",
                      type: "counter",
                      help: "Outbound high capacity octets",
                      indexes: [{ labelname: "ifIndex", type: "gauge" }],
                      lookups: [{
                        labels: ["ifIndex"],
                        labelname: "ifName",
                        oid: "1.3.6.1.2.1.31.1.1.1.1",
                        type: "DisplayString"
                      }]
                    }
                  ]
                }
              }
            }' \
            > ${runtimeDir}/snmp.yml

          chmod 0444 ${runtimeDir}/blackbox-icmp.json ${runtimeDir}/blackbox-dns-mikrotik.json \
            ${runtimeDir}/mikrotik-snmp.json ${runtimeDir}/blackbox.yml ${runtimeDir}/snmp.yml
        '';
    };

    services.prometheus = {
      enable = true;
      listenAddress = "0.0.0.0";
      port = prometheusPort;
      globalConfig.scrape_interval = "15s";

      exporters = {
        blackbox = {
          enable = true;
          listenAddress = "127.0.0.1";
          configFile = "${runtimeDir}/blackbox.yml";
          enableConfigCheck = false;
        };

        snmp = {
          enable = true;
          listenAddress = "127.0.0.1";
          configurationPath = "${runtimeDir}/snmp.yml";
          enableConfigCheck = false;
        };
      };

      scrapeConfigs = [
        {
          job_name = "blackbox-icmp";
          metrics_path = "/probe";
          params.module = [ "icmp_ipv4" ];
          file_sd_configs = [
            {
              files = [ "${runtimeDir}/blackbox-icmp.json" ];
              refresh_interval = "1m";
            }
          ];
          relabel_configs = [
            {
              source_labels = [ "__address__" ];
              target_label = "__param_target";
            }
            {
              source_labels = [ "__param_target" ];
              target_label = "instance";
            }
            {
              target_label = "__address__";
              replacement = "127.0.0.1:${toString config.services.prometheus.exporters.blackbox.port}";
            }
          ];
        }
        {
          job_name = "blackbox-dns-mikrotik";
          metrics_path = "/probe";
          params.module = [ "dns_via_mikrotik" ];
          file_sd_configs = [
            {
              files = [ "${runtimeDir}/blackbox-dns-mikrotik.json" ];
              refresh_interval = "1m";
            }
          ];
          relabel_configs = [
            {
              source_labels = [ "__address__" ];
              target_label = "__param_target";
            }
            {
              source_labels = [ "__param_target" ];
              target_label = "instance";
            }
            {
              target_label = "__address__";
              replacement = "127.0.0.1:${toString config.services.prometheus.exporters.blackbox.port}";
            }
          ];
        }
        {
          job_name = "mikrotik-snmp";
          metrics_path = "/snmp";
          params = {
            auth = [ "public_v2" ];
            module = [ "if_mib" ];
          };
          file_sd_configs = [
            {
              files = [ "${runtimeDir}/mikrotik-snmp.json" ];
              refresh_interval = "1m";
            }
          ];
          relabel_configs = [
            {
              source_labels = [ "__address__" ];
              target_label = "__param_target";
            }
            {
              source_labels = [ "__param_target" ];
              target_label = "instance";
            }
            {
              target_label = "__address__";
              replacement = "127.0.0.1:${toString config.services.prometheus.exporters.snmp.port}";
            }
          ];
        }
      ];

      rules = [
        ''
          groups:
            - name: network-health
              rules:
                - alert: MikroTikRouterDown
                  expr: probe_success{job="blackbox-icmp",role="router"} == 0
                  for: 2m
                  labels:
                    severity: critical
                  annotations:
                    summary: MikroTik router is unreachable from elderwood
                - alert: UpstreamGatewayDown
                  expr: probe_success{job="blackbox-icmp",role="upstream_gateway"} == 0
                  for: 2m
                  labels:
                    severity: warning
                  annotations:
                    summary: Upstream gateway is unreachable from elderwood
                - alert: MikroTikDnsDown
                  expr: probe_success{job="blackbox-dns-mikrotik",role="mikrotik_dns"} == 0
                  for: 2m
                  labels:
                    severity: critical
                  annotations:
                    summary: MikroTik DNS probe failed
                - alert: MikroTikSnmpDown
                  expr: up{job="mikrotik-snmp"} == 0
                  for: 5m
                  labels:
                    severity: warning
                  annotations:
                    summary: MikroTik SNMP scrape is failing
        ''
      ];
    };

    systemd.services.prometheus = {
      requires = [ "network-monitor-runtime.service" ];
      after = [ "network-monitor-runtime.service" ];
    };
    systemd.services.prometheus-blackbox-exporter = {
      requires = [ "network-monitor-runtime.service" ];
      after = [ "network-monitor-runtime.service" ];
    };
    systemd.services.prometheus-snmp-exporter = {
      requires = [ "network-monitor-runtime.service" ];
      after = [ "network-monitor-runtime.service" ];
    };

    services.grafana = {
      enable = true;
      openFirewall = true;
      settings = {
        security.secret_key = "$__file{${config.age.secrets.network-monitor-grafana-secret-key.path}}";
        server = {
          http_addr = "0.0.0.0";
          http_port = 3000;
          domain = "elderwood";
          root_url = "http://elderwood:3000/";
        };
      };
      provision = {
        enable = true;
        datasources.settings = {
          apiVersion = 1;
          prune = true;
          datasources = [
            {
              name = "Prometheus";
              uid = "prometheus";
              type = "prometheus";
              access = "proxy";
              url = "http://127.0.0.1:${toString prometheusPort}";
              isDefault = true;
            }
          ];
        };
        dashboards.settings = {
          apiVersion = 1;
          providers = [
            {
              name = "network";
              type = "file";
              options.path = dashboardDir;
            }
          ];
        };
      };
    };

    networking.firewall.allowedTCPPorts = [
      prometheusPort
      3000
    ];
  };
}
