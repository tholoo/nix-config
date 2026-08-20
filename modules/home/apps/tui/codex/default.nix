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

  codexPackage = pkgs.symlinkJoin {
    name = "${llmAgents.codex.name}-system-bwrap";
    paths = [ llmAgents.codex ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      rm "$out/bin/codex"
      makeWrapper "${llmAgents.codex}/bin/.codex-wrapped" "$out/bin/codex" \
        --prefix PATH : "/run/wrappers/bin:${pkgs.bubblewrap}/bin"
    '';
  };

  npx = "${pkgs.nodejs}/bin/npx";
  npxPath = lib.makeBinPath [
    pkgs.nodejs
    pkgs.bash
    pkgs.coreutils
  ];

  codexNotify = "${
    pkgs.writeShellApplication {
      name = "codex-notify";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.jq
        pkgs.libnotify
        pkgs.dunst
      ];
      text = builtins.readFile ./notify.sh;
    }
  }/bin/codex-notify";
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
    home = {
      packages = lib.optionals cfg.enableUsageTools [
        # llmAgents.agentsview
        # llmAgents.oh-my-codex
      ];

      sessionVariables.CODEX_HOME = "${config.xdg.configHome}/codex";
    };

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
      package = codexPackage;
      enableMcpIntegration = true;

      settings = {
        personality = "pragmatic";
        model = "gpt-5.6-sol";
        model_reasoning_effort = "high";
        approval_policy = "on-request";
        approvals_reviewer = "auto_review";
        default_mode_request_user_input = true;
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

        features = {
          hooks = true;
          goals = true;
          multi_agent = true;
          shell_snapshot = true;
          terminal_resize_reflow = true;
          codex_git_commit = false;
        };

        notify = [ codexNotify ];

        tui = {
          vim_mode_default = true;
          # Good for Zellij/tmux-style workflows: keep terminal scrollback usable.
          alternate_screen = "auto";
          notification_condition = "always";
          notification_method = "auto";
          notifications = [
            "agent-turn-complete"
            "approval-requested"
          ];
          status_line = [
            "model-with-reasoning"
            "current-dir"
            "git-branch"
            "context-remaining"
          ];

          model_availability_nux."gpt-5.5" = 3;
        };

        hooks = {
          PermissionRequest = [
            {
              hooks = [
                {
                  type = "command";
                  command = codexNotify;
                  timeout = 10;
                  statusMessage = "Sending approval notification";
                }
              ];
            }
          ];
        };
      };

      context = optionalString (cfg.hostContext != null) cfg.hostContext;

      skills = ../ai/skills;
    };

    home.activation.codexLegacyConfig = config.lib.dag.entryAfter [ "writeBoundary" ] ''
      legacy_config="$HOME/.codex/config.toml"
      legacy_skills="$HOME/.codex/skills"
      xdg_config="$HOME/.config/codex/config.toml"
      xdg_skills="$HOME/.config/codex/skills"

      mkdir -p "$HOME/.codex" "$legacy_skills"
      if [ -L "$legacy_config" ]; then
        rm "$legacy_config"
        cp "$xdg_config" "$legacy_config"
        chmod u+w "$legacy_config"
      elif [ ! -e "$legacy_config" ]; then
        cp "$xdg_config" "$legacy_config"
        chmod u+w "$legacy_config"
      fi

      if [ -d "$xdg_skills" ]; then
        for skill in "$xdg_skills"/*; do
          [ -e "$skill" ] || continue
          target="$legacy_skills/$(basename "$skill")"

          if [ -e "$target" ] && [ ! -L "$target" ]; then
            echo "Skipping existing non-symlink Codex skill: $target"
            continue
          fi

          ln -sfn "$skill" "$target"
        done
      fi
    '';
  };
}
