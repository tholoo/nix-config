{
  config,
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
  cfg = config.mine.claude-code;
  name = "claude-code";

  jsonFormat = pkgs.formats.json { };
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "develop"
      "cli-tools"
      "ai"
    ];

    hostContext = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Host-specific context for Claude Code (rendered as a rule file).";
    };

    proxyUrl = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "socks5://127.0.0.1:1080";
      description = "Proxy URL for Claude Code API requests. Read by the overlay wrapper.";
    };
  };

  config = mkIf cfg.enable {
    programs.claude-code = {
      enable = true;

      settings =
        {
          theme = "dark";
          includeCoAuthoredBy = false;
        }
        // lib.optionalAttrs (cfg.proxyUrl != null) {
          proxyUrl = cfg.proxyUrl;
        }
        // {
          permissions = {
            defaultMode = "acceptEdits";
            allow = [
              "Bash(git *)"
              "Bash(nix fmt:*)"
              "Bash(nix build:*)"
              "Bash(nix develop:*)"
              "Bash(nix run:*)"
              "Bash(nix flake *)"
              "Bash(agenix *)"
              "Bash(ls:*)"
              "Bash(which:*)"
              "Bash(man:*)"
              "Edit"
              "Read"
            ];
            ask = [
              "Bash(nixos-rebuild *)"
              "Bash(deploy *)"
              "Bash(rm *)"
            ];
            deny = [
              "Bash(rm -rf:*)"
              "Read(./.env)"
              "Read(./secrets/**)"
            ];
          };

          hooks = {
            PostToolUse = [
              {
                matcher = "Edit|MultiEdit|Write";
                hooks = [
                  {
                    type = "command";
                    command = ''
                      file=$(jq -r '.tool_input.file_path // empty' <<< "$CLAUDE_TOOL_INPUT")
                      [[ "$file" == *.nix ]] && nix fmt "$file" 2>/dev/null || true
                    '';
                  }
                ];
              }
            ];
          };
        };

      rules = lib.optionalAttrs (cfg.hostContext != null) {
        host-context = cfg.hostContext;
      };
    };

    # Keybindings: shift+enter for newline, unbind alt+enter
    home.file.".claude/keybindings.json" = {
      source = jsonFormat.generate "claude-code-keybindings.json" {
        "$schema" = "https://www.schemastore.org/claude-code-keybindings.json";
        bindings = [
          {
            context = "Chat";
            bindings = {
              "shift+enter" = "chat:newline";
              "alt+enter" = null;
            };
          }
        ];
      };
    };
  };
}
