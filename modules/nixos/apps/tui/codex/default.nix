{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf;
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
  };

  config = mkIf cfg.enable {
    environment.etc."codex/requirements.toml".source =
      (pkgs.formats.toml { }).generate "codex-requirements.toml"
        codexHooks.requirements;
  };
}
