{ config, lib, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "tui";
in
{
  options.mine.${name} = mkEnable config { tags = [ ]; };

  config = mkIf cfg.enable { mine.tags.include = [ "tui" ]; };
}
