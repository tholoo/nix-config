{
  pkgs,
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "cli-cool";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "cli-misc"
    ];
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      figlet # generate ascii art of strings
      grc # command colorizer
      # fetchers
      fastfetch
      onefetch
    ];
  };
}
