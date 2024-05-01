{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  username,
  hostname,
  ...
}:
{
  imports = [
    ../../nixos/common.nix
    ../../nixos/docker.nix
    ../../nixos/services
    # If you want to use modules your own flake exports (from modules/nixos):
    # outputs.nixosModules.example

    # Or modules from other flakes (such as nixos-hardware):
    # inputs.hardware.nixosModules.common-cpu-amd
    # inputs.hardware.nixosModules.common-ssd

    # Import your generated (nixos-generate-config) hardware configuration
    ./hardware-configuration.nix
  ];

  # stylix = {
  #   image = ../resources/wallpapers/wallhaven-fields-858z32.png;
  #   polarity = "dark";
  # };

  # nixpkgs.config.nvidia.acceptLicense = true;
  environment.etc."greetd/environments".text = ''
    sway
    Hyprland
  '';

  security = {
    polkit.enable = true;
    rtkit.enable = true;
    pam.services.swaylock = {
      text = "auth include login";
    };
  };

  # systemd.services.vpn = {
  # wantedBy = [ "multi-user.target" ];
  # after = [ "network.target" ];
  # description = "V2Ray Service";
  # serviceConfig = {
  # Type = "simple";
  # User = "${username}";
  # ExecStart = "${pkgs.v2ray}/bin/v2ray run --config=/home/${username}/v2ray/config.json";
  # Restart = "on-failure";
  # };
  # };

  # systemd.user.services.polkit-gnome-authentication-agent-1 = {
  #   description = "polkit-gnome-authentication-agent-1";
  #   wantedBy = [ "graphical-session.target" ];
  #   wants = [ "graphical-session.target" ];
  #   after = [ "graphical-session.target" ];
  #   serviceConfig = {
  #     Type = "simple";
  #     ExecStart =
  #       "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
  #     Restart = "on-failure";
  #     RestartSec = 1;
  #     TimeoutStopSec = 10;
  #   };
  # };
  services = {
    # minecraft-server = {
    # enable = true;
    # openFirewall = true;
    # declarative = true;
    # eula = true;
    # serverProperties = {
    # server-port = 43000;
    # difficulty = 3;
    # gamemode = 1;
    # max-players = 5;
    # motd = "Thoohohohohoohlo";
    # };
    # };
    # xserver = {
    # Load nvidia driver for Xorg and Wayland
    #   videoDrivers = [ "nvidiaLegacy470" ];
    # };
    #     enable = true;
    #     xkb = {
    #       variant = "";
    #       options = "caps:escape";
    #       layout = "us";
    #     };
    # videoDrivers = ["nvidia" "amdgpu" "modesetting" "radeon"];
    # displayManager = {
    # defaultSession = "none+i3";
    # lightdm.enable = true;
    # };
    #   windowManager.i3.enable = true;
    # };
    # enable = true;
    # xkb = {
    # variant = "";
    # options = "caps:escape";
    # layout = "us";
    # };
    # # videoDrivers = ["nvidia" "amdgpu" "modesetting" "radeon"];
    # # displayManager = {
    # # defaultSession = "none+i3";
    # # lightdm.enable = true;
    # # };
    # windowManager.i3.enable = true;
    # };
    gvfs.enable = true;
    gnome.gnome-keyring.enable = true;
    blueman.enable = true;
    # xserver.displayManager.gdm.enable = true;
    # xserver.desktopManager.gnome.enable = true;
    # printing.enable = true;
  };

  sound.enable = true;
  hardware = {
    logitech = {
      wireless = {
        enable = true;
        enableGraphical = true;
      };
    };
    # gt 710
    # nvidia = {
    #   package = config.boot.kernelPackages.nvidiaPackages.legacy_470;
    #   # Modesetting is required.
    #   modesetting.enable = true;
    #   # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
    #   # Enable this if you have graphical corruption issues or application crashes after waking
    #   # up from sleep. This fixes it by saving the entire VRAM memory to /tmp/ instead
    #   # of just the bare essentials.
    #   powerManagement.enable = false;
    #
    #   # Fine-grained power management. Turns off GPU when not in use.
    #   # Experimental and only works on modern Nvidia GPUs (Turing or newer).
    #   powerManagement.finegrained = false;
    #
    #   # Use the NVidia open source kernel module (not to be confused with the
    #   # independent third-party "nouveau" open source driver).
    #   # Support is limited to the Turing and later architectures. Full list of
    #   # supported GPUs is at:
    #   # https://github.com/NVIDIA/open-gpu-kernel-modules#compatible-gpus
    #   # Only available from driver 515.43.04+
    #   # Currently alpha-quality/buggy, so false is currently the recommended setting.
    #   open = false;
    #
    #   # Enable the Nvidia settings menu,
    #   # accessible via `nvidia-settings`.
    #   nvidiaSettings = true;
    # };
    opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
    };
    # pulseaudio = {
    #   enable = true;
    #   # extra codecs
    #   package = pkgs.pulseaudioFull;
    #   # automatically switch sound to bluetooth device
    #   extraConfig = "load-module module-switch-on-connect";
    # };
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
  };

  networking.hostName = "nixos";

  time.timeZone = "Asia/Tehran";

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  i18n.defaultLocale = "en_US.UTF-8";

  boot.binfmt.emulatedSystems = [ "x86_64-windows" ];

  programs.fish.enable = true;
  users.users = {
    "${username}" = {
      # You can set an initial password for your user.
      # If you do, you can skip setting a root password by passing '--no-root-passwd' to nixos-install.
      # Be sure to change it (using passwd) after rebooting!
      initialPassword = "1234";
      isNormalUser = true;
      shell = pkgs.fish;
      openssh.authorizedKeys.keys = [
        # TODO: Add your SSH public key(s) here, if you plan on using SSH to connect
      ];
      extraGroups = [
        "wheel"
        "networkmanager"
        "audio"
        "docker"
        "video"
        "input"
      ];
    };
  };
  programs = {
    light.enable = true;
    virt-manager.enable = true;
    kdeconnect.enable = true;
  };
  # for sway
  systemd.user.services.kanshi = {
    description = "kanshi daemon";
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.kanshi}/bin/kanshi -c kanshi_config_file";
    };
  };

  environment.systemPackages = with pkgs; [
    git
    vim
    neovim
    wget
    curl

    qemu
  ];
  environment.variables = {
    EDITOR = "nvim";
    # Native wayland support
    NIXOS_OZONE_WL = "1";
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  services.openssh = {
    enable = true;
    settings = {
      # Forbid root login through SSH.
      PermitRootLogin = "no";
      # Use keys only. Remove if you want to SSH using password (not recommended)
      PasswordAuthentication = false;
    };
  };

  # Open ports in the firewall.
  # networking.firewall = {
  #   allowedTCPPorts = [ ... ];
  #   allowedUDPPorts = [ ... ];
  # }
}
