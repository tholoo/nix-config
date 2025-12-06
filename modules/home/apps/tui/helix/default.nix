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
in
with lib;
with lib.mine;
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "editor"
      "devleop"
    ];

    enableLSP = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to enable language servers.";
    };

  };

  config = mkIf cfg.enable {
    home.sessionVariables = {
      EDITOR = lib.mkForce "hx";
      SUDO_EDITOR = lib.mkForce "hx";
      VISUAL = lib.mkForce "hx";
    };

    programs.helix = {
      enable = true;
      extraPackages = mkIf cfg.enable (
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
          nodePackages.vscode-json-languageserver
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
        ]
      );
      # https://docs.helix-editor.com/configuration.html
      settings = {
        theme = "ayu_dark";
        editor = {
          auto-format = true;
          true-color = true;
          auto-save = true;
          line-number = "relative";
          shell = [
            "nu"
            "-c"
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
          space = {
            space = "file_picker";
            i = ":toggle lsp.display-inlay-hints";
            o = ":write";
          };
        };
      };
      languages = {
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
            config = {
              options = {
                nixos.expr = ''(builtins.getFlake "/home/${config.mine.user.name}/nix-config").nixosConfigurations."${host}".options'';
                home-manager.expr = ''(builtins.getFlake "/home/${config.mine.user.name}/nix-config").homeConfigurations."${config.mine.user.name}@${host}".options'';
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
              "basedpyright"
              "ruff"
              # "pylyzer"
              "typos"
            ];
            auto-format = true;
          }
          {
            name = "nix";
            auto-format = true;
            formatter.command = "${lib.getExe pkgs.nixfmt-rfc-style}";
          }
          {
            name = "gdscript";
            language-servers = [
              "godot"
              "typos"
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
