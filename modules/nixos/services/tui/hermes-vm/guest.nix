{
  config,
  lib,
  pkgs,
  modulesPath,
  hermes,
  hostCfg,
  ...
}:
let
  # The pinned binary package omits the upstream locale catalogs. Keep their
  # revision matched to Hermes without rebuilding the Python application.
  locales = pkgs.runCommand "hermes-locales-${hermes.version}" { } ''
    mkdir -p "$out"
    cp -R ${hermes.src}/locales/. "$out/"
  '';
  python = pkgs.python3.withPackages (
    p: with p; [
      pandas
      openpyxl
      pypdf
      pillow
      pyyaml
    ]
  );
  tools = [
    "web"
    "terminal"
    "file"
    "memory"
    "session_search"
    "todo"
    "cronjob"
    "clarify"
  ];
  baseConfig = pkgs.writeText "hermes-config.json" (
    builtins.toJSON {
      model = {
        provider = "openai-codex";
        default = hostCfg.model;
      };
      fallback_providers = [ ];
      toolsets = tools;
      platform_toolsets = {
        cli = tools;
        telegram = tools;
        cron = lib.subtractLists [ "cronjob" "clarify" ] tools;
      };
      max_concurrent_sessions = 2;
      max_live_sessions = 2;
      agent = {
        max_turns = 30;
        run_budget_seconds = 600;
        gateway_timeout = 600;
        reasoning_effort = "medium";
        environment_hint = "Work inside this isolated guest. The persistent workspace is /var/lib/hermes/workspace. Software and gateway settings are managed by NixOS.";
      };
      terminal = {
        backend = "local";
        cwd = "/var/lib/hermes/workspace";
        timeout = 120;
      };
      web = {
        search_backend = "ddgs";
        extract_backend = "firecrawl";
        keyless_fallback = false;
        keyless_rescue = false;
      };
      approvals = {
        mode = "smart";
        cron_mode = "deny";
        unattended_mode = "deny";
      };
      auxiliary.approval = {
        provider = "openai-codex";
        model = hostCfg.model;
      };
      security = {
        allow_private_urls = false;
        redact_secrets = true;
        allow_lazy_installs = false;
      };
      privacy.redact_pii = true;
      cron = {
        allow_agent_scheduling = false;
        model_drift_guard = true;
        preflight = true;
        max_parallel_jobs = 1;
      };
      stt.enabled = false;
      voice.auto_tts = false;
      telegram = {
        guest_mode = false;
        require_mention = true;
        observe_unmentioned_group_messages = false;
      };
      platforms.telegram.enabled = true;
      display.tool_progress = "new";
      mcp_servers = { };
    }
  );
  admin = pkgs.writeShellApplication {
    name = "hermes-admin";
    runtimeInputs = [
      python
      pkgs.util-linux
      pkgs.systemd
      hermes
    ];
    text = ''
      if [[ "$EUID" != 0 ]]; then
        echo 'Use the guest root console for administration.' >&2
        exit 1
      fi
      export HERMES_BASE_CONFIG=${baseConfig}
      export HERMES_EXECUTABLE=${lib.getExe hermes}
      exec python3 ${./guest-admin.py} "$@"
    '';
  };
