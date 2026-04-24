{
  inputs,
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "secrets";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "secrets"
    ];
  };

  config = mkIf cfg.enable {
    age.secrets = { };
  };
}
