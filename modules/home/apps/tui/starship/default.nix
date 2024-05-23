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
  name = "starship";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "tui-interactive"
    ];
  };

  config = mkIf cfg.enable {
    programs.starship = {
      enable = true;
      settings = {
        kubernetes = {
          disabled = false;
          # detect_files = [ "k8s" ];
          contexts = [
            {
              context_pattern = ".*prod.*";
              style = "bold red";
              context_alias = "prod";
            }
            {
              context_pattern = ".*stag.*";
              style = "green";
              context_alias = "stage";
            }
          ];
        };
        # add_newline = false;
        # line_break.disabled = true;
      };
    };
  };
}
