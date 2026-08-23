{
  lib,
  pkgs,
  inputs,

  system, # The system architecture for this host (eg. `x86_64-linux`).
  target, # The Snowfall Lib target for this system (eg. `x86_64-iso`).
  format, # A normalized name for the system target (eg. `iso`).
  virtual, # A boolean to determine whether this system is a virtual target using nixos-generators.
  systems, # An attribute map of your defined hosts.

  config,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
    ./network-monitor.nix
    ./adguardhome.nix
  ];
  mine = {
    host = {
      name = "elderwood";
      location = "Asia/Tehran";
    };

    tags.exclude = [
      "gui"
      "game"
      "develop"
    ];

    gui.enable = false;
    tui.enable = true;

    grub.enable = true;
    systemd-boot.enable = false;

    mihomo = {
      enable = true;
      webui = pkgs.metacubexd;
      apiSecretFile = config.age.secrets.mihomo-api-secret.path;
      subscriptions = [
        {
          name = "main";
          urlFile = config.age.secrets.mihomo-sub-url-main.path;
        }
      ];
      directDomains = [
        "cafebazaar.ir"
        "digikala.com"
        "runflare.com"
      ];
      directNameservers = [
        "192.168.88.1"
        "78.157.42.100"
      ];
    };

    network-monitor.enable = true;

    dokploy.enable = false;

    # TODO: re-enable for CPU-only inference once the rest of the host is settled.
    llama-cpp.enable = false;

    # k3s/flux2 bootstrap reaches GitHub release artifacts; re-enable once mihomo proxy is up.
    k8s.enable = false;
  };

  age.secrets.tholo-authorized-key = {
    file = inputs.self + /secrets/ssh/windows-authorized-key.age;
    path = "/run/agenix/authorized-keys/tholo";
    mode = "0444";
  };

  age.secrets.mihomo-api-secret.file = inputs.self + /secrets/mihomo/mihomo-api-secret.age;
  age.secrets.mihomo-sub-url-main.file = inputs.self + /secrets/mihomo/mihomo-sub-url-main.age;

  # Caddy is the LAN frontend for elderwood. Keep Nixflix services running, but
  # stop its generated nginx vhosts from binding port 80.
  nixflix.nginx.enable = lib.mkForce false;

  # Firefly still uses nginx internally on 8080; move nginx's generated default
  # listeners away from the HTTP/HTTPS frontend ports reserved for Caddy.
  services.nginx.defaultHTTPListenPort = lib.mkForce 8088;
  services.nginx.defaultSSLListenPort = lib.mkForce 8443;

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD";
  }; # Force intel-media-driver

  # Haswell + 6.x kernel false-positive: deep idle (C6/C7) causes "MCE broadcast timeout" panics
  # because hyperthread siblings don't wake fast enough to ACK broadcast IPIs.
  # Cap at C2 — keeps the broadcast issue away while still allowing meaningful power saving.
  # Try raising to 3 if stable; lower again if panics return.
  boot.kernelParams = [
    "processor.max_cstate=2"
    "intel_idle.max_cstate=2"
  ];
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv4.conf.all.rp_filter" = 2; # loose
    "net.ipv4.conf.default.rp_filter" = 2;
  };
  networking.interfaces.enp6s0.ipv4.routes = [
    {
      address = "192.168.89.0";
      prefixLength = 24;
      via = "192.168.88.1";
    }
  ];

  # NVIDIA GM107 (GTX 750 Ti) hits PRIVRING faults under nouveau.
  # Disabled until proprietary driver is wired up (see GPU TODO).
  boot.blacklistedKernelModules = [ "nouveau" ];
}
