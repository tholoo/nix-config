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
  name = "develop";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "cli-tools"
      "develop"
    ];
  };

  config = mkIf cfg.enable {
    home.sessionVariables = {
      RIP_GRAVEYARD = "~/.local/share/Trash";
    };

    home.packages = with pkgs; [
      # bugstalker # rust debugger
      fenix.complete.toolchain

      python314
    ];

    programs.uv.enable = true;
  };
}
