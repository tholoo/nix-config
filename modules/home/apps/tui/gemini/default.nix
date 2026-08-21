{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkIf
    mkOption
    optionalAttrs
    types
    ;
  inherit (lib.mine) mkEnable;

  cfg = config.mine.${name};
  name = "antigravity-cli";

  llmAgents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
  agentSkills = import ../ai/skills.nix { inherit inputs lib; };
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
      description = "Host-specific context for Gemini CLI.";
    };

    defaultModel = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "gemini-2.5-flash";
      description = "The default Gemini model to expose through GEMINI_MODEL.";
    };
  };

  config = mkIf cfg.enable {
    programs.antigravity-cli = {
      enable = false;
      package = llmAgents.antigravity-cli;
      enableMcpIntegration = true;
      inherit (cfg) defaultModel;

      settings = {
        ui.theme = "Default";
        general = {
          vimMode = true;
          preferredEditor = "hx";
          previewFeatures = true;
        };
        ide.enabled = true;
        privacy.usageStatisticsEnabled = false;
        tools.autoAccept = false;
        context = {
          fileName = [
            "GEMINI.md"
            "AGENTS.md"
            "CONTEXT.md"
          ];
          loadMemoryFromIncludeDirectories = true;
        };
        security.auth.selectedType = "oauth-personal";
      };

      context = optionalAttrs (cfg.hostContext != null) {
        CONTEXT = ''
          # Host Context

        ''
        + cfg.hostContext;
      };

      skills = agentSkills;
    };
  };
}
