{ pkgs, ... }:
let
  internet = pkgs.writeTextFile {
    name = "internet";
    destination = "/bin/internet";
    executable = true;
    text = # nu
      ''
        #!${pkgs.nushell}/bin/nu

        const default_router = "192.168.88.1"
        const default_router_port = "22"
        const default_probe_domain = "digikala.com"
        const default_probe_url = "https://digikala.com"

        def env-or-default [name: string, default: string] {
          if ($name in $env) {
            $env | get $name
          } else {
            $default
          }
        }

        def dns-servers [] {
          if ("INTERNET_DNS_SERVERS" in $env) {
            $env.INTERNET_DNS_SERVERS
            | split row ","
            | each {|server| $server | str trim }
            | where {|server| $server != "" }
          } else {
            []
          }
        }

        def probe-domain [] {
          env-or-default "INTERNET_DNS_DOMAIN" $default_probe_domain
        }

        def probe-url [] {
          env-or-default "INTERNET_PROBE_URL" $default_probe_url
        }

        def run-probe [command: closure] {
          let result = (
            try {
              do $command
            } catch {
              { exit_code: 1, stdout: "", stderr: "" }
            }
          )

          $result.exit_code == 0
        }

        def tcp-ok [host: string, port: string] {
          run-probe { ^${pkgs.coreutils}/bin/timeout 2 ${pkgs.bash}/bin/bash -c $"</dev/tcp/($host)/($port)" | complete }
        }

        def parse-dig-answers [stdout: string] {
          $stdout
          | str trim
          | lines
          | where {|line| $line =~ '^\d{1,3}(\.\d{1,3}){3}$' }
        }

        def dns-status [server?: string] {
          let domain = (probe-domain)
          let result = (
            try {
              if ($server == null) {
                ^${pkgs.dnsutils}/bin/dig +time=2 +tries=1 +short $domain A | complete
              } else {
                ^${pkgs.dnsutils}/bin/dig +time=2 +tries=1 +short @$server $domain A | complete
              }
            } catch {
              { exit_code: 1, stdout: "", stderr: "" }
            }
          )

          let answers = (parse-dig-answers $result.stdout)

          {
            server: ($server | default "system"),
            ok: (($result.exit_code == 0) and (($answers | length) > 0)),
            answers: $answers,
          }
        }

        def https-status [] {
          let url = (probe-url)
          let result = (
            try {
              ^${pkgs.curl}/bin/curl -fsS --max-time 8 -o /dev/null -w "%{http_code}" $url | complete
            } catch {
              { exit_code: 1, stdout: "", stderr: "" }
            }
          )

          {
            url: $url,
            ok: ($result.exit_code == 0),
            status: ($result.stdout | str trim),
            error: ($result.stderr | str trim),
          }
        }

        def status-record [] {
          let router = (env-or-default "INTERNET_ROUTER" $default_router)
          let router_port = (env-or-default "INTERNET_ROUTER_PORT" $default_router_port)
          let lan_ok = (tcp-ok $router $router_port)
          let configured_servers = (dns-servers)
          let dns_results = (
            if (($configured_servers | length) == 0) {
              [ (dns-status) ]
            } else {
              $configured_servers | each {|server| dns-status $server }
            }
          )
          let dns_ok = ($dns_results | any {|row| $row.ok })
          let https_result = (https-status)
          let state = (
            if ($lan_ok == false) {
              "local-router-unreachable"
            } else if ($dns_ok == false) {
              "down"
            } else if ($https_result.ok == false) {
              "down"
            } else {
              "up"
            }
          )

          {
            state: $state,
            router: { address: $router, port: $router_port, ok: $lan_ok },
            dns: {
              domain: (probe-domain),
              results: $dns_results,
            },
            https: $https_result,
          }
        }

        def ok-label [ok: bool] {
          if $ok { "ok" } else { "fail" }
        }

        def exit-code [state: string] {
          match $state {
            "up" => 0,
            "down" => 1,
            "local-router-unreachable" => 2,
            _ => 64,
          }
        }

        def render-status [status: record] {
          print $"internet: ($status.state)"
          print $"router ($status.router.address):($status.router.port): (ok-label $status.router.ok)"
          print $"dns probe: ($status.dns.domain)"

          $status.dns.results | each {|row|
            let label = (ok-label $row.ok)
            let answers = if (($row.answers | length) > 0) {
              $row.answers | str join ", "
            } else {
              "no answer"
            }
            print $"dns ($row.server): ($label) (($answers))"
          }
          let https_label = (ok-label $status.https.ok)
          let https_detail = if $status.https.ok {
            $"HTTP ($status.https.status)"
          } else if $status.https.error != "" {
            $status.https.error
          } else {
            "no response"
          }
          print $"https ($status.https.url): ($https_label) (($https_detail))"

          match $status.state {
            "up" => { print "signal: router, DNS, and HTTPS probe succeeded" },
            "down" => {
              if ($status.dns.results | any {|row| $row.ok }) {
                print "signal: DNS works, but the HTTPS probe failed"
              } else {
                print "signal: local router is reachable, but upstream DNS resolution failed"
              }
            },
            "local-router-unreachable" => { print "signal: this machine cannot reach the MikroTik router" },
            _ => {},
          }
        }

        def usage [] {
          print "usage: internet status [--json]"
          print ""
          print "environment overrides:"
          print "  INTERNET_ROUTER=192.168.88.1"
          print "  INTERNET_ROUTER_PORT=22"
          print "  INTERNET_DNS_SERVERS=comma,separated,dns,servers"
          print "  INTERNET_DNS_DOMAIN=digikala.com"
          print "  INTERNET_PROBE_URL=https://digikala.com"
        }

        def main [
          command?: string = "status"
          --json
        ] {
          match $command {
            "status" => {
              let status = (status-record)

              if $json {
                print ($status | to json)
              } else {
                render-status $status
              }

              exit (exit-code $status.state)
            },
            "help" => {
              usage
            },
            _ => {
              usage
              exit 64
            },
          }
        }
      '';
  };
in
{
  home.packages = [ internet ];
}
