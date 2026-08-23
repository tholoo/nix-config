{
  pkgs,
  config,
  lib,
  ...
}:
let
  inherit (lib) getExe mkIf mkMerge;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "vicinae";
  vigiland = config.mine.vigiland;
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "runner"
    ];
  };

  config = mkMerge [
    (mkIf cfg.enable {
      programs.vicinae = {
        enable = true;
        systemd.enable = true;
        settings = {
          theme = {
            name = "vicinae-dark";
          };
        };
      };
    })
    (mkIf (cfg.enable && vigiland.enable) {
      xdg.dataFile."vicinae/scripts/vigiland" = {
        executable = true;
        onChange = ''
          ${getExe config.programs.vicinae.package} cmd launch core:reload-scripts > /dev/null 2>&1 || true
        '';
        text = ''
          #!${pkgs.runtimeShell}
          # @vicinae.schemaVersion 1
          # @vicinae.title Vigiland
          # @vicinae.mode silent
          # @vicinae.icon ☕
          # @vicinae.keywords ["idle", "inhibit", "caffeine", "awake"]
          # @vicinae.description Toggle the idle inhibitor

          exec ${getExe vigiland.controlPackage} toggle-message
        '';
      };
    })
  ];
}
