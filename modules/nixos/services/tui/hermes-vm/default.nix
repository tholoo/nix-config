{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.mine.hermes-vm;
  hermes = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.hermes-agent;
  guest = import (inputs.nixpkgs + "/nixos/lib/eval-config.nix") {
    system = pkgs.stdenv.hostPlatform.system;
    specialArgs = {
      inherit hermes;
      hostCfg = cfg;
    };
    modules = [ ./guest.nix ];
  };
  closure = pkgs.closureInfo { rootPaths = [ guest.config.system.build.toplevel ]; };
  storeImage =
    pkgs.runCommand "hermes-guest-store.erofs"
      {
        nativeBuildInputs = [
          pkgs.gnutar
          pkgs.erofs-utils
        ];
      }
      ''
        tar --create --absolute-names --verbatim-files-from \
          --transform 'flags=rSh;s|/nix/store/||' --files-from ${closure}/store-paths \
          | mkfs.erofs --quiet --force-uid=0 --force-gid=0 -T 0 \
            -L hermes-store --tar=f "$out"
      '';
  settings = pkgs.writeText "hermes-vm.json" (
    builtins.toJSON {
      inherit (cfg) cpus memoryMiB diskGiB;
      stateDir = "/var/lib/hermes-vm";
      qemu = lib.getExe' pkgs.qemu_kvm "qemu-system-x86_64";
      qemuImg = lib.getExe' pkgs.qemu_kvm "qemu-img";
      mkfs = lib.getExe' pkgs.e2fsprogs "mkfs.ext4";
      socat = lib.getExe pkgs.socat;
      inherit storeImage;
      kernel = "${guest.config.system.build.toplevel}/kernel";
      initrd = "${guest.config.system.build.toplevel}/initrd";
      init = "${guest.config.system.build.toplevel}/init";
      hasCredential = cfg.environmentFile != null;
      proxySocket = "/run/hermes-egress/proxy.sock";
    }
  );
  command = pkgs.writeShellApplication {
    name = "hermes-vm";
    runtimeInputs = [ pkgs.python3 ];
    text = ''exec python3 ${./host.py} --config ${settings} "$@"'';
  };
  firewall = pkgs.writeText "hermes-vm-egress.nft" ''
    table inet hermes_vm {
      chain output {
        type filter hook output priority -10; policy accept;
        meta skuid "hermes-vm" jump guest_egress
      }
      chain guest_egress {
        # All traffic must use the Unix-socket HTTPS relay, never raw sockets.
        counter reject
      }
    }
  '';
in
{
  options.mine.hermes-vm = lib.mine.mkEnable config { tags = [ ]; } // {
    cpus = lib.mkOption {
      type = lib.types.ints.between 1 4;
      default = 2;
    };
    memoryMiB = lib.mkOption {
      type = lib.types.ints.between 1024 8192;
      default = 3072;
    };
    diskGiB = lib.mkOption {
      type = lib.types.ints.between 8 128;
      default = 24;
    };
    model = lib.mkOption {
      type = lib.types.str;
      default = "gpt-5.6-sol";
    };
    proxyPort = lib.mkOption {
      type = lib.types.port;
      default = 7890;
      description = "Existing host Mihomo HTTP proxy port; used only by the trusted egress relay.";
    };
    proxyUrlFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional runtime upstream HTTP proxy URL, e.g. an agenix secret containing credentials.";
    };
    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Runtime Telegram environment file, normally an agenix secret path.
        Contents never enter the store. With null, use hermes-admin telegram in the guest.
      '';
    };
    package = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      default = command;
    };
    guestSystem = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      default = guest.config.system.build.toplevel;
    };
    image = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      default = storeImage;
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
        message = "hermes-vm currently supports x86_64-linux with KVM.";
      }
      {
        assertion =
          cfg.environmentFile == null
          || (lib.hasPrefix "/" cfg.environmentFile && !(lib.hasPrefix "/nix/store/" cfg.environmentFile));
        message = "hermes-vm.environmentFile must be a runtime path outside the Nix store.";
      }
      {
        assertion = !config.networking.nftables.flushRuleset;
        message = "hermes-vm needs networking.nftables.flushRuleset = false to preserve its independent egress table.";
      }
      {
        assertion =
          cfg.proxyUrlFile == null
          || (lib.hasPrefix "/" cfg.proxyUrlFile && !(lib.hasPrefix "/nix/store/" cfg.proxyUrlFile));
        message = "hermes-vm.proxyUrlFile must be a runtime path outside the Nix store.";
      }
    ];
    users.groups.hermes-vm = { };
    users.users.hermes-vm = {
      isSystemUser = true;
      group = "hermes-vm";
      extraGroups = [
        "kvm"
        "hermes-egress"
      ];
      home = "/var/lib/hermes-vm";
    };
    environment.systemPackages = [ command ];

    users.groups.hermes-egress = { };
    users.users.hermes-egress = {
      isSystemUser = true;
      group = "hermes-egress";
    };
    systemd.services.hermes-egress = {
      description = "Public HTTPS egress for Hermes through Mihomo";
      after = [
        "network-online.target"
        "mihomo.service"
      ];
      wants = [ "network-online.target" ];
      path = [ pkgs.iproute2 ];
      serviceConfig = {
        User = "hermes-egress";
        Group = "hermes-egress";
        RuntimeDirectory = "hermes-egress";
        RuntimeDirectoryMode = "0750";
        LoadCredential = lib.optional (cfg.proxyUrlFile != null) "upstream:${cfg.proxyUrlFile}";
        ExecStart = "${pkgs.python3}/bin/python3 ${./egress.py} --socket /run/hermes-egress/proxy.sock --port ${toString cfg.proxyPort}";
        Restart = "on-failure";
        RestartSec = 5;
        MemoryMax = "192M";
        TasksMax = 32;
        CPUQuota = "25%";
        LimitCORE = 0;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        NoNewPrivileges = true;
        CapabilityBoundingSet = "";
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_NETLINK"
        ];
      };
    };

    # A separate table coexists with the host's existing firewall/Docker rules.
    # It stays installed on stop; the VM must never outlive its egress filter.
    systemd.services.hermes-vm-firewall = {
      description = "Block direct IP networking from the Hermes VM";
      before = [ "hermes-vm.service" ];
      after = [
        "nftables.service"
        "firewall.service"
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      path = [ pkgs.nftables ];
      script = ''
        # Replace this table in a single transaction; never flush other rules.
        if nft list table inet hermes_vm >/dev/null 2>&1; then
          { echo 'delete table inet hermes_vm'; cat ${firewall}; } | nft -f -
        else
          nft -f ${firewall}
        fi
      '';
    };
    systemd.services.hermes-vm = {
      description = "Isolated personal Hermes assistant VM";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      requires = [
        "hermes-vm-firewall.service"
        "hermes-egress.service"
      ];
      after = [
        "network-online.target"
        "hermes-vm-firewall.service"
        "hermes-egress.service"
      ];
      restartTriggers = [
        settings
        firewall
      ];
      unitConfig.ConditionPathExists = "/dev/kvm";
      serviceConfig = {
        User = "hermes-vm";
        Group = "hermes-vm";
        SupplementaryGroups = [
          "kvm"
          "hermes-egress"
        ];
        StateDirectory = "hermes-vm";
        StateDirectoryMode = "0700";
        WorkingDirectory = "/var/lib/hermes-vm";
        UMask = "0077";
        LoadCredential = lib.optional (cfg.environmentFile != null) "telegram:${cfg.environmentFile}";
        ExecStartPre = "${command}/bin/hermes-vm prepare";
        ExecStart = "${command}/bin/hermes-vm run";
        ExecStop = "${command}/bin/hermes-vm poweroff";
        TimeoutStopSec = 120;
        Restart = "on-failure";
        RestartSec = 15;
        CPUQuota = "150%";
        CPUWeight = 20;
        MemoryHigh = "${toString (cfg.memoryMiB + 256)}M";
        MemoryMax = "${toString (cfg.memoryMiB + 768)}M";
        MemorySwapMax = 0;
        IOWeight = 20;
        TasksMax = 128;
        LimitCORE = 0;
        OOMPolicy = "stop";
        OOMScoreAdjust = 500;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        NoNewPrivileges = true;
        # libslirp's command forwarding uses a loopback TCP socket pair.
        # Give it an isolated loopback, with no host interfaces or routes.
        # Filesystem Unix sockets still reach the HTTPS relay and consoles.
        PrivateNetwork = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
        ];
        # Independent cgroup enforcement also survives firewall reloads.
        IPAddressDeny = [ "any" ];
        IPAddressAllow = [ "localhost" ];
        DevicePolicy = "closed";
        DeviceAllow = [ "/dev/kvm rw" ];
        CapabilityBoundingSet = "";
      };
    };
  };
}
