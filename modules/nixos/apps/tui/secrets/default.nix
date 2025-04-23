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
      singbox-domain.file = inputs.self + /secrets/singbox-domain.age;
      singbox-header-domain.file = inputs.self + /secrets/singbox-header-domain.age;
      singbox-uuid.file = inputs.self + /secrets/singbox-uuid.age;
      singbox-clash-pass.file = inputs.self + /secrets/singbox-clash-pass.age;
    };
  };
}
