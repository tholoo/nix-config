let
  more = { pkgs, ... }: {
    programs = {
      zoxide = {
        enable = true;
      };
      fzf = {
        enable = true;
        enableFishIntegration = true;
        tmux.enableShellIntegration = false;
      };
      eza = {
        enable = true;
        enableAliases = false;
        git = true;
        icons = true;
        extraOptions = [
          "--group-directories-first"
        ];
      };
      bat = {
        enable = true;
      };
      starship = {
        enable = true;
        # settings = {
          # add_newline = false;
          # aws.disabled = true;
          # gcloud.disabled = true;
          # line_break.disabled = true;
        # };
      };
      ssh = {
        enable = true;
      };
      rofi = {
        enable = true;
        terminal = "${pkgs.wezterm}/bin/wezterm";
      };
    };
  };
in
[
  ./wezterm
  ./git
  ./fish
  ./tmux
  ./python
  ./xsession
  # ./nixvim
  more
]

