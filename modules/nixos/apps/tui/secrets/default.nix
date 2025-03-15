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
      singbox-obfs-pass.file = inputs.self + /secrets/singbox-obfs-pass.age;
      singbox-pass.file = inputs.self + /secrets/singbox-pass.age;
      singbox-clash-pass.file = inputs.self + /secrets/singbox-clash-pass.age;
    };
  };
}
