{
  inputs,
  outputs,
  pkgs,
  lib,
  username,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disk-config.nix
    ../../nixos/common.nix
    ../../nixos/docker.nix
  ];

  # security = {
  #   polkit.enable = true;
  #   rtkit.enable = true;
  # };

  networking = {
    hostName = "nixos";
    firewall.enable = true;
  };

  boot.loader.grub = {
    # no need to set devices, disko will add all devices that have a EF02 partition to the list already
    # devices = [ ];
    efiSupport = true;
    efiInstallAsRemovable = true;
    configurationLimit = 30;
  };

  time.timeZone = "Asia/Tehran";

  security.sudo.wheelNeedsPassword = false;

  programs.fish.enable = true;
  users.users = {
    root = {
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDP5NAC+t7dRdeCUVaMPRUvfu4hrFLqEqpmh8NlXORwF tholo@nixos"
      ];
    };
    "${username}" = {
      initialPassword = "1234";
      isNormalUser = true;
      shell = pkgs.fish;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDP5NAC+t7dRdeCUVaMPRUvfu4hrFLqEqpmh8NlXORwF tholo@nixos"
      ];
      extraGroups = [
        "wheel"
        "networkmanager"
        "audio"
        "docker"
        "video"
        "input"
        "libvirtd"
      ];
    };
  };

  environment.systemPackages = with pkgs; [
    git
    vim
    neovim
    wget
    curl
  ];

  environment.variables = {
    EDITOR = "nvim";
  };

  services.openssh = {
    enable = true;
    hostKeys = [
      {
        path = "/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
    settings = {
      # Forbid root login through SSH.
      # PermitRootLogin = "no";
      # Use keys only. Remove if you want to SSH using password (not recommended)
      PasswordAuthentication = false;
    };
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    sharedModules = [
      inputs.nixvim.homeManagerModules.nixvim
      inputs.agenix.homeManagerModules.default
    ];
    extraSpecialArgs = {
      inherit username;
    };
    users.${username} = import ./home.nix;
  };
  # Open ports in the firewall.
  # networking.firewall = {
  #   allowedTCPPorts = [ ... ];
  #   allowedUDPPorts = [ ... ];
  # }
}
