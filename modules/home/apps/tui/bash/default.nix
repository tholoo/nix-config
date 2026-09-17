{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "bash";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "shell"
    ];
  };

  config = mkIf cfg.enable {
    programs.bash.enable = true;

    # Dev shells can put the minimal Bash build first in PATH.
    home.shellAliases.bash = lib.getExe pkgs.bashInteractive;
  };
}
