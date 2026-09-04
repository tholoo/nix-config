{
  pkgs,
  lib,
  modulesPath,
  ...
}:
let
  graniteLoginShell = (
    pkgs.writeShellScriptBin "granite-login-shell" ''
      if [[ "''${1-}" == "-c" ]]; then
        exec ${lib.getExe pkgs.bash} "$@"
      fi

      exec ${lib.getExe pkgs.nushell} "$@"
    ''
  ).overrideAttrs (oldAttrs: {
    passthru = (oldAttrs.passthru or { }) // {
      shellPath = "/bin/granite-login-shell";
    };
  });
in
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disk-config.nix
  ];
  mine = {
    host = {
      name = "granite";
      location = "Asia/Tehran";
    };

    tui.enable = true;
    tags.exclude = [
      "game"
      "gui"
      "develop"
      "ai"
      "mount"
      "proxy"
      "vpn"
      "personal"
      "emulation"
    ];

    tui-misc.enable = false;
    theme.enable = false;
    codex.enable = false;

    systemd-boot.enable = false;
    syncthing.enable = false;

    k8s.enable = false;
    n8n.enable = false;
    llama-cpp.enable = false;
    homepage-dashboard.enable = false;
    uptime-kuma.enable = false;
  };

  security.sudo.wheelNeedsPassword = false;

  # OpenSSH invokes the login shell with `-c` for remote commands, but without
  # it for an interactive login. Use Bash for the former and Nushell for the
  # latter so command-oriented SSH clients get conventional shell semantics.
  users.users.tholo.shell = lib.mkForce graniteLoginShell;

  # Let a local outer Zellij session identify itself to the remote client so
  # Zellij 0.45's nested-session protocol is enabled across SSH.
  services.openssh.settings.AcceptEnv = [ "ZELLIJ" ];

  # The qemu-guest profile cannot grow an LVM mapper device directly. Disko
  # already allocates the root partition and logical volume to all free space.
  boot.growPartition = lib.mkForce false;

  # Hetzner cloud VM has no /dev/kvm; libvirtd from the docker module can't start here.
  virtualisation.libvirtd.enable = lib.mkForce false;
  # services.minecraft-server.serverProperties.jvmOpts = "-Xmx512M -Xms512M";
  virtualisation.docker.daemon.settings = {
    registry-mirrors = [ ]; # disable ir mirror
    dns = [
      "185.12.64.1"
      "185.12.64.2"
    ];
  };

  systemd.services.docker-retention = {
    description = "Prune stale Docker images and build cache";
    after = [ "docker.service" ];
    requires = [ "docker.service" ];
    serviceConfig = {
      Type = "oneshot";
      Nice = 19;
      IOSchedulingClass = "idle";
      IOSchedulingPriority = 7;
    };
    script = ''
      set -euo pipefail
      ${pkgs.docker}/bin/docker image prune --all --force --filter until=168h
      ${pkgs.docker}/bin/docker builder prune --all --force --filter until=168h --keep-storage 2GB
    '';
  };

  systemd.timers.docker-retention = {
    description = "Run Docker retention daily";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "2h";
    };
  };

  networking.firewall.allowedTCPPorts = [
    80
    443
    3000
  ];
}
