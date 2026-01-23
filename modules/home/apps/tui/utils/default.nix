{
  pkgs,
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "utils";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "cli-tools"
    ];
  };

  config = mkIf cfg.enable {
    home.sessionVariables = {
      RIP_GRAVEYARD = "~/.local/share/Trash";
    };

    home.packages = with pkgs; [
      jnv # interactive jq
      yq-go # yaml processor https://github.com/mikefarah/yq
      watchexec # Run commands based on file change
      dust # a better du
      duf # a better df
      gping # ping but with a graph
      trashy # for deleting things to trash
      usql # universal sql cli tool
      xh # faster httpie
      asdf-vm # a runtime programming language version manager (like pyenv)
      inetutils # commands like telnet
      sd # better sed
      lazydocker # like lazygit but for docker
      hyperfine # measuring and comparing execution speed of commands
      gnumeric # converting csv and excel
      rainfrog # tui database management
      rip2 # RM Improved
      serpl # search and replace
      ncdu # see what's taking up space
      gparted # disk management

      nmap
      dnsutils
    ];
  };
}
