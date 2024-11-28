{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "gpg";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "password"
    ];
  };

  config = mkIf cfg.enable {
    programs.${name} = {
      enable = true;
    };
  };
}
