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
  name = "anki";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "study"
    ];
  };

  config = mkIf cfg.enable {
    programs.anki = {
      enable = true;
      addons = [
        # AnkiConnect — required by mpvacious to create cards from mpv.
        # mpvacious talks to it at http://127.0.0.1:8765 while Anki is running.
        pkgs.ankiAddons.anki-connect
        # Calendar heatmap of daily reviews — motivational, low overhead.
        pkgs.ankiAddons.review-heatmap
        # Auto-mark-known: track consecutive Easy answers on French Mining
        # notes; after 3, append Lemma to ~/.local/share/frdict/known.txt and
        # suspend the cards. Same known.txt that frmine.lua reads.
        (pkgs.anki-utils.buildAnkiAddon {
          pname = "auto-mark-known";
          version = "1.0";
          src = ./auto-mark-known;
        })
      ];
    };
  };
}
