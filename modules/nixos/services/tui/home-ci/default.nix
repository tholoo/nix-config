{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.mine.home-ci;
  ubuntu = pkgs.fetchurl {
    url = "https://cloud-images.ubuntu.com/noble/20260826/noble-server-cloudimg-amd64.img";
    hash = "sha256-0P6Eu1+AhTQl+mvijiwQbzAQTDz+hhGTPy5lybY/DjA=";
  };
  settings = pkgs.writeText "home-ci-config.json" (
    builtins.toJSON {
      inherit (cfg)
        memoryMiB
        cpus
        diskGiB
        sshPort
        settingsFile
        ;
      stateDir = "/var/lib/home-ci";
      ssh = "${pkgs.openssh}/bin/ssh";
      image = ubuntu;
      guest = ./guest.py;
      bootstrap = ./bootstrap.sh;
      dockerWrapper = ./docker.py;
      jobHook = ./job-start.sh;
      runnerVersion = "2.337.0";
      runnerSha256 = "70920811a4f8ad4328818682bca5c6469c1c942fab52448868071d0063816613";
    }
  );
  command = pkgs.writeShellApplication {
    name = "home-ci";
    runtimeInputs = with pkgs; [
      python3
      openssh
      gh
      cdrkit
      qemu
      coreutils
    ];
    text = ''
      export HOME_CI_CONFIG=${settings}
      exec python3 ${./host.py} "$@"
    '';
  };
in
{
  options.mine.home-ci = lib.mine.mkEnable config { tags = [ ]; } // {
    cpus = lib.mkOption {
      type = lib.types.ints.positive;
      default = 4;
    };
    memoryMiB = lib.mkOption {
      type = lib.types.ints.positive;
      default = 4096;
    };
    diskGiB = lib.mkOption {
      type = lib.types.ints.positive;
      default = 80;
    };
    sshPort = lib.mkOption {
      type = lib.types.port;
      default = 22222;
    };
    settingsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional runtime JSON settings file, for example an agenix secret path. Never its contents.";
    };
    package = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      default = command;
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
        message = "home-ci currently provides an x86_64 Ubuntu guest.";
      }
    ];
    users.groups.home-ci = { };
    users.users.home-ci = {
      isSystemUser = true;
      group = "home-ci";
      extraGroups = [ "kvm" ];
      home = "/var/lib/home-ci";
    };
    environment.systemPackages = [ command ];
    systemd.services.home-ci = {
      description = "Private Ubuntu GitHub Actions VM";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      restartTriggers = [ settings ];
      serviceConfig = {
        User = "home-ci";
        Group = "home-ci";
        SupplementaryGroups = [ "kvm" ];
        StateDirectory = "home-ci";
        StateDirectoryMode = "0700";
        UMask = "0077";
        LoadCredential = lib.optional (cfg.settingsFile != null) "settings:${cfg.settingsFile}";
        WorkingDirectory = "/var/lib/home-ci";
        ExecStartPre = "${command}/bin/home-ci _prepare";
        ExecStart = "${command}/bin/home-ci _run";
        ExecStop = "${command}/bin/home-ci _poweroff";
        Restart = "on-failure";
        RestartSec = 10;
        TimeoutStartSec = 300;
        TimeoutStopSec = 180;
        ProtectHome = true;
        ProtectSystem = "strict";
        PrivateTmp = true;
        NoNewPrivileges = true;
      };
    };
  };
}
