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

  codexRuntimePackage = pkgs.symlinkJoin {
    name = "${llmAgents.codex.name}-system-bwrap";
    paths = [ llmAgents.codex ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      rm "$out/bin/codex"
      makeWrapper "${llmAgents.codex}/bin/.codex-wrapped" "$out/bin/codex" \
        --prefix PATH : "/run/wrappers/bin:${pkgs.bubblewrap}/bin" \
        ${optionalString (cfg.proxyUrl != null) ''
          --set-default HTTP_PROXY ${lib.escapeShellArg cfg.proxyUrl} \
          --set-default HTTPS_PROXY ${lib.escapeShellArg cfg.proxyUrl} \
          --set-default ALL_PROXY ${lib.escapeShellArg cfg.proxyUrl} \
          --set-default http_proxy ${lib.escapeShellArg cfg.proxyUrl} \
          --set-default https_proxy ${lib.escapeShellArg cfg.proxyUrl} \
          --set-default all_proxy ${lib.escapeShellArg cfg.proxyUrl}
        ''}
    '';
    meta.mainProgram = "codex";
  };

  npx = "${pkgs.nodejs}/bin/npx";
  npxPath = lib.makeBinPath [
    pkgs.nodejs
    pkgs.bash
    pkgs.coreutils
  ];

  dokployMcp = pkgs.writeShellApplication {
    name = "dokploy-mcp";
    runtimeInputs = [ pkgs.nodejs ];
    text = ''
      token_file="${config.age.secrets.dokploy-api-key.path}"

      if [[ ! -s "$token_file" ]]; then
        echo "Dokploy API token is missing: $token_file" >&2
        exit 1
      fi

      DOKPLOY_API_KEY="$(<"$token_file")"
      export DOKPLOY_API_KEY
      export DOKPLOY_URL="https://dokploy.ditollo.com"
      export DOKPLOY_TOOL_PRESET="deploy"
      export DOKPLOY_REDACT_ENV="true"

      exec ${npx} -y @dokploy/mcp@0.30.2
    '';
  };

  codexHooks = import ../../../../shared/codex-hooks.nix {
    inherit inputs lib pkgs;
  };
  codexNotify = codexHooks.notifyCommand;
  agentDeck = inputs.zellij-agent-deck.packages.${pkgs.stdenv.hostPlatform.system}.default;
  codexPackage = inputs.zellij-agent-deck.lib.mkCodexWrapper {
    inherit pkgs agentDeck;
    codex = codexRuntimePackage;
    name = "${llmAgents.codex.name}-zellij-resume";
  };

  agentSkills = import ../ai/skills.nix { inherit inputs lib; };

  codexSettings = {
    personality = "pragmatic";
    model = "gpt-5.6-sol";
    model_reasoning_effort = "high";
    approval_policy = "on-request";
    approvals_reviewer = "auto_review";
    default_mode_request_user_input = true;
    sandbox_mode = "workspace-write";
    web_search = "cached";

    plugins = {
      "figma@openai-curated".enabled = true;
      "google-drive@openai-curated".enabled = true;
    };

    features = {
      hooks = true;
      goals = true;
      multi_agent = true;
      respect_system_proxy = true;
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
        "thread-title"
      ];

      model_availability_nux."gpt-5.5" = 3;
    };
  };

  codexMcpServers = lib.mapAttrs (
    _name: server:
    lib.filterAttrsRecursive (_name: value: value != null) (
      (lib.removeAttrs server [
        "disabled"
        "headers"
      ])
      // (lib.optionalAttrs ((server.url or null) != null && (server.headers or { }) != { }) {
        http_headers = server.headers;
      })
      // {
        enabled = !(server.disabled or false);
      }
    )
  ) config.programs.mcp.servers;

  managedSettings =
    codexSettings
    // lib.optionalAttrs (cfg.enableSharedMcp && codexMcpServers != { }) {
      mcp_servers = codexMcpServers;
    };

  managedConfig = (pkgs.formats.toml { }).generate "codex-managed-config.toml" managedSettings;
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

    proxyUrl = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "http://127.0.0.1:10808";
      description = "Default proxy URL exported to Codex when no proxy environment override is set.";
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

    enableBoardService = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to run the ESP32 Codex dashboard bridge as a user service.";
    };
  };

  config = mkIf cfg.enable {
    age.secrets.dokploy-api-key.file = inputs.self + /secrets/dokploy/dokploy-api-key.age;

    home = {
      packages = [
        codexHooks.boardPackage
      ]
      ++ lib.optionals cfg.enableUsageTools [
        # llmAgents.agentsview
        # llmAgents.oh-my-codex
      ];

      sessionVariables.CODEX_HOME = "${config.xdg.configHome}/codex";
    };

    # Codex needs to update config.toml when the user trusts a project. Keep it
    # as a normal file instead of a Home Manager symlink into the Nix store.
    # On activation, declarative settings win while runtime-only keys (notably
    # `projects`) are preserved from the existing writable file.
    home.activation.codexWritableConfig = config.lib.dag.entryAfter [ "writeBoundary" ] ''
      codex_home=${lib.escapeShellArg "${config.xdg.configHome}/codex"}
      config_file="$codex_home/config.toml"
      managed_config=${lib.escapeShellArg managedConfig}

      mkdir -p -- "$codex_home"
      new_config="$(${pkgs.coreutils}/bin/mktemp "$codex_home/.config.toml.XXXXXX")"
      trap 'rm -f -- "$new_config" "''${projects_config:-}"' EXIT

      ${pkgs.coreutils}/bin/cp -- "$managed_config" "$new_config"
      if [ -e "$config_file" ] && \
        ${pkgs.yq-go}/bin/yq -e -p toml '.projects != null' "$config_file" >/dev/null
      then
        projects_config="$(${pkgs.coreutils}/bin/mktemp "$codex_home/.projects.toml.XXXXXX")"
        ${pkgs.yq-go}/bin/yq -p toml -o toml 'pick(["projects"])' \
          "$config_file" > "$projects_config"
        ${pkgs.yq-go}/bin/yq eval-all -p toml -o toml \
          'select(fileIndex == 0) * select(fileIndex == 1)' \
          "$managed_config" "$projects_config" > "$new_config"
      fi
      chmod 600 "$new_config"
      mv -f -- "$new_config" "$config_file"
      trap - EXIT
    '';

    programs.nushell.environmentVariables.CODEX_HOME = "${config.xdg.configHome}/codex";

    systemd.user.services."codex-board" = mkIf cfg.enableBoardService {
      Unit = {
        Description = "ESP32 Codex dashboard bridge";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${lib.getExe codexHooks.boardPackage} daemon --port auto";
        Restart = "on-failure";
        RestartSec = "3s";
        UMask = "0077";
        Environment = [
          "PYTHONUNBUFFERED=1"
          "CODEX_HOME=${config.xdg.configHome}/codex"
        ]
        ++ lib.optionals (cfg.proxyUrl != null) [
          "HTTP_PROXY=${cfg.proxyUrl}"
          "HTTPS_PROXY=${cfg.proxyUrl}"
          "ALL_PROXY=${cfg.proxyUrl}"
          "http_proxy=${cfg.proxyUrl}"
          "https_proxy=${cfg.proxyUrl}"
          "all_proxy=${cfg.proxyUrl}"
        ];
      };
      Install.WantedBy = [ "default.target" ];
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

        dokploy = {
          command = lib.getExe dokployMcp;
          env_vars = [ "XDG_RUNTIME_DIR" ];
          startup_timeout_sec = 60;
          tool_timeout_sec = 300;
          default_tools_approval_mode = "writes";
        };
      };
    };

    programs.codex = {
      enable = true;
      package = codexPackage;
      enableMcpIntegration = false;
      settings = { };

      context = optionalString (cfg.hostContext != null) cfg.hostContext;

      skills = agentSkills;
    };

  };
}
