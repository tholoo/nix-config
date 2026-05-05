{
  inputs,
  pkgs,
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkIf
    mkOption
    optionalString
    types
    ;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "codex";

  llmAgents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};

  npx = "${pkgs.nodejs}/bin/npx";
  npxPath = lib.makeBinPath [
    pkgs.nodejs
    pkgs.bash
    pkgs.coreutils
  ];
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
      description = "Host-specific context for Codex (rendered as custom instructions).";
    };

    enableSharedMcp = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to define shared MCP servers and merge them into Codex.";
    };

    enableUsageTools = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to install Codex usage and session analysis tools from llm-agents.nix.";
    };
  };

  config = mkIf cfg.enable {
    home.packages = lib.optionals cfg.enableUsageTools [
      llmAgents.ccusage-codex
      llmAgents.agentsview
      llmAgents.oh-my-codex
    ];

    programs.mcp = mkIf cfg.enableSharedMcp {
      enable = true;
      servers = {
        context7 = {
          command = npx;
          args = [
            "-y"
            "@upstash/context7-mcp"
          ];
          env = {
            PATH = npxPath;
          };
        };

        playwright = {
          command = npx;
          args = [
            "-y"
            "@playwright/mcp@latest"
            "--browser"
            "chromium"
            "--executable-path"
            "${pkgs.playwright-driver.browsers}/chromium-${pkgs.playwright-driver.passthru.browsersJSON.chromium.revision}/chrome-linux64/chrome"
            "--user-data-dir"
            "/tmp/playwright-mcp-userdata"
          ];
          env = {
            PATH = npxPath;
            PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
            PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "true";
          };
        };
      };
    };

    programs.codex = {
      enable = true;
      package = llmAgents.codex;
      enableMcpIntegration = true;

      settings = {
        personality = "pragmatic";
        model_reasoning_effort = "high";
        approval_policy = "on-request";
        sandbox_mode = "workspace-write";
        web_search = "cached";

        projects = {
          "/home/tholo/projects".trust_level = "trusted";
          "/home/tholo/nix-config".trust_level = "trusted";
        };

        plugins = {
          "figma@openai-curated".enabled = true;
          "google-drive@openai-curated".enabled = true;
        };

        tui.model_availability_nux."gpt-5.5" = 3;

        features = {
          multi_agent = true;
          shell_snapshot = true;
          terminal_resize_reflow = true;
        };
      };

      custom-instructions = optionalString (cfg.hostContext != null) cfg.hostContext;

      skills = {
        debug = ../claude/debug-skill.md;
        grill = ../claude/grill-skill.md;
        saiyan = ../claude/saiyan-skill.md;
      };
    };
  };
}
