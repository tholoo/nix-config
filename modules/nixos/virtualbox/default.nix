{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "virtualbox";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "graphics"
      "vm"
    ];
  };

  config = mkIf cfg.enable {
    # virtualisation.virtualbox.host.enable = true;
    # users.extraGroups.vboxusers.members = [ "tholo" ];
  };
}
