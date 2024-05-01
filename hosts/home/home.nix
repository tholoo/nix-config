# Check the size with: nix-shell -p nix-tree.out --run nix-tree
{
  inputs,
  outputs,
  getNixFiles,
  lib,
  pkgs,
  flakeSelf,
  username,
  hostname,
  ...
}:
{
  imports = [
    ../../home-manager/programs/gui
    ../../home-manager/programs/tui
    ../../home-manager/window_manager
    ../../home-manager/services
    inputs.nix-colors.homeManagerModules.default
    # If you want to use modules your own flake exports (from modules/home-manager):
    # outputs.homeManagerModules.example

    # Or modules exported from other flakes (such as nix-colors):
    # inputs.nix-colors.homeManagerModules.default
  ];
  # stylix = {
  #   image = ../resources/wallpapers/wallhaven-fields-858z32.png;
  #   polarity = "dark";
  #
  #   fonts = with pkgs; rec {
  #     monospace = {
  #       name = "Fira Code";
  #       package = fira-code;
  #     };
  #     sansSerif = {
  #       name = "Cantarell";
  #       package = cantarell-fonts;
  #     };
  #     serif = sansSerif;
  #   };
  #
  #   cursor = {
  #     package = pkgs.qogir-icon-theme;
  #     name = "Qogir";
  #   };
  #
  #   targets = {
  #     waybar.enableLeftBackColors = true;
  #     waybar.enableRightBackColors = true;
  #   };
  # };

  colorScheme = inputs.nix-colors.colorSchemes.onedark;

  nix = {
    package = pkgs.nix;
    settings = {
      trusted-users = [
        "root"
        "${username}"
      ];
      max-jobs = "auto";

      # The maximum number of parallel TCP connections used to fetch files from binary caches and by other downloads.
      # It defaults to 25. 0 means no limit.
      http-connections = 128;

      # This option defines the maximum number of substitution jobs that Nix will try to run in
      # parallel. The default is 16. The minimum value one can choose is 1 and lower values will be
      # interpreted as 1.
      max-substitution-jobs = 128;

      # The number of lines of the tail of the log to show if a build fails.
      log-lines = 25;

      # When free disk space in /nix/store drops below min-free during a build, Nix performs a
      # garbage-collection until max-free bytes are available or there is no more garbage.
      # A value of 0 (the default) disables this feature.
      # min-free = 128000000; # 128 MB
      # max-free = 1000000000; # 1 GB

      # Prevent garbage collection from altering nix-shells managed by nix-direnv
      # https://github.com/nix-community/nix-direnv#installation
      # keep-outputs = true;
      # keep-derivations = true;

      # Automatically detect files in the store that have identical contents, and replaces
      # them with hard links to a single copy. This saves disk space.
      auto-optimise-store = true;

      # Whether to warn about dirty Git/Mercurial trees.
      # warn-dirty = false;
    };
  };
  nixpkgs = {
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      outputs.overlays.additions
      outputs.overlays.modifications
      # outputs.overlays.unstable-packages

      # You can also add overlays exported from other flakes:
      # neovim-nightly-overlay.overlays.default

      # Or define it inline, for example:
      # (final: prev: {
      #   hi = final.hello.overrideAttrs (oldAttrs: {
      #     patches = [ ./change-hello-to-hi.patch ];
      #   });
      # })
    ];
    config = {
      allowUnfree = true;
      # Workaround for https://github.com/nix-community/home-manager/issues/2942
      allowUnfreePredicate = _: true;
    };
  };

  fonts.fontconfig.enable = true;

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    extraPortals = with pkgs; [ xdg-desktop-portal-wlr ];
  };

  home = {
    username = "${username}";
    homeDirectory = "/home/${username}";

    packages = with pkgs; [
      # essentials
      xdg-utils
      # gcc
      libgcc
      libgccjit
      clang

      # fonts
      (nerdfonts.override {
        fonts = [
          "FiraCode"
          "FiraMono"
          "JetBrainsMono"
          "Overpass"
          "CascadiaCode"
        ];
      })
      ubuntu_font_family
      # vazir-fonts # persian font
      codespell

      proxychains
      nekoray

      distrobox

      # # this adds a command 'my-hello' to your
      # # environment:
      # (pkgs.writeShellScriptBin "my-hello" ''
      #   echo "Hello, ${config.home.username}!"
      # '')

      # nix related
      # it provides the command `nom` works just like `nix`
      # with more detailed log output
      nix-output-monitor
      nix-prefetch-github
      nix-tree
      nh
      devenv

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
      usql # universal sql cli tool
      gg # for proxying commands
      xh # faster httpie
      asdf-vm # a runtime programming language version manager (like pyenv)
      yt-dlp # audio/video downloader
      inetutils # commands like telnet

      # cool
      figlet # generate ascii art of strings
      grc # command colorizer

      # archives
      zip
      unzip
      p7zip

      # learning
      tldr
      cht-sh
      obsidian

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
      # since 64gram and telegram-desktop share the same bin name:
      (pkgs.writeShellScriptBin "64gram" "exec -a $0 ${lib.getExe _64gram} $@")

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

  home.file = {
    # ".config/nvim" = {
    # source = /home/${username}/dotfiles/nvim/.config/nvim;
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

  # If you don't want to manage your shell through Home
  # Manager then you have to manually source 'hm-session-vars.sh' located at
  # either
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  # or
  #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
  # or
  #  /etc/profiles/per-user/${username}/etc/profile.d/hm-session-vars.sh
  home.sessionVariables = {
    EDITOR = "nvim";
    SUDO_EDITOR = "nvim";
    VISUAL = "nvim";
    DIFFPROG = "nvim -d";
    MANPAGER = "nvim +Man!";

    # http_proxy = "http://localhost:2081";
    # HTTP_PROXY = "http://localhost:2081";

    # https_proxy = "http://localhost:2081";
    # HTTPS_PROXY = "http://localhost:2081";

    # socks_proxy = "socks://localhost:2080";
    # SOCKS_PROXY = "socks://localhost:2080";

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

  programs.home-manager.enable = true;

  services = {
    # screenshot
    # flameshot.enable = true;
    # screen annotatiaon tool
    # gromit-mpx = {
    #   enable = true;
    #   hotKey = "F9";
    #   # undoKey = "Shift+Insert";
    # };
  };

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "23.11"; # Please read the comment before changing.
}
