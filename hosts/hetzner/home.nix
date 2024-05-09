# Check the size with: nix-shell -p nix-tree.out --run nix-tree
{
  inputs,
  outputs,
  pkgs,
  username,
  getNixFiles,
  ...
}:
{
  imports = [
    # don't know why this causes infinite recursion
    # ../../home-manager/programs/tui
    ../../home-manager/programs/tui/bat.nix
    ../../home-manager/programs/tui/direnv.nix
    ../../home-manager/programs/tui/eza.nix
    ../../home-manager/programs/tui/fzf.nix
    ../../home-manager/programs/tui/mcfly.nix
    ../../home-manager/programs/tui/ssh.nix
    ../../home-manager/programs/tui/starship.nix
    ../../home-manager/programs/tui/yazi.nix
    ../../home-manager/programs/tui/zoxide.nix
    ../../home-manager/programs/tui/fish
    ../../home-manager/programs/tui/git
    # ../../home-manager/programs/tui/nixvim
    ../../home-manager/programs/tui/tmux
    ../../home-manager/programs/tui/secrets.nix
  ];

  # # nix = {
  # #   package = pkgs.nix;
  # #   settings = {
  # #     trusted-users = [
  # #       "root"
  # #       "${username}"
  # #     ];
  # #     max-jobs = "auto";
  # #
  # #     log-lines = 25;
  # #
  # #     auto-optimise-store = true;
  # #   };
  # # };
  #
  # # fonts.fontconfig.enable = true;
  #
  home = {
    inherit username;
    homeDirectory = "/home/${username}";

    packages = with pkgs; [
      # essentials
      xdg-utils
      # gcc
      libgcc
      libgccjit
      clang

      proxychains

      distrobox

      # nix related
      # it provides the command `nom` works just like `nix`
      # with more detailed log output
      nix-output-monitor
      nix-prefetch-github
      nix-tree
      nh
      devenv
      manix
      nurl

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
      calibre

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

      # clipboard
      wl-clipboard
    ];
  };
  #
  # # home.sessionVariables = {
  # #   EDITOR = "nvim";
  # #   SUDO_EDITOR = "nvim";
  # #   VISUAL = "nvim";
  # #   DIFFPROG = "nvim -d";
  # #   MANPAGER = "nvim +Man!";
  # # };
  #
  programs.home-manager.enable = true;
  #
  # # Nicely reload system units when changing configs
  # systemd.user.startServices = "sd-switch";
  #
  # # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "23.11"; # Please read the comment before changing.
}
