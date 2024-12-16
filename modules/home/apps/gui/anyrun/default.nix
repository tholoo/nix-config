{
  pkgs,
  config,
  lib,
  inputs,
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
        plugins = with inputs.anyrun.packages.${pkgs.system}; [
          applications
          dictionary
          rink
          translate
          # symbols (BROKEN)
          # randr (BROKEN)
        ];
        hideIcons = false;
        layer = "overlay";
        hidePluginInfo = true;
        closeOnClick = true;
        showResultsImmediately = true;
        width.fraction = 0.25;
        y.fraction = 0.3;
      };
      extraCss = # css
        ''
                  #window {
            background-color: rgba(0, 0, 0, 0);
          }

          box#main {
            border-radius: 20px;
            background-color: rgba(38, 38, 38, 0.8);
            border: 2px solid #7e9cd8;
          }

          entry#entry {
            min-height: 40px;
            border-radius: 20px;
            background: transparent;
            box-shadow: none;
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
            font-size: 10px;
            color: #b0b0b0;
          }

          label#plugin {
            font-size: 14px;
          }
        '';
      # extraCss = ''
      #   * {
      #     all: unset;
      #     font-size: 1.2rem;
      #   }
      #
      #   #window,
      #   #match,
      #   #entry,
      #   #plugin,
      #   #main {
      #     background: transparent;
      #   }
      #
      #   #match.activatable {
      #     border-radius: 8px;
      #     margin: 4px 0;
      #     padding: 4px;
      #     /* transition: 100ms ease-out; */
      #   }
      #   #match.activatable:first-child {
      #     margin-top: 12px;
      #   }
      #   #match.activatable:last-child {
      #     margin-bottom: 0;
      #   }
      #
      #   #match:hover {
      #     background: rgba(255, 255, 255, 0.05);
      #   }
      #   #match:selected {
      #     background: rgba(255, 255, 255, 0.1);
      #   }
      #
      #   #entry {
      #     background: rgba(255, 255, 255, 0.05);
      #     border: 1px solid rgba(255, 255, 255, 0.1);
      #     border-radius: 8px;
      #     padding: 4px 8px;
      #   }
      #
      #   box#main {
      #     background: rgba(0, 0, 0, 0.5);
      #     box-shadow:
      #       inset 0 0 0 1px rgba(255, 255, 255, 0.9),
      #       0 30px 30px 15px rgba(0, 0, 0, 0.5);
      #     border-radius: 20px;
      #     padding: 12px;
      #   }
      # '';

      extraConfigFiles = {
        "applications.ron".text = ''
          Config(
            desktop_actions: false,
            max_entries: 5,
            terminal: Some("kitty"),
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
