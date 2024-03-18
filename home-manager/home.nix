# This is your home-manager configuration file
# Use this to configure your home environment (it replaces ~/.config/nixpkgs/home.nix)
{ inputs, outputs, getNixFiles, lib, pkgs, ... }: {
  # You can import other home-manager modules here

  imports = getNixFiles ./programs ++ getNixFiles ./window_manager
    ++ [ inputs.nix-colors.homeManagerModules.default ];
  # imports = [
  # If you want to use modules your own flake exports (from modules/home-manager):
  # outputs.homeManagerModules.example

  # Or modules exported from other flakes (such as nix-colors):
  # inputs.nix-colors.homeManagerModules.default

  # You can also split up your configuration and import pieces of it here:
  # ./nvim.nix
  # ];

  colorScheme = inputs.nix-colors.colorSchemes.onedark;

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
      # Workaround for https://github.com/nix-community/home-manager/issues/2942
      allowUnfreePredicate = _: true;
    };
  };

  # TODO: Set your username
  home = {
    username = "tholo";
    homeDirectory = "/home/tholo";

    packages = with pkgs; [
      # essentials
      # gcc
      libgcc
      libgccjit
      clang

      # neovim
      nerdfonts
      # (nerdfonts.override { fonts = [ "FiraCode" "FiraCodeMono" "JetBrainsMono"]; })

      vazir-fonts # persian font
      codespell

      proxychains

      # # It is sometimes useful to fine-tune packages, for example, by applying
      # # overrides. You can do that directly here, just don't forget the
      # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
      # # fonts?
      # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

      # # You can also create simple shell scripts directly inside your
      # # configuration. For example, this adds a command 'my-hello' to your
      # # environment:
      # (pkgs.writeShellScriptBin "my-hello" ''
      #   echo "Hello, ${config.home.username}!"
      # '')

      # nix related

      # it provides the command `nom` works just like `nix`
      # with more detailed log output
      nix-output-monitor
      nix-prefetch-github

      # utils
      ripgrep # recursively searches directories for a regex pattern
      jq # A lightweight and flexible command-line JSON processor
      yq-go # yaml processor https://github.com/mikefarah/yq
      fd # A rust alternative to find
      watchexec # Run commands based on file change
      satty # Screen annotatiaon tool
      bottom # System monitor
      dust # a better du
      duf # a better df
      gping # ping but with a graph
      trashy # for deleting things to trash

      grc # command colorizer

      # archives
      zip
      xz
      unzip
      p7zip

      # learning
      tldr
      cht-sh

      # productivity
      # hugo # static site generator
      glow # markdown previewer in terminal

      btop # replacement of htop/nmon
      iotop # io monitoring
      iftop # network monitoring

      # system call monitoring
      strace # system call monitoring
      ltrace # library call monitoring
      lsof # list open files

      # system tools
      sysstat
      lm_sensors # for `sensors` command
      ethtool
      pciutils # lspci
      usbutils # lsusb

      # languages
      lua

      python3
      poetry

      nodejs_21

      # screenshot
      shotman
      grim
      swappy
      slurp

      # clipboard
      wl-clipboard

      # social
      telegram-desktop

      # browser
      # (vivaldi.override {
      # proprietaryCodecs = true;
      # enableWidevine = false;
      # })
      vivaldi
      vivaldi-ffmpeg-codecs

      # audio
      qpwgraph
      helvum
    ];
  };

  # link the configuration file in current directory to the specified location in home directory
  # home.file.".config/i3/wallpaper.jpg".source = ./wallpaper.jpg;

  # link all files in `./scripts` to `~/.config/i3/scripts`
  # home.file.".config/i3/scripts" = {
  #   source = ./scripts;
  #   recursive = true;   # link recursively
  #   executable = true;  # make all files executable
  # };

  # encode the file content in nix configuration file directly
  # home.file.".xxx".text = ''
  #     xxx
  # '';

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  # FIXME: temporary solution, should switch to nixvim
  home.file = {
    # ".config/nvim" = {
    # source = /home/tholo/dotfiles/nvim/.config/nvim;
    # recursive = true;
    # };
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

  # Home Manager can also manage your environment variables through
  # 'home.sessionVariables'. If you don't want to manage your shell through Home
  # Manager then you have to manually source 'hm-session-vars.sh' located at
  # either
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/tholo/etc/profile.d/hm-session-vars.sh
  #
  home.sessionVariables = {
    EDITOR = "nvim";
    SUDO_EDITOR = "nvim";
    VISUAL = "nvim";
    DIFFPROG = "nvim -d";
    MANPAGER = "nvim +Man!";

    http_proxy = "http://localhost:2081";
    HTTP_PROXY = "http://localhost:2081";

    https_proxy = "http://localhost:2081";
    HTTPS_PROXY = "http://localhost:2081";

    socks_proxy = "socks://localhost:2080";
    SOCKS_PROXY = "socks://localhost:2080";

    # System
    # XDG_DATA_DIRS = "/usr/share:/usr/local/share"
    # XDG_CONFIG_DIRS = "/etc/xdg"

    # User
    # XDG_CACHE_HOME = "$HOME/.cache"
    # XDG_CONFIG_HOME = "$HOME/.config"
    # XDG_DATA_HOME = "$HOME/.local/share"
    # XDG_DESKTOP_DIR = "$HOME/Desktop"
    # XDG_DOWNLOAD_DIR = "$HOME/Downloads"
    # XDG_DOCUMENTS_DIR = "$HOME/Documents"
    # XDG_MUSIC_DIR = "$HOME/Music"
    # XDG_PICTURES_DIR = "$HOME/Pictures"
    # XDG_VIDEOS_DIR = "$HOME/Videos"
  };
  # Add stuff for your user as you see fit:
  # programs.neovim.enable = true;
  # home.packages = with pkgs; [ steam ];

  # Enable home-manager
  programs.home-manager.enable = true;

  services = {
    # use headphone buttons to control volume
    mpris-proxy.enable = true;
    kanshi.enable = true;
    # notification daemon
    # mako = { enable = true; };
    # clipboard manager for wayland
    copyq.enable = true;
    # screenshot
    # flameshot.enable = true;
    # screen annotatiaon tool
    # gromit-mpx = {
    #   enable = true;
    #   hotKey = "F9";
    #   # undoKey = "Shift+Insert";
    # };
    # progress bar
    wob = {
      enable = true;
      systemd = true;
    };
    # connect android to linux
    kdeconnect = {
      enable = true;
      indicator = true;
    };
    # auto dark mode
    darkman = {
      enable = true;
      settings = { usegeoclue = true; };
    };

    polybar = {
      script = "polybar bar &";
      enable = true;
    };

    # pipewire audio effects
    easyeffects.enable = true;
  };

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "23.11"; # Please read the comment before changing.
}
