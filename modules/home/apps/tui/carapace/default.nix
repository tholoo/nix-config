{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "carapace";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "shell"
      "interactive"
    ];
  };

  config = mkIf cfg.enable {
    programs.${name} = {
      enable = false;
    };
  };
}
