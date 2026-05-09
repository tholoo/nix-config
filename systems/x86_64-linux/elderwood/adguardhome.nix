{ ... }:
{
  mine.mihomo = {
    dnsListen = "127.0.0.1:1053";
    dnsHijack = [ "127.0.0.1:1053" ];
  };

  services = {
    adguardhome = {
      enable = true;
      host = "0.0.0.0";
      port = 3002;
      openFirewall = true;
      mutableSettings = true;

      settings = {
        auth_attempts = 5;
        block_auth_min = 15;
        users = [
          {
            name = "admin";
            password = "$2b$12$P2XvbCoh/yHu88TCBIS.A.WOUesqh7Pp55xjHSATYeIV2TeRgFinG";
          }
        ];

        filtering.rewrites = [
          {
            domain = "elderwood";
            answer = "192.168.88.31";
            enabled = true;
          }
          {
            domain = "*.elderwood";
            answer = "192.168.88.31";
            enabled = true;
          }
        ];

        dns = {
          bind_hosts = [ "0.0.0.0" ];
          port = 53;
          upstream_dns = [ "127.0.0.1:1053" ];
          bootstrap_dns = [
            "1.1.1.1"
            "8.8.8.8"
          ];
        };
      };
    };

    resolved.settings.Resolve.DNSStubListener = "no";
  };

  networking.firewall = {
    allowedTCPPorts = [ 53 ];
    allowedUDPPorts = [ 53 ];
  };

  networking.networkmanager.insertNameservers = [ "127.0.0.1" ];
}
