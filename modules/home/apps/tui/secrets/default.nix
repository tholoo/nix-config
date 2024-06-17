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
    age.secrets = {
      ip-granite.file = inputs.self + /secrets/ip-granite.age;
      ip-ahm.file = inputs.self + /secrets/ip-ahm.age;
    };
  };
}
