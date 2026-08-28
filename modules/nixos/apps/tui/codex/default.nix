{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkIf
    mkOption
    types
    ;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "codex";

  codexHooks = import ../../../../shared/codex-hooks.nix {
    inherit inputs lib pkgs;
  };
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "ai"
    ];

    enableBoardUdev = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to grant the active desktop user access to the ESP32 dashboard USB serial interface.";
    };
  };

  config = mkIf cfg.enable {
    environment.etc."codex/requirements.toml".source =
      (pkgs.formats.toml { }).generate "codex-requirements.toml"
        codexHooks.requirements;

    services.udev.extraRules = lib.optionalString cfg.enableBoardUdev ''
      SUBSYSTEM=="tty", ATTRS{idVendor}=="303a", ATTRS{idProduct}=="1001", GROUP="users", MODE="0660"
      SUBSYSTEM=="tty", ATTRS{idVendor}=="303a", ATTRS{idProduct}=="4001", GROUP="users", MODE="0660"
    '';
  };
}
