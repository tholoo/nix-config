{ config, lib, ... }:
let
  cfg = config.mine.agent-desktop;
in
{
  options.mine.agent-desktop = lib.mine.mkEnable config { tags = [ ]; };
  config = lib.mkIf cfg.enable {
    programs.ydotool.enable = true;
    users.users.${config.mine.users.name}.extraGroups = [ config.programs.ydotool.group ];
  };
}
