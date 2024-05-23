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
  name = "helix";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "editor"
    ];
  };

  config = mkIf cfg.enable {
    programs.helix = {
      enable = true;
      # https://docs.helix-editor.com/languages.html
      languages = {
        language-server = {
          typescript-language-server = with pkgs.nodePackages; {
            command = "''${typescript-language-server}/bin/typescript-language-server";
            args = [
              "--stdio"
              "--tsserver-path=''${typescript}/lib/node_modules/typescript/lib"
            ];
          };
        };

        language = [
          { name = "rust"; }
          { name = "python"; }
        ];
      };

      # https://docs.helix-editor.com/configuration.html
      settings = {
        # theme = "base16";
        editor = {
          auto-save = true;
          line-number = "relative";
          lsp = {
            display-messages = true;
            display-inlay-hints = true;
          };
        };
        keys.normal = {
          space.space = "file_picker";
          # space.w = ":w";
          esc = [
            "collapse_selection"
            "keep_primary_selection"
          ];
        };
      };
    };
  };
}
