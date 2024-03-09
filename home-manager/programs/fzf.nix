{ pkgs, ... }: {
  programs.fzf = {
    enable = true;
    enableFishIntegration = true;
    tmux.enableShellIntegration = false;
  };
}
