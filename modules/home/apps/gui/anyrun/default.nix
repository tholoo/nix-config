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
  name = "anyrun";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "browser"
      "web"
    ];
  };

  config = mkIf cfg.enable {
    programs.anyrun = {
      enable = true;
      config = {
        plugins = with pkgs; [
          "${anyrun}/lib/libapplications.so"
          "${anyrun}/lib/libdictionary.so"
          "${anyrun}/lib/librink.so"
          "${anyrun}/lib/libtranslate.so"
          "${anyrun}/lib/libsymbols.so"
        ];
        hideIcons = false;
        layer = "overlay";
        hidePluginInfo = true;
        closeOnClick = true;
        showResultsImmediately = true;
        width.fraction = 0.35;
        y.fraction = 0.3;
      };
      extraCss = # css
        ''
          #window {
            background-color: rgba(0, 0, 0, 0);
          }

          box#main {
            border-radius: 15px;
            background-color: rgba(30, 30, 30, 1);
            font-size: 20px;
            border: 2px solid #7e9cd8;
          }

          entry#entry {
            min-height: 50px;
            border-radius: 20px;
            background: transparent;
            box-shadow: none;
            color: #E5EBF7;
            border: none;
          }

          list#main {
            background-color: rgba(0, 0, 0, 0);
          }

          #plugin {
            background: transparent;
            padding-bottom: 5px;
          }

          #match {
            padding: 2.5px;
          }

          #match:selected {
            background: transparent;
            border-right: 4px solid #7e9cd8;
            border-left: 4px solid #7e9cd8;
            border-radius: 4px;
            color: #7e9cd8;
          }

          #match:selected label#info {
            color: #b0b0b0;
            animation: fade 0.1s linear
          }

          @keyframes fade {
            0% {
              color: transparent;
            }

            100% {
              color: #b0b0b0;
            }
          }

          #match label#info {
            color: transparent;
          }

          #match:hover {
            background: transparent;
          }

          label#match-desc {
            font-size: 15px;
            color: #b0b0b0;
          }

          label#plugin {
            font-size: 14px;
          }
        '';

      extraConfigFiles = {
        "applications.ron".text = ''
          Config(
            desktop_actions: false,
            max_entries: 5,
            terminal: Some("ghostty"),
          )
        '';

        "shell.ron".text = ''
          Config(
            prefix: ">"
          )
        '';
      };
    };
  };
}
