{ config, pkgs, lib, ... }@inputs:

{
  # imports = [
  # inputs.sops-nix.homeManagerModules.sops
  # agenix.homeManagerModules.default
  # ];
  nixpkgs.config = {
    allowUnfree = true;
    allowUnfreePredicate = (_: true);
  };

  home.username = inputs.username;
  home.homeDirectory = "/home/${inputs.username}";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "23.11"; # Please read the comment before changing.

  home.packages = with pkgs; [
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
    # with more details log output
    nix-output-monitor

    # utils
    ripgrep # recursively searches directories for a regex pattern
    jq # A lightweight and flexible command-line JSON processor
    yq-go # yaml processor https://github.com/mikefarah/yq
    # eza # A modern replacement for ‘ls’
    # fzf # A command-line fuzzy finder
    fd # A rust alternative to find

    # archives
    zip
    xz
    unzip
    p7zip

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

    # browser
    # (vivaldi.override {
    # proprietaryCodecs = true;
    # enableWidevine = false;
    # })
    # vivaldi
    # vivaldi-ffmpeg-codecs
  ];

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

  # wayland.windowManager.sway = {
  # enable = true;
  # xwayland = true;
  # };

  # Use sway desktop environment with Wayland display server
  wayland.windowManager.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
    # Sway-specific Configuration
    config = {
      terminal = "wezterm";
      menu = "wofi --show run";
      # Status bar(s)
      bars = [{
        fonts.size = 15.0;
        command = "waybar";
        position = "bottom";
      }];
      # Display device configuration
      # output = {
      #   eDP-1 = {
      #     # Set HIDP scale (pixel integer scaling)
      #     scale = "1";
      #   };
      # };
    };
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  imports = lib.concatMap import [ ./programs ];

  # programs = {
  # neovim = {
  # enable = true;
  # defaultEditor = true;
  # withPython3 = true;
  # withNodeJs = true;
  # withRuby = true;
  # # vimAlias = true;
  # # extraConfig = ''
  # # set number
  # # syntax on
  # # set shiftwidth=2
  # # set tabstop=2
  # # set expandtab
  # # set smarttab
  # # set clipboard+=unnamedplus
  # # '';
  # # plugins = with pkgs.vimPlugins; [
  # # vim-devicons
  # # vim-nix
  # # ];
  # };

  # alacritty = {
  # enable = true;
  # settings = {
  # env.TERM = "alacritty";
  # window = {
  # decorations = "full";
  # title = "Alacritty";
  # dynamic_title = true;
  # class = {
  # instance = "Alacritty";
  # general = "Alacritty";
  # };
  # };
  # font = {
  # normal = {
  # family = "monospace";
  # style = "regular";
  # };
  # bold = {
  # family = "monospace";
  # style = "regular";
  # };
  # italic = {
  # family = "monospace";
  # style = "regular";
  # };
  # bold_italic = {
  # family = "monospace";
  # style = "regular";
  # };
  # size = 14.00;
  # };
  # colors = {
  # primary = {
  # background = "#1d1f21";
  # foreground = "#c5c8c6";
  # };
  # };
  # };
  # };

  # # gtk = {
  # # enable = true;
  # # theme.name = "adw-gtk3";
  # # cursorTheme.name = "Bibata-Modern-Ice";
  # # iconTheme.name = "GruvboxPlus";
  # # };

  # chromium = {
  # enable = true;
  # };
  # };

  services = {
    # use headphone buttons to control volume
    mpris-proxy.enable = true;
  };
}
