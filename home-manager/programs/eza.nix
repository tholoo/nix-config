{ pkgs, ... }: {
  programs.eza = {
    enable = true;
    enableAliases = false;
    git = true;
    icons = true;
    extraOptions = [ "--group-directories-first" ];
  };
}
