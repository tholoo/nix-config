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
    age = {
      identityPaths = [ "/home/${config.mine.user.name}/.ssh/id_ed25519" ];
      secrets = {
        ip-granite.file = inputs.self + /secrets/ips/ip-granite.age;
        ip-flint.file = inputs.self + /secrets/ips/ip-flint.age;
        ip-parsa-hetzner-germany.file = inputs.self + /secrets/ips/ip-parsa-hetzner-germany.age;
        ip-ahmad-hetzner-germany.file = inputs.self + /secrets/ips/ip-ahmad-hetzner-germany.age;
        ip-parsa-iranserver-tehran.file = inputs.self + /secrets/ips/ip-parsa-iranserver-tehran.age;
        ip-parsa-asiatech-tehran.file = inputs.self + /secrets/ips/ip-parsa-asiatech-tehran.age;
        ip-parsa-asiatech-tehran2.file = inputs.self + /secrets/ips/ip-parsa-asiatech-tehran2.age;
        ip-mohammad-do.file = inputs.self + /secrets/ips/ip-mohammad-do.age;
      };
    };
  };
}
