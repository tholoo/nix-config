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
      subscriptions = [
        {
          name = "main";
          urlFile = config.age.secrets.mihomo-sub-url-main.path;
        }
      ];
      directDomains = [
        "runflare.com"
      ];
    };

    dokploy.enable = false;

    # TODO: re-enable for CPU-only inference once the rest of the host is settled.
    llama-cpp.enable = false;

    # k3s/flux2 bootstrap reaches GitHub release artifacts; re-enable once mihomo proxy is up.
    k8s.enable = false;
  };

  age.secrets.mihomo-sub-url-main.file = inputs.self + /secrets/mihomo/mihomo-sub-url-main.age;

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD";
  }; # Force intel-media-driver

  # Haswell + 6.x kernel false-positive: deep C-states cause "MCE broadcast timeout" panics.
  # Pinning C-state ceilings keeps cores responsive to broadcast IPIs.
  boot.kernelParams = [
    "processor.max_cstate=1"
    "intel_idle.max_cstate=0"
  ];

  # NVIDIA GM107 (GTX 750 Ti) hits PRIVRING faults under nouveau.
  # Disabled until proprietary driver is wired up (see GPU TODO).
  boot.blacklistedKernelModules = [ "nouveau" ];
}
