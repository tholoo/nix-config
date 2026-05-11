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
  topSitesPort = 9914;
  serviceStatusPort = 9915;

  mkStat =
    {
      id,
      title,
      expr,
      x,
      y ? 0,
      w ? 4,
      h ? 4,
    }:
    {
      inherit id title;
      type = "stat";
      datasource.uid = "prometheus";
      gridPos = {
        inherit
          x
          y
          w
          h
          ;
      };
      targets = [
        {
          refId = "A";
          inherit expr;
        }
      ];
      fieldConfig.defaults = {
        unit = "bool";
        mappings = [
          {
            type = "value";
            options = {
              "0" = {
                text = "DOWN";
                color = "red";
              };
              "1" = {
                text = "UP";
                color = "green";
              };
            };
          }
        ];
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
        textMode = "value";
        reduceOptions = {
          calcs = [ "lastNotNull" ];
          fields = "";
          values = false;
        };
      };
    };

  mkMetricStat =
    {
      id,
      title,
      expr,
      unit,
      x,
      y ? 4,
      w ? 4,
      h ? 3,
      decimals ? 0,
    }:
    {
      inherit id title;
      type = "stat";
      datasource.uid = "prometheus";
      gridPos = {
        inherit
          x
          y
          w
          h
          ;
      };
      targets = [
        {
          refId = "A";
          instant = true;
          inherit expr;
        }
      ];
      fieldConfig.defaults = {
        inherit unit decimals;
        noValue = "No data";
        thresholds = {
          mode = "absolute";
          steps = [
            {
              color = "red";
              value = null;
            }
            {
              color = "green";
              value = 99;
            }
          ];
        };
      };
      options = {
        colorMode = "none";
        graphMode = "none";
        justifyMode = "center";
        textMode = "value";
        reduceOptions = {
          calcs = [ "lastNotNull" ];
          fields = "";
          values = false;
        };
      };
    };

  uptimeExpr = expr: ''100 * avg_over_time((${expr})[24h:])'';
  downForExpr = expr: ''((${expr}) == bool 0) * (time() - max_over_time(timestamp((${expr}) == 1)[30d:]))'';

  activeInBps = ''sum by (ifName) (8 * rate(ifHCInOctets{job="mikrotik-snmp"}[5m]) * on(instance, ifIndex) group_left() (ifOperStatus{job="mikrotik-snmp"} == 1))'';

  activeOutBps = ''sum by (ifName) (8 * rate(ifHCOutOctets{job="mikrotik-snmp"}[5m]) * on(instance, ifIndex) group_left() (ifOperStatus{job="mikrotik-snmp"} == 1))'';

  topSitesCollector = pkgs.writeText "network-monitor-top-sites.py" ''
    import ipaddress
    import json
    import os
    import re
    import sqlite3
    import time
    import urllib.error
    import urllib.request
    from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
    from threading import Lock, Thread

    API_URL = os.environ.get("MIHOMO_API_URL", "http://127.0.0.1:9090/connections")
    SECRET_FILE = os.environ.get("MIHOMO_SECRET_FILE") or os.path.join(
      os.environ["CREDENTIALS_DIRECTORY"],
      "mihomo-api-secret",
    )
    DB_PATH = os.environ.get("TOP_SITES_DB", "/var/lib/network-monitor/top-sites.sqlite")
    METRICS_HOST = os.environ.get("METRICS_HOST", "127.0.0.1")
    METRICS_PORT = int(os.environ.get("METRICS_PORT", "9914"))
    POLL_INTERVAL = float(os.environ.get("POLL_INTERVAL", "10"))
    TOP_LIMIT = int(os.environ.get("TOP_LIMIT", "20"))
    RETENTION_SECONDS = 24 * 60 * 60
    HOST_RE = re.compile(r"^[a-z0-9.-]+$")
    lock = Lock()
    last_success = 0
    last_poll = 0
    last_error = ""


    def read_secret():
      with open(SECRET_FILE, "r", encoding="utf-8") as f:
        return f.read().strip()


    def normalize_host(value):
      if not value:
        return None
      host = value.strip().lower().rstrip(".")
      if not host:
        return None
      if ":" in host and not host.startswith("["):
        host = host.split(":", 1)[0]
      if host.startswith("[") and host.endswith("]"):
        host = host[1:-1]
      try:
        ip = ipaddress.ip_address(host)
        if ip.is_private or ip.is_loopback or ip.is_link_local or ip.is_multicast:
          return None
        return None
      except ValueError:
        pass
      if host.endswith(".lan") or host.endswith(".local"):
        return None
      if "." not in host:
        return None
      if not HOST_RE.match(host):
        return None
      return host


    def init_db(conn):
      conn.execute("PRAGMA journal_mode = WAL")
      conn.execute("""
        CREATE TABLE IF NOT EXISTS connections (
          id TEXT PRIMARY KEY,
          domain TEXT NOT NULL,
          first_seen INTEGER NOT NULL
        )
      """)
      conn.execute("CREATE INDEX IF NOT EXISTS idx_connections_seen ON connections(first_seen)")
      conn.execute("CREATE INDEX IF NOT EXISTS idx_connections_domain ON connections(domain)")
      conn.commit()


    def connection_domain(item):
      meta = item.get("metadata") or {}
      for key in ("host", "destinationHost", "sniffHost"):
        host = normalize_host(str(meta.get(key) or ""))
        if host:
          return host
      return None


    def poll_once(conn, token):
      global last_success, last_poll, last_error
      req = urllib.request.Request(API_URL, headers={"Authorization": f"Bearer {token}"})
      with urllib.request.urlopen(req, timeout=5) as response:
        body = response.read()
      payload = json.loads(body.decode("utf-8"))
      now = int(time.time())
      inserted = 0
      for item in payload.get("connections", []):
        conn_id = item.get("id")
        domain = connection_domain(item)
        if not conn_id or not domain:
          continue
        cur = conn.execute(
          "INSERT OR IGNORE INTO connections (id, domain, first_seen) VALUES (?, ?, ?)",
          (str(conn_id), domain, now),
        )
        inserted += cur.rowcount
      conn.execute("DELETE FROM connections WHERE first_seen < ?", (now - RETENTION_SECONDS,))
      conn.commit()
      with lock:
        last_success = 1
        last_poll = now
        last_error = ""
      return inserted


    def poll_loop():
      global last_success, last_poll, last_error
      token = read_secret()
      os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
      conn = sqlite3.connect(DB_PATH, timeout=10)
      init_db(conn)
      while True:
        try:
          poll_once(conn, token)
        except Exception as exc:
          with lock:
            last_success = 0
            last_poll = int(time.time())
            last_error = exc.__class__.__name__
        time.sleep(POLL_INTERVAL)


    def metric_escape(value):
      return value.replace("\\", "\\\\").replace("\n", "\\n").replace('"', '\\"')


    def render_metrics():
      now = int(time.time())
      conn = sqlite3.connect(DB_PATH, timeout=10)
      lines = [
        "# HELP network_monitor_top_site_visits Unique mihomo connections first seen for a domain in the selected rolling window.",
        "# TYPE network_monitor_top_site_visits gauge",
      ]
      for window, seconds in (("1h", 3600), ("24h", 86400)):
        rows = conn.execute(
          """
          SELECT domain, COUNT(*) AS visits
          FROM connections
          WHERE first_seen >= ?
          GROUP BY domain
          ORDER BY visits DESC, domain ASC
          LIMIT ?
          """,
          (now - seconds, TOP_LIMIT),
        ).fetchall()
        for domain, visits in rows:
          lines.append(
            f'network_monitor_top_site_visits{{window="{window}",domain="{metric_escape(domain)}"}} {visits}'
          )
      tracked = conn.execute("SELECT COUNT(*) FROM connections").fetchone()[0]
      conn.close()
      with lock:
        success = last_success
        poll = last_poll
        error = last_error
      lines.extend([
        "# HELP network_monitor_top_sites_last_success Whether the last mihomo poll succeeded.",
        "# TYPE network_monitor_top_sites_last_success gauge",
        f"network_monitor_top_sites_last_success {success}",
        "# HELP network_monitor_top_sites_last_poll_timestamp_seconds Unix timestamp of the last mihomo poll.",
        "# TYPE network_monitor_top_sites_last_poll_timestamp_seconds gauge",
        f"network_monitor_top_sites_last_poll_timestamp_seconds {poll}",
        "# HELP network_monitor_top_sites_tracked_connections Connections retained in the top-sites database.",
        "# TYPE network_monitor_top_sites_tracked_connections gauge",
        f"network_monitor_top_sites_tracked_connections {tracked}",
        f'network_monitor_top_sites_last_error{{error="{metric_escape(error)}"}} {0 if error == "" else 1}',
      ])
      return ("\n".join(lines) + "\n").encode("utf-8")


    class Handler(BaseHTTPRequestHandler):
      def do_GET(self):
        if self.path != "/metrics":
          self.send_response(404)
          self.end_headers()
          return
        try:
          body = render_metrics()
          self.send_response(200)
          self.send_header("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
          self.send_header("Content-Length", str(len(body)))
          self.end_headers()
          self.wfile.write(body)
        except Exception:
          self.send_response(500)
          self.end_headers()

      def log_message(self, fmt, *args):
        return


    if __name__ == "__main__":
      Thread(target=poll_loop, daemon=True).start()
      ThreadingHTTPServer((METRICS_HOST, METRICS_PORT), Handler).serve_forever()
  '';

  serviceStatusCollector = pkgs.writeText "network-monitor-service-status.py" ''
    import json
    import os
    import sqlite3
    import time
    import urllib.error
    import urllib.request
    from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
    from threading import Lock, Thread

    DB_PATH = os.environ.get("SERVICE_STATUS_DB", "/var/lib/network-monitor-service-status/service-status.sqlite")
    METRICS_HOST = os.environ.get("METRICS_HOST", "127.0.0.1")
    METRICS_PORT = int(os.environ.get("METRICS_PORT", "9915"))
    POLL_INTERVAL = float(os.environ.get("POLL_INTERVAL", "30"))
    RETENTION_SECONDS = int(os.environ.get("RETENTION_SECONDS", str(30 * 24 * 60 * 60)))
    UPTIME_WINDOW_SECONDS = int(os.environ.get("UPTIME_WINDOW_SECONDS", str(24 * 60 * 60)))
    SERVICES = [
      {
        "id": "grafana",
        "name": "Grafana",
        "url": os.environ.get("GRAFANA_HEALTH_URL", "http://127.0.0.1:3000/api/health"),
      },
      {
        "id": "prometheus",
        "name": "Prometheus",
        "url": os.environ.get("PROMETHEUS_HEALTH_URL", "http://127.0.0.1:9091/-/ready"),
      },
    ]
    lock = Lock()
    current = {}


    def init_db(conn):
      conn.execute("PRAGMA journal_mode = WAL")
      conn.execute("""
        CREATE TABLE IF NOT EXISTS service_samples (
          service TEXT NOT NULL,
          ts INTEGER NOT NULL,
          up INTEGER NOT NULL,
          error TEXT NOT NULL DEFAULT "",
          PRIMARY KEY (service, ts)
        )
      """)
      conn.execute("CREATE INDEX IF NOT EXISTS idx_service_samples_service_ts ON service_samples(service, ts)")
      conn.commit()


    def check_url(url):
      req = urllib.request.Request(url, headers={"User-Agent": "elderwood-network-monitor/1.0"})
      with urllib.request.urlopen(req, timeout=5) as response:
        response.read(256)
        return 200 <= response.status < 400


    def record_sample(conn, service, up, error):
      now = int(time.time())
      conn.execute(
        "INSERT OR REPLACE INTO service_samples (service, ts, up, error) VALUES (?, ?, ?, ?)",
        (service["id"], now, 1 if up else 0, error),
      )
      conn.execute("DELETE FROM service_samples WHERE ts < ?", (now - RETENTION_SECONDS,))
      conn.commit()
      with lock:
        current[service["id"]] = {
          "service": service["id"],
          "name": service["name"],
          "url": service["url"],
          "up": 1 if up else 0,
          "status": "UP" if up else "DOWN",
          "lastChecked": now,
          "error": error,
        }


    def poll_loop():
      os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
      conn = sqlite3.connect(DB_PATH, timeout=10)
      init_db(conn)
      while True:
        for service in SERVICES:
          try:
            up = check_url(service["url"])
            record_sample(conn, service, up, "" if up else "bad_status")
          except Exception as exc:
            record_sample(conn, service, False, exc.__class__.__name__)
        time.sleep(POLL_INTERVAL)


    def service_summary(service_id):
      now = int(time.time())
      conn = sqlite3.connect(DB_PATH, timeout=10)
      row = conn.execute(
        "SELECT up, ts, error FROM service_samples WHERE service = ? ORDER BY ts DESC LIMIT 1",
        (service_id,),
      ).fetchone()
      if row is None:
        conn.close()
        service = next(item for item in SERVICES if item["id"] == service_id)
        return {
          "service": service_id,
          "name": service["name"],
          "status": "UNKNOWN",
          "up": 0,
          "uptimePercent": 0,
          "uptimeRatio": 0,
          "downSeconds": 0,
          "lastChecked": 0,
          "error": "no_samples",
        }

      up, last_checked, error = row
      uptime_row = conn.execute(
        "SELECT AVG(up) FROM service_samples WHERE service = ? AND ts >= ?",
        (service_id, now - UPTIME_WINDOW_SECONDS),
      ).fetchone()
      uptime_ratio = float(uptime_row[0] or 0)
      down_seconds = 0
      if up == 0:
        last_up = conn.execute(
          "SELECT MAX(ts) FROM service_samples WHERE service = ? AND up = 1",
          (service_id,),
        ).fetchone()[0]
        if last_up is None:
          down_since = conn.execute(
            "SELECT MIN(ts) FROM service_samples WHERE service = ?",
            (service_id,),
          ).fetchone()[0]
        else:
          down_since = conn.execute(
            "SELECT MIN(ts) FROM service_samples WHERE service = ? AND up = 0 AND ts > ?",
            (service_id, last_up),
          ).fetchone()[0]
        down_seconds = max(0, now - int(down_since or last_checked))
      conn.close()
      service = next(item for item in SERVICES if item["id"] == service_id)
      return {
        "service": service_id,
        "name": service["name"],
        "status": "UP" if up else "DOWN",
        "up": int(up),
        "uptimePercent": round(uptime_ratio * 100, 2),
        "uptimeRatio": uptime_ratio,
        "downSeconds": int(down_seconds),
        "lastChecked": int(last_checked),
        "error": error,
      }


    def metric_escape(value):
      return str(value).replace("\\", "\\\\").replace("\n", "\\n").replace('"', '\\"')


    def render_metrics():
      lines = [
        "# HELP network_monitor_service_up Whether the last local service health check succeeded.",
        "# TYPE network_monitor_service_up gauge",
        "# HELP network_monitor_service_uptime_ratio Ratio of successful local service health checks in the selected rolling window.",
        "# TYPE network_monitor_service_uptime_ratio gauge",
        "# HELP network_monitor_service_down_seconds Seconds the local service has been continuously down. Zero when up.",
        "# TYPE network_monitor_service_down_seconds gauge",
        "# HELP network_monitor_service_last_check_timestamp_seconds Unix timestamp of the last local service health check.",
        "# TYPE network_monitor_service_last_check_timestamp_seconds gauge",
      ]
      for service in SERVICES:
        summary = service_summary(service["id"])
        labels = f'service="{metric_escape(service["id"])}",name="{metric_escape(service["name"])}"'
        lines.extend([
          f"network_monitor_service_up{{{labels}}} {summary['up']}",
          f'network_monitor_service_uptime_ratio{{{labels},window="24h"}} {summary["uptimeRatio"]}',
          f"network_monitor_service_down_seconds{{{labels}}} {summary['downSeconds']}",
          f"network_monitor_service_last_check_timestamp_seconds{{{labels}}} {summary['lastChecked']}",
          f'network_monitor_service_error{{{labels},error="{metric_escape(summary["error"])}"}} {0 if summary["error"] == "" else 1}',
        ])
      return ("\n".join(lines) + "\n").encode("utf-8")


    class Handler(BaseHTTPRequestHandler):
      def do_GET(self):
        if self.path == "/metrics":
          body = render_metrics()
          self.send_response(200)
          self.send_header("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
          self.send_header("Content-Length", str(len(body)))
          self.end_headers()
          self.wfile.write(body)
          return
        if self.path.startswith("/status/"):
          service_id = self.path.rsplit("/", 1)[-1]
          if service_id not in {service["id"] for service in SERVICES}:
            self.send_response(404)
            self.end_headers()
            return
          body = (json.dumps(service_summary(service_id)) + "\n").encode("utf-8")
          self.send_response(200)
          self.send_header("Content-Type", "application/json")
          self.send_header("Content-Length", str(len(body)))
          self.end_headers()
          self.wfile.write(body)
          return
        self.send_response(404)
        self.end_headers()

      def log_message(self, fmt, *args):
        return


    if __name__ == "__main__":
      Thread(target=poll_loop, daemon=True).start()
      ThreadingHTTPServer((METRICS_HOST, METRICS_PORT), Handler).serve_forever()
  '';

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
              title = "Direct ISP Web";
              x = 0;
              w = 5;
              expr = ''max(probe_success{job="blackbox-http-direct"})'';
            })
            (mkStat {
              id = 2;
              title = "Proxy Web";
              x = 5;
              w = 5;
              expr = ''max(probe_success{job="blackbox-http-proxy"})'';
            })
            (mkStat {
              id = 3;
              title = "Router";
              x = 10;
              w = 4;
              expr = ''probe_success{job="blackbox-icmp",role="router"}'';
            })
            (mkStat {
              id = 4;
              title = "Upstream";
              x = 14;
              w = 5;
              expr = ''probe_success{job="blackbox-icmp",role="upstream_gateway"}'';
            })
            (mkStat {
              id = 5;
              title = "MikroTik DNS";
              x = 19;
              w = 5;
              expr = ''probe_success{job="blackbox-dns-mikrotik",role="mikrotik_dns"}'';
            })
            (mkMetricStat {
              id = 13;
              title = "Direct ISP Web Uptime 24h";
              x = 0;
              w = 5;
              unit = "percent";
              decimals = 2;
              expr = uptimeExpr ''max(probe_success{job="blackbox-http-direct"})'';
            })
            (mkMetricStat {
              id = 14;
              title = "Proxy Web Uptime 24h";
              x = 5;
              w = 5;
              unit = "percent";
              decimals = 2;
              expr = uptimeExpr ''max(probe_success{job="blackbox-http-proxy"})'';
            })
            (mkMetricStat {
              id = 15;
              title = "Router Uptime 24h";
              x = 10;
              w = 4;
              unit = "percent";
              decimals = 2;
              expr = uptimeExpr ''probe_success{job="blackbox-icmp",role="router"}'';
            })
            (mkMetricStat {
              id = 16;
              title = "Upstream Uptime 24h";
              x = 14;
              w = 5;
              unit = "percent";
              decimals = 2;
              expr = uptimeExpr ''probe_success{job="blackbox-icmp",role="upstream_gateway"}'';
            })
            (mkMetricStat {
              id = 17;
              title = "MikroTik DNS Uptime 24h";
              x = 19;
              w = 5;
              unit = "percent";
              decimals = 2;
              expr = uptimeExpr ''probe_success{job="blackbox-dns-mikrotik",role="mikrotik_dns"}'';
            })
            (mkMetricStat {
              id = 18;
              title = "Direct ISP Web Down For";
              x = 0;
              y = 7;
              w = 5;
              unit = "s";
              expr = downForExpr ''max(probe_success{job="blackbox-http-direct"})'';
            })
            (mkMetricStat {
              id = 19;
              title = "Proxy Web Down For";
              x = 5;
              y = 7;
              w = 5;
              unit = "s";
              expr = downForExpr ''max(probe_success{job="blackbox-http-proxy"})'';
            })
            (mkMetricStat {
              id = 20;
              title = "Router Down For";
              x = 10;
              y = 7;
              w = 4;
              unit = "s";
              expr = downForExpr ''probe_success{job="blackbox-icmp",role="router"}'';
            })
            (mkMetricStat {
              id = 21;
              title = "Upstream Down For";
              x = 14;
              y = 7;
              w = 5;
              unit = "s";
              expr = downForExpr ''probe_success{job="blackbox-icmp",role="upstream_gateway"}'';
            })
            (mkMetricStat {
              id = 22;
              title = "MikroTik DNS Down For";
              x = 19;
              y = 7;
              w = 5;
              unit = "s";
              expr = downForExpr ''probe_success{job="blackbox-dns-mikrotik",role="mikrotik_dns"}'';
            })
            {
              id = 6;
              type = "timeseries";
              title = "Top Active Router Interfaces";
              datasource.uid = "prometheus";
              gridPos = {
                x = 0;
                y = 10;
                w = 14;
                h = 8;
              };
              targets = [
                {
                  refId = "A";
                  legendFormat = "down {{ifName}}";
                  expr = "topk(8, ${activeInBps})";
                }
                {
                  refId = "B";
                  legendFormat = "up {{ifName}}";
                  expr = "topk(8, ${activeOutBps})";
                }
              ];
              fieldConfig.defaults.unit = "bps";
              options.legend = {
                displayMode = "table";
                placement = "bottom";
                calcs = [
                  "lastNotNull"
                  "max"
                ];
              };
            }
            {
              id = 7;
              type = "timeseries";
              title = "Web Probe Success";
              datasource.uid = "prometheus";
              gridPos = {
                x = 14;
                y = 10;
                w = 10;
                h = 4;
              };
              targets = [
                {
                  refId = "A";
                  legendFormat = "{{path}} {{target_host}}";
                  expr = ''probe_success{job=~"blackbox-http-direct|blackbox-http-proxy"}'';
                }
              ];
              fieldConfig.defaults = {
                min = 0;
                max = 1;
                unit = "bool";
              };
              options.legend = {
                displayMode = "list";
                placement = "bottom";
              };
            }
            {
              id = 8;
              type = "timeseries";
              title = "Local Probe Success";
              datasource.uid = "prometheus";
              gridPos = {
                x = 14;
                y = 14;
                w = 10;
                h = 4;
              };
              targets = [
                {
                  refId = "A";
                  legendFormat = "{{job}} {{role}}";
                  expr = ''probe_success{job=~"blackbox-icmp|blackbox-dns-mikrotik"}'';
                }
              ];
              fieldConfig.defaults = {
                min = 0;
                max = 1;
                unit = "bool";
              };
            }
            {
              id = 9;
              type = "timeseries";
              title = "Web Latency";
              datasource.uid = "prometheus";
              gridPos = {
                x = 0;
                y = 18;
                w = 12;
                h = 6;
              };
              targets = [
                {
                  refId = "A";
                  legendFormat = "{{path}} {{target_host}}";
                  expr = ''probe_duration_seconds{job=~"blackbox-http-direct|blackbox-http-proxy"}'';
                }
              ];
              fieldConfig.defaults.unit = "s";
            }
            {
              id = 10;
              type = "timeseries";
              title = "Local Probe Latency";
              datasource.uid = "prometheus";
              gridPos = {
                x = 12;
                y = 18;
                w = 12;
                h = 6;
              };
              targets = [
                {
                  refId = "A";
                  legendFormat = "{{job}} {{role}}";
                  expr = ''probe_duration_seconds{job=~"blackbox-icmp|blackbox-dns-mikrotik"}'';
                }
              ];
              fieldConfig.defaults.unit = "s";
            }
            {
              id = 11;
              type = "table";
              title = "Top Visited Domains - 1h";
              datasource.uid = "prometheus";
              gridPos = {
                x = 0;
                y = 24;
                w = 12;
                h = 7;
              };
              targets = [
                {
                  refId = "A";
                  expr = ''topk(20, network_monitor_top_site_visits{window="1h"})'';
                  format = "table";
                  instant = true;
                }
              ];
              transformations = [
                {
                  id = "organize";
                  options = {
                    excludeByName = {
                      Time = true;
                      "__name__" = true;
                      job = true;
                      instance = true;
                      window = true;
                    };
                    renameByName = {
                      domain = "Domain";
                      Value = "Visits";
                    };
                  };
                }
              ];
              options.showHeader = true;
            }
            {
              id = 12;
              type = "table";
              title = "Top Visited Domains - 24h";
              datasource.uid = "prometheus";
              gridPos = {
                x = 12;
                y = 24;
                w = 12;
                h = 7;
              };
              targets = [
                {
                  refId = "A";
                  expr = ''topk(20, network_monitor_top_site_visits{window="24h"})'';
                  format = "table";
                  instant = true;
                }
              ];
              transformations = [
                {
                  id = "organize";
                  options = {
                    excludeByName = {
                      Time = true;
                      "__name__" = true;
                      job = true;
                      instance = true;
                      window = true;
                    };
                    renameByName = {
                      domain = "Domain";
                      Value = "Visits";
                    };
                  };
                }
              ];
              options.showHeader = true;
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
          direct_http_probe_urls="$(${jq} -c '.direct_http_probe_urls // .http_probe_urls // ["https://digikala.com", "https://cafebazaar.ir"]' "$config_file")"
          proxy_http_probe_urls="$(${jq} -c '.proxy_http_probe_urls // ["https://cp.cloudflare.com/generate_204", "https://www.gstatic.com/generate_204"]' "$config_file")"
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
            --argjson urls "$direct_http_probe_urls" \
            '$urls | map({
              targets: [.],
              labels: {
                path: "direct",
                role: "direct_web",
                target_host: (. | sub("^https?://"; "") | split("/")[0])
              }
            })' \
            > ${runtimeDir}/blackbox-http-direct.json

          ${jq} -n \
            --argjson urls "$proxy_http_probe_urls" \
            '$urls | map({
              targets: [.],
              labels: {
                path: "proxy",
                role: "proxy_web",
                target_host: (. | sub("^https?://"; "") | split("/")[0])
              }
            })' \
            > ${runtimeDir}/blackbox-http-proxy.json

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
                },
                http_usable_web: {
                  prober: "http",
                  timeout: "8s",
                  http: {
                    preferred_ip_protocol: "ip4",
                    valid_status_codes: [200, 204, 301, 302, 307, 308],
                    method: "GET"
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
            ${runtimeDir}/blackbox-http-direct.json ${runtimeDir}/blackbox-http-proxy.json \
            ${runtimeDir}/mikrotik-snmp.json ${runtimeDir}/blackbox.yml ${runtimeDir}/snmp.yml
        '';
    };

    systemd.services.network-monitor-top-sites = {
      description = "Collect domain-only top visited sites from mihomo";
      wantedBy = [ "multi-user.target" ];
      after = [
        "mihomo.service"
        "network-online.target"
      ];
      wants = [
        "mihomo.service"
        "network-online.target"
      ];
      environment = {
        MIHOMO_API_URL = "http://127.0.0.1:${toString config.mine.mihomo.apiPort}/connections";
        TOP_SITES_DB = "/var/lib/network-monitor/top-sites.sqlite";
        METRICS_HOST = "127.0.0.1";
        METRICS_PORT = toString topSitesPort;
        POLL_INTERVAL = "10";
        TOP_LIMIT = "20";
      };
      serviceConfig = {
        ExecStart = "${pkgs.python3}/bin/python3 ${topSitesCollector}";
        Restart = "on-failure";
        RestartSec = "5s";
        DynamicUser = true;
        StateDirectory = "network-monitor";
        LoadCredential = [ "mihomo-api-secret:${config.age.secrets.mihomo-api-secret.path}" ];
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
      };
    };

    systemd.services.network-monitor-service-status = {
      description = "Collect local Grafana and Prometheus availability history";
      wantedBy = [ "multi-user.target" ];
      after = [
        "grafana.service"
        "prometheus.service"
      ];
      wants = [
        "grafana.service"
        "prometheus.service"
      ];
      environment = {
        SERVICE_STATUS_DB = "/var/lib/network-monitor-service-status/service-status.sqlite";
        METRICS_HOST = "127.0.0.1";
        METRICS_PORT = toString serviceStatusPort;
        POLL_INTERVAL = "30";
        UPTIME_WINDOW_SECONDS = toString (24 * 60 * 60);
      };
      serviceConfig = {
        ExecStart = "${pkgs.python3}/bin/python3 ${serviceStatusCollector}";
        Restart = "on-failure";
        RestartSec = "5s";
        DynamicUser = true;
        StateDirectory = "network-monitor-service-status";
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
      };
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
          job_name = "blackbox-http-direct";
          scrape_interval = "2m";
          metrics_path = "/probe";
          params.module = [ "http_usable_web" ];
          file_sd_configs = [
            {
              files = [ "${runtimeDir}/blackbox-http-direct.json" ];
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
          job_name = "blackbox-http-proxy";
          scrape_interval = "2m";
          metrics_path = "/probe";
          params.module = [ "http_usable_web" ];
          file_sd_configs = [
            {
              files = [ "${runtimeDir}/blackbox-http-proxy.json" ];
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
        {
          job_name = "network-monitor-service-status";
          static_configs = [
            {
              targets = [ "127.0.0.1:${toString serviceStatusPort}" ];
            }
          ];
        }
        {
          job_name = "network-monitor-top-sites";
          static_configs = [
            {
              targets = [ "127.0.0.1:${toString topSitesPort}" ];
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
                - alert: DirectWebDown
                  expr: max(probe_success{job="blackbox-http-direct"}) == 0
                  for: 2m
                  labels:
                    severity: critical
                  annotations:
                    summary: No configured direct HTTP probe target is reachable
                - alert: ProxyWebDown
                  expr: max(probe_success{job="blackbox-http-proxy"}) == 0
                  for: 2m
                  labels:
                    severity: warning
                  annotations:
                    summary: No configured proxy HTTP probe target is reachable
                - alert: MikroTikSnmpDown
                  expr: up{job="mikrotik-snmp"} == 0
                  for: 5m
                  labels:
                    severity: warning
                  annotations:
                    summary: MikroTik SNMP scrape is failing
                - alert: TopSitesCollectorDown
                  expr: up{job="network-monitor-top-sites"} == 0 or network_monitor_top_sites_last_success == 0
                  for: 5m
                  labels:
                    severity: warning
                  annotations:
                    summary: Top sites collector is not scraping mihomo successfully
                - alert: LocalServiceStatusCollectorDown
                  expr: up{job="network-monitor-service-status"} == 0
                  for: 5m
                  labels:
                    severity: warning
                  annotations:
                    summary: Local Grafana/Prometheus status collector is down
                - alert: GrafanaDown
                  expr: network_monitor_service_up{service="grafana"} == 0
                  for: 2m
                  labels:
                    severity: warning
                  annotations:
                    summary: Grafana is down on elderwood
                - alert: PrometheusDown
                  expr: network_monitor_service_up{service="prometheus"} == 0
                  for: 2m
                  labels:
                    severity: critical
                  annotations:
                    summary: Prometheus is down on elderwood
        ''
      ];
    };

    systemd.services.prometheus = {
      wants = [
        "network-monitor-service-status.service"
        "network-monitor-top-sites.service"
      ];
      requires = [ "network-monitor-runtime.service" ];
      after = [
        "network-monitor-runtime.service"
        "network-monitor-top-sites.service"
      ];
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
