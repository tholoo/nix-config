{
  pkgs,
  config,
  lib,
  host,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "helix";
  # Steelix's Rust queries require its own grammar revision, while the Nixpkgs
  # package currently supplies the older Helix release grammar. Override only
  # this parser so the editor itself can still come from the binary cache.
  rustGrammar = pkgs.steelix.tree-sitter-grammars.tree-sitter-rust.overrideAttrs {
    version = "261b202";
    src = pkgs.fetchFromGitHub {
      owner = "tree-sitter";
      repo = "tree-sitter-rust";
      rev = "261b20226c04ef601adbdf185a800512a5f66291";
      hash = "sha256-i6OrbcHNkrsAW5cpYOI7r0F6xn94KZWB9ZJMUH+k2ds=";
    };
  };
  helixShell = pkgs.writeScriptBin "helix-shell" ''
    #!${pkgs.python3}/bin/python3
    ${builtins.readFile ./yazi.py}
  '';
in
with lib;
with lib.mine;
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "editor"
    ];

    enableLSP = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to enable language servers.";
    };

  };

  config = mkIf cfg.enable {
    xdg.configFile = {
      "helix/runtime/grammars/rust.so".source = "${rustGrammar}/parser";
    };
    home.sessionVariables = {
      EDITOR = lib.mkForce "hx";
      SUDO_EDITOR = lib.mkForce "hx";
      VISUAL = lib.mkForce "hx";
    };

    programs.helix = {
      enable = true;
      package = pkgs.steelix;
      extraPackages = mkIf cfg.enableLSP (
        with pkgs;
        [
          # nix
          nixd
          # yaml
          yaml-language-server
          # vue
          vue-language-server
          # toml
          taplo
          # protobuf
          buf
          # bash
          bash-language-server
          # docker
          docker-compose-language-service
          docker-ls
          # go
          gopls
          delve # debugger
          golangci-lint
          golangci-lint-langserver
          # helm
          helm-ls
          # json
          vscode-json-languageserver
          # typescript
          typescript-language-server
          vscode-langservers-extracted
          biome
          # html
          superhtml
          # kotlin
          kotlin-language-server
          # rust
          lldb
          # c
          clang-tools
          # typst
          tinymist
          typstyle
          # markdown
          markdown-oxide
          # java
          jdt-language-server
        ]
      );
      # https://docs.helix-editor.com/configuration.html
      settings = {
        # theme managed by stylix
        editor = {
          auto-format = true;
          true-color = true;
          auto-save = true;
          line-number = "relative";
          # Ordinary commands still use Nushell. Reserved handoff commands pass
          # the current filename directly to the helper, without shell quoting.
          shell = [
            "${helixShell}/bin/helix-shell"
            (lib.getExe pkgs.nushell)
            (lib.getExe config.programs.yazi.package)
            (lib.getExe config.programs.lazygit.package)
          ];
          cursor-shape = {
            normal = "block";
            insert = "bar";
            select = "underline";
          };
          end-of-line-diagnostics = "hint";
          inline-diagnostics.cursor-line = "hint";
          lsp = {
            display-messages = true;
            display-inlay-hints = false;
          };
          rulers = [
            80
            120
          ];
        };
        keys.normal = {
          L = "extend_to_line_end";
          H = "extend_to_line_start";
          "ret" = "goto_word";
          V = [
            "goto_first_nonwhitespace"
            "extend_to_line_end"
          ];
          esc = [
            "collapse_selection"
            "keep_primary_selection"
          ];
          "C-e" =
            "@"
            + lib.concatMapStrings (command: "${command}<ret>") [
              # Pass the current path as one argument, without shell interpolation.
              # Register Y holds an escaped :open command, or :noop on cancellation.
              ":set-register Y %sh{helix-yazi %{file_path_absolute}}"
              ":<C-r>Y"
              ":redraw"
            ];
          "C-g" =
            "@"
            + lib.concatMapStrings (command: "${command}<ret>") [
              ":set-register Y %sh{helix-lazygit %{file_path_absolute}}"
              ":<C-r>Y"
              ":redraw"
            ];
          space = {
            space = "file_picker";
            i = ":toggle lsp.display-inlay-hints";
            o = ":write";
          };
        };
      };
      languages = mkIf cfg.enableLSP {
        language-server = {
          rust-analyzer = {
            auto-format = true;
            command = lib.getExe pkgs.rust-analyzer-nightly;
            # args = [ "client" ];
            # command = lib.getExe pkgs.ra-multiplex;
            config = {
              cachePriming.enable = true;
              diagnostics.experimental.enable = true;
              procMacro.enable = true;
              check = {
                command = "clippy";
              };
              cargo = {
                allFeatures = true;
              };
            };
          };
          nixd = {
            auto-format = true;
            command = lib.getExe pkgs.nixd;
            config =
              let
                myFlake = ''(builtins.getFlake "/home/${config.mine.user.name}/nix-config")'';
                nixosOpts = ''${myFlake}.nixosConfigurations."${host}".options'';
              in
              {
                nixpkgs.expr = "import ${myFlake}.inputs.nixpkgs { }";
                formatting.command = [ "${lib.getExe pkgs.nixfmt}" ];
                options = {
                  nixos.expr = nixosOpts;
                  # home-manager.expr = ''(builtins.getFlake "/home/${config.mine.user.name}/nix-config").homeConfigurations."${config.mine.user.name}@${host}".options'';
                  home-manager.expr = "${nixosOpts}.home-manager.users.type.getSubOptions []";
                };
              };
          };
          biome = {
            command = "biome";
            args = [ "lsp-proxy" ];
          };
          typos = {
            command = lib.getExe pkgs.typos-lsp;
          };
          harper-ls = {
            command = lib.getExe pkgs.harper;
            args = [ "--stdio" ];
            config.harper-ls = {
              diagnosticSeverity = "hint";
              isolateEnglish = true;
              linters = {
                SpellCheck = false;
                SentenceCapitalization = false;
                LongSentences = false;
                AnA = true;
                UnclosedQuotes = true;
                RepeatedWords = true;
                Spaces = true;
              };
            };
          };
          ruff = {
            command = lib.getExe pkgs.ruff;
            args = [ "server" ];
            config.settings = {
              exclude = [
                ".bzr"
                ".direnv"
                ".eggs"
                ".git"
                ".git-rewrite"
                ".hg"
                ".ipynb_checkpoints"
                ".mypy_cache"
                ".nox"
                ".pants.d"
                ".pyenv"
                ".pytest_cache"
                ".pytype"
                ".ruff_cache"
                ".svn"
                ".tox"
                ".venv"
                ".vscode"
                "__pypackages__"
                "_build"
                "buck-out"
                "build"
                "dist"
                "node_modules"
                "site-packages"
                "venv"
                ".venv"
              ];

              lint = {
                pydocstyle.convention = "google";
                select = [
                  # pydocstyle
                  "D"
                  # pyupgrade
                  "UP"
                  # flynt (convert old format to f string)
                  "FLY"
                  # tryceratops (try except)
                  "TRY"
                  # flake8-django
                  "DJ"
                ];

                # Allow fix for all enabled rules (when `--fix`) is provided.
                fixable = [ "ALL" ];
                unfixable = [ ];

                # Allow unused variables when underscore-prefixed.
                dummy-variable-rgx = "^(_+|(_+[a-zA-Z0-9_]*[a-zA-Z0-9]+?))$";

                # On top of the Google convention, disable `D417`, which requires
                # documentation for every function parameter.
                ignore = [ "D417" ];
              };
            };
          };
          basedpyright = {
            command = lib.getExe' pkgs.basedpyright "basedpyright-langserver";
            args = [ "--stdio" ];
            except-features = [ "format" ];
            config.basedpyright.analysis = {
              typeCheckingMode = "basic";
              autoSearchPaths = true;
            };
          };
          pylyzer = {
            command = lib.getExe pkgs.pylyzer;
            args = [ "--server" ];
          };
          ty = {
            command = lib.getExe pkgs.ty;
            args = [ "server" ];
          };
          godot = {
            command = lib.getExe pkgs.netcat;
            args = [
              "127.0.0.1"
              "6005"
            ];
          };
          efm = {
            command = lib.getExe pkgs.efm-langserver;
            only-features = [
              "diagnostics"
              "format"
            ];
          };
        };

        language = [
          {
            name = "rust";
            auto-format = true;
            formatter.command = "rustfmt --edition 2024 --style-edition 2024";
          }
          {
            name = "typst";
            auto-format = true;
            formatter.command = "typstyle";
          }
          {
            name = "toml";
            language-servers = [
              "taplo"
            ];
            auto-format = true;
            formatter = {
              command = "taplo";
              args = [
                "fmt"
                "-"
              ];
            };
          }
          {
            name = "python";
            language-servers = [
              # "basedpyright"
              "ty"
              "ruff"
              # "pylyzer"
              "typos"
            ];
            auto-format = true;
          }
          {
            name = "nix";
            auto-format = true;
            formatter.command = "${lib.getExe pkgs.nixfmt}";
          }
          {
            name = "gdscript";
            language-servers = [
              "godot"
              "typos"
            ];
          }
          {
            name = "markdown";
            language-servers = [
              "markdown-oxide"
              {
                name = "harper-ls";
                only-features = [
                  "diagnostics"
                  "code-action"
                ];
              }
              {
                name = "typos";
                only-features = [
                  "diagnostics"
                  "code-action"
                ];
              }
            ];
          }
          {
            name = "javascript";
            language-servers = [
              {
                name = "typescript-language-server";
                except-features = [ "format" ];
              }
              "biome"
            ];
            auto-format = true;
          }

          {
            name = "typescript";
            language-servers = [
              {
                name = "typescript-language-server";
                except-features = [ "format" ];
              }
              "biome"
            ];
            auto-format = true;
          }

          {
            name = "tsx";
            auto-format = true;
            language-servers = [
              {
                name = "typescript-language-server";
                except-features = [ "format" ];
              }
              "biome"
            ];
          }
          {
            name = "jsx";
            auto-format = true;
            language-servers = [
              {
                name = "typescript-language-server";
                except-features = [ "format" ];
              }
              "biome"
            ];

          }
          {
            name = "json";
            language-servers = [
              {
                name = "vscode-json-language-server";
                except-features = [ "format" ];
              }
              "biome"
            ];
          }
        ];
      };
    };
  };
}