in
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];
  nixpkgs.config.allowUnfree = false;
  system.stateVersion = "26.05";
  networking.hostName = "hermes";
  time.timeZone = "UTC";
  boot.loader.grub.enable = false;
  boot.initrd.availableKernelModules = [
    "virtio_pci"
    "virtio_blk"
    "virtio_net"
  ];
  boot.kernelModules = [
    "qemu_fw_cfg"
    # Let logind receive QEMU's ACPI power button for clean host-side stops.
    "button"
    "evdev"
  ];
  boot.supportedFilesystems = [ "erofs" ];
  boot.kernelParams = [ "console=ttyS0" ];
  fileSystems."/" = {
    device = "/dev/disk/by-label/hermes-state";
    fsType = "ext4";
  };
  fileSystems."/nix/store" = {
    device = "/dev/disk/by-label/hermes-store";
    fsType = "erofs";
    neededForBoot = true;
  };
  boot.tmp.useTmpfs = true;
  boot.tmp.tmpfsSize = "256M";
  swapDevices = [ ];
  nix.enable = false;
  documentation.enable = false;
  services.openssh.enable = false;
  services.getty.autologinUser = "root";
  users.mutableUsers = false;
  # There are no network logins; administration is exclusively through the
  # host-owned Unix console socket and its root autologin getty.
  users.allowNoPasswordLogin = true;
  users.users.root.hashedPassword = "!";
  users.groups.hermes = { };
  users.users.hermes = {
    isSystemUser = true;
    group = "hermes";
    home = "/var/lib/hermes";
  };

  networking.useDHCP = false;
  networking.useNetworkd = true;
  networking.enableIPv6 = false;
  # Applications resolve destinations through the proxy; raw DNS has no egress.
  networking.nameservers = [ ];
  services.resolved.enable = false;
  systemd.network.networks."10-uplink" = {
    matchConfig.Type = "ether";
    networkConfig = {
      DHCP = "ipv4";
      IPv6AcceptRA = false;
      LinkLocalAddressing = "no";
    };
    dhcpV4Config = {
      UseDNS = false;
      UseNTP = false;
      UseHostname = false;
    };
  };
  networking.firewall.enable = true;
  # The host provides the clock at each boot; no guest NTP exception is needed.
  services.timesyncd.enable = false;

  environment.systemPackages = with pkgs; [
    admin
    hermes
    python
    curl
    jq
    gitMinimal
    ripgrep
    file
    unzip
    unrar-free
    poppler-utils
    qpdf
    tesseract
    ffmpeg-headless
  ];
  environment.etc."hermes/SOUL.md".source = ./SOUL.md;
  # This is a synthetic QEMU guest-forward address, not a host/LAN endpoint.
  environment.variables = {
    HERMES_BUNDLED_LOCALES = "${locales}";
    HTTP_PROXY = "http://10.0.2.100:3128";
    HTTPS_PROXY = "http://10.0.2.100:3128";
    http_proxy = "http://10.0.2.100:3128";
    https_proxy = "http://10.0.2.100:3128";
    TELEGRAM_PROXY = "http://10.0.2.100:3128";
    DDGS_PROXY = "http://10.0.2.100:3128";
    NO_PROXY = "localhost,127.0.0.1";
    no_proxy = "localhost,127.0.0.1";
  };
  systemd.tmpfiles.rules = [
    "d /var/lib/hermes 0700 hermes hermes -"
    "d /var/lib/hermes/workspace 0700 hermes hermes -"
    "d /var/lib/hermes-private 0700 root root -"
    "d /run/hermes 0700 root root -"
  ];
  systemd.services.hermes-prepare = {
    description = "Prepare private Hermes configuration";
    wantedBy = [ "multi-user.target" ];
    before = [ "hermes-gateway.service" ];
    after = [
      "systemd-tmpfiles-setup.service"
      "systemd-modules-load.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${admin}/bin/hermes-admin prepare";
    };
  };
  systemd.services.hermes-gateway = {
    description = "Private Telegram Hermes gateway";
    wantedBy = [ "multi-user.target" ];
    requires = [ "hermes-prepare.service" ];
    wants = [ "network-online.target" ];
    after = [
      "hermes-prepare.service"
      "network-online.target"
    ];
    unitConfig.ConditionPathExists = "/run/hermes/telegram.env";
    path = config.environment.systemPackages;
    environment = config.environment.variables // {
      HOME = "/var/lib/hermes";
      HERMES_HOME = "/var/lib/hermes";
      HERMES_YOLO_MODE = "false";
      HERMES_DISABLE_LAZY_INSTALLS = "1";
      PYTHONUNBUFFERED = "1";
      TZ = "UTC";
    };
    serviceConfig = {
      User = "hermes";
      Group = "hermes";
      WorkingDirectory = "/var/lib/hermes/workspace";
      EnvironmentFile = "/run/hermes/telegram.env";
      ExecStart = "${lib.getExe hermes} gateway run";
      Restart = "on-failure";
      RestartSec = 30;
      TimeoutStopSec = 60;
      UMask = "0077";
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictSUIDSGID = true;
      CapabilityBoundingSet = "";
      RestrictAddressFamilies = [
        "AF_UNIX"
        "AF_INET"
      ];
      ReadWritePaths = [ "/var/lib/hermes" ];
      BindReadOnlyPaths = [
        "/var/lib/hermes/config.yaml"
        "/var/lib/hermes/.env"
        "/var/lib/hermes/SOUL.md"
      ];
      LimitCORE = 0;
      TasksMax = 256;
    };
  };
  services.journald.extraConfig = ''
    SystemMaxUse=100M
    RuntimeMaxUse=32M
    MaxRetentionSec=7day
  '';
  services.logrotate = {
    enable = true;
    settings.hermes = {
      files = [ "/var/lib/hermes/logs/*.log" ];
      frequency = "daily";
      rotate = 7;
      size = "10M";
      missingok = true;
      notifempty = true;
      copytruncate = true;
      compress = true;
      su = "hermes hermes";
    };
  };
}
