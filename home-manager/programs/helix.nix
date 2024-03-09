{ pkgs, ... }: {
  programs.helix = {
    enable = true;
    # https://docs.helix-editor.com/languages.html
    languages = {
      language-server = {
        typescript-language-server = with pkgs.nodePackages; {
          command =
            "''${typescript-language-server}/bin/typescript-language-server";
          args = [
            "--stdio"
            "--tsserver-path=''${typescript}/lib/node_modules/typescript/lib"
          ];
        };
      };

      language = [ { name = "rust"; } { name = "python"; } ];
    };

    # https://docs.helix-editor.com/configuration.html
    settings = {
      # theme = "base16";
      editor = {
        line-number = "relative";
        lsp.display-messages = true;
      };
      keys.normal = {
        space.space = "file_picker";
        # space.w = ":w";
        esc = [ "collapse_selection" "keep_primary_selection" ];
      };
    };
  };
}
