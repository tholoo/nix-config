{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "keychain";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "ssh"
      "password"
    ];
  };

  config = mkIf cfg.enable {
    programs.${name} = {
      enable = true;
      keys = [ "id_ed25519" ];
    };
  };
}
