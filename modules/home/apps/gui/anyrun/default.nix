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
          @define-color accent #7e9cd8;
          @define-color bg-color #1e1e1e;
          @define-color fg-color #E5EBF7;
          @define-color desc-color #b0b0b0;

          window {
            background-color: rgba(0, 0, 0, 0);
          }

          box.main {
            border-radius: 15px;
            background-color: @bg-color;
            font-size: 20px;
            border: 2px solid @accent;
            margin: 10px;
            padding: 5px;
            box-shadow: none;
          }

          text {
            min-height: 50px;
            border-radius: 20px;
            background: transparent;
            box-shadow: none;
            color: @fg-color;
            border: none;
          }

          list.plugin {
            background-color: transparent;
          }

          box.plugin {
            background: transparent;
            padding-bottom: 5px;
          }

          label.match {
            padding: 2.5px;
            color: @fg-color;
          }

          .match {
            background: transparent;
          }

          .match:hover {
            background: transparent;
          }

          .match:selected {
            background: transparent;
            border-right: 4px solid @accent;
            border-left: 4px solid @accent;
            border-radius: 4px;
            color: @accent;
            animation: fade 0.1s linear;
          }

          label.plugin.info {
            font-size: 14px;
            color: @fg-color;
          }

          .match label.plugin.info {
            color: transparent;
          }

          .match:selected label.plugin.info {
            color: @desc-color;
            animation: fade 0.1s linear;
          }

          label.match.description {
            font-size: 15px;
            color: @desc-color;
          }

          box.plugin:first-child {
            margin-top: 5px;
          }

          @keyframes fade {
            0% {
              opacity: 0;
            }

            100% {
              opacity: 1;
            }
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
