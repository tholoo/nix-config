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
  name = "tailscale";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "service"
      "tui"
    ];
  };

  config = mkIf cfg.enable {
    services.tailscale = {
      enable = true;
      extraDaemonFlags = [ "--no-logs-no-support" ];
    };

    environment.systemPackages = with pkgs; [
      tailscale
    ];

    networking.firewall = {
      # enable the firewall
      enable = true;

      # always allow traffic from your Tailscale network
      trustedInterfaces = [ "tailscale0" ];

      # allow the Tailscale UDP port through the firewall
      allowedUDPPorts = [
        config.services.tailscale.port
        25565
      ];

      # let you SSH in over the public internet
      # allowedTCPPorts = [ 22 ];
    };
  };
}
