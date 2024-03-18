# This is your system's configuration file.
# Use this to configure your system environment (it replaces /etc/nixos/configuration.nix)
{ inputs, outputs, lib, config, pkgs, ... }: {
  # You can import other NixOS modules here
  imports = [
    # If you want to use modules your own flake exports (from modules/nixos):
    # outputs.nixosModules.example

    # Or modules from other flakes (such as nixos-hardware):
    # inputs.hardware.nixosModules.common-cpu-amd
    # inputs.hardware.nixosModules.common-ssd

    # You can also split up your configuration and import pieces of it here:
    # ./users.nix

    # Import your generated (nixos-generate-config) hardware configuration
    ./hardware-configuration.nix
  ];

  nixpkgs = {
    # You can add overlays here
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.unstable-packages

      # You can also add overlays exported from other flakes:
      # neovim-nightly-overlay.overlays.default

      # Or define it inline, for example:
      # (final: prev: {
      #   hi = final.hello.overrideAttrs (oldAttrs: {
      #     patches = [ ./change-hello-to-hi.patch ];
      #   });
      # })
    ];
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;

      # pulseaudio = true;
      nvidia.acceptLicense = true;
    };
  };

  # This will add each flake input as a registry
  # To make nix3 commands consistent with your flake
  nix.registry = (lib.mapAttrs (_: flake: { inherit flake; }))
    ((lib.filterAttrs (_: lib.isType "flake")) inputs);

  # This will additionally add your inputs to the system's legacy channels
  # Making legacy nix commands consistent as well, awesome!
  nix.nixPath = [ "/etc/nix/path" ];
  environment.etc = (lib.mapAttrs' (name: value: {
    name = "nix/path/${name}";
    value.source = value.flake;
  }) config.nix.registry) // {
    "greetd/environments".text = ''
      sway
      Hyprland
    '';
  };

  nix.settings = {
    # Enable flakes and new 'nix' command
    experimental-features = "nix-command flakes";
    # Deduplicate and optimize nix store
    auto-optimise-store = true;
  };

  # FIXME: Add the rest of your current configuration
  security = {
    polkit.enable = true;
    rtkit.enable = true;
    pam.services.swaylock = { text = "auth include login"; };
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  systemd.services.vpn = {
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    description = "V2Ray Service";
    serviceConfig = {
      Type = "simple";
      User = "tholo";
      ExecStart =
        "${pkgs.v2ray}/bin/v2ray run --config=/home/tholo/v2ray/config.json";
      Restart = "on-failure";
    };
  };

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
  # Enable CUPS to print documents.
  services = {
    keyd = {
      enable = true;
      keyboards = {
        default = {
          settings = {
            main = {
              # https://github.com/rvaiya/keyd/blob/2338f11b1ddd81eaddd957de720a3b4279222da0/t/keys.py
              capslock = "esc";
              leftbrace = "overload(meta, leftbrace)";
              # meta = "oneshot(meta)";
              # rightalt = "overload(meta, rightalt)";
              rightalt = "layer(nav)";
              # backtick = "layer(layout_switch)";
            };
            # TODO: Make layout layers
            # layout_switch = {
            # "1" = "setlayout(qwerty)";
            # "2" = "setlayout(dvorak)";
            # };
            nav = {
              h = "left";
              j = "down";
              k = "up";
              l = "right";
            };
          };
        };
      };
    };
    v2raya.enable = true;
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
    pipewire = {
      enable = true;
      audio.enable = true;
      extraConfig.pipewire = {
        "99-silent-bell.conf" = {
          "context.properties" = { "module.x11.bell" = false; };
        };
      };
      wireplumber = {
        enable = true;
        # Higher quality for bluetooth
        configPackages = [
          (pkgs.writeTextDir
            "share/wireplumber/bluetooth.lua.d/51-bluez-config.lua" ''
              bluez_monitor.properties = {
                ["bluez5.enable-sbc-xq"] = true,
                ["bluez5.enable-msbc"] = true,
                ["bluez5.enable-hw-volume"] = true,
                ["bluez5.headset-roles"] = "[ hsp_hs hsp_ag hfp_hf hfp_ag ]"
              }
            '')
        ];
      };
      pulse.enable = true;
      # jack.enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
    };
  };

  services.greetd = {
    enable = true;
    settings = {
      default_session.command = ''
        ${pkgs.greetd.tuigreet}/bin/tuigreet \
          --time \
          --asterisks \
          --user-menu \
          --cmd sway
      '';
    };
  };

  # Enable the GNOME Desktop Environment.
  # programs.sway.enable = true;
  # services.xserver.displayManager.gdm.enable = true;
  # services.xserver.desktopManager.gnome.enable = true;
  # services.printing.enable = true;

  # Enable sound.
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

  # TODO: Set your hostname
  networking.hostName = "nixos";

  # Set your time zone.
  time.timeZone = "Asia/Tehran";

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable =
    true; # Easiest to use and most distros use this by default.

  # TODO: This is just an example, be sure to use whatever bootloader you prefer
  boot.loader.systemd-boot.enable = true;

  boot.loader.systemd-boot.configurationLimit = 30;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub.configurationLimit = 30;

  boot.binfmt.emulatedSystems = [ "x86_64-windows" ];

  virtualisation = {
    docker.enable = true;
    libvirtd.enable = true;
  };

  # TODO: Configure your system-wide user settings (groups, etc), add more users as needed.
  users.users = {
    # FIXME: Replace with your username
    tholo = {
      # TODO: You can set an initial password for your user.
      # If you do, you can skip setting a root password by passing '--no-root-passwd' to nixos-install.
      # Be sure to change it (using passwd) after rebooting!
      initialPassword = "1234";
      isNormalUser = true;
      openssh.authorizedKeys.keys = [
        # TODO: Add your SSH public key(s) here, if you plan on using SSH to connect
      ];
      # TODO: Be sure to add any other groups you need (such as networkmanager, audio, docker, etc)
      extraGroups = [ "wheel" "networkmanager" "audio" "docker" "video" ];
    };
  };
  programs = {
    light.enable = true;
    # hyprland.enable = true;
    virt-manager.enable = true;
  };
  # for sway
  systemd.user.services.kanshi = {
    description = "kanshi daemon";
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.kanshi}/bin/kanshi -c kanshi_config_file";
    };
  };
  # set fish as the default shell
  programs.fish.enable = true;
  users.users.tholo.shell = pkgs.fish;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    git
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    neovim
    wget
    curl
    qemu
  ];
  environment.variables.EDITOR = "nvim";

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # This setups a SSH server. Very important if you're setting up a headless system.
  # Feel free to remove if you don't need it.
  services.openssh = {
    enable = true;
    settings = {
      # Forbid root login through SSH.
      PermitRootLogin = "no";
      # Use keys only. Remove if you want to SSH using password (not recommended)
      PasswordAuthentication = false;
    };
  };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "23.05";
}
