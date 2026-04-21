{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.claude-code;
  name = "claude-code";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "develop"
      "cli-tools"
      "ai"
    ];
  };

  config = mkIf cfg.enable {
    programs.claude-code = {
      enable = true;

      settings = {
        theme = "dark";
        includeCoAuthoredBy = false;

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
                  # Auto-format .nix files after edits
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
    };
  };
}
