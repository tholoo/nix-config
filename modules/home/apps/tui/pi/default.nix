{
  inputs,
  pkgs,
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf mkOption types;
  cfg = config.mine.pi;
  json = pkgs.formats.json { };
  basePi = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi;
  extensionRoot = "${pkgs.mine.pi-extensions}/lib/pi-extensions/node_modules";
  permissionExtensions = [
    "${extensionRoot}/@gotgenes/pi-permission-system/precompiled/index.js"
    "${extensionRoot}/@mzwing/pi-permission-auto-review/dist/index.js"
  ];
  agentSkills = import ../ai/skills.nix { inherit inputs lib pkgs; };
  skills = pkgs.linkFarm "pi-skills" (
    lib.mapAttrsToList (name: path: { inherit name path; }) agentSkills
  );
  noProxy = lib.concatStringsSep "," cfg.noProxy;
  package = pkgs.symlinkJoin {
    name = "${basePi.name}-configured";
    paths = [ basePi ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      rm "$out/bin/pi"
      wrapper_args=(
        --set-default PI_CODING_AGENT_DIR ${lib.escapeShellArg "${config.home.homeDirectory}/.pi/agent"}
        --set PI_OFFLINE 1
        --set PI_TELEMETRY 0
        --set PI_MCP_CONFIG_MODE exclusive
        --unset OPENAI_API_KEY
        --set-default NO_PROXY ${lib.escapeShellArg noProxy}
        --set-default no_proxy ${lib.escapeShellArg noProxy}
        --prefix PATH : ${
          lib.makeBinPath [
            pkgs.nodejs
            pkgs.git
            pkgs.ripgrep
            pkgs.fd
          ]
        }
      )
      ${lib.optionalString cfg.enableNotifications ''
        wrapper_args+=(--set PI_NOTIFY_SEND ${lib.getExe' pkgs.libnotify "notify-send"})
      ''}
      ${lib.optionalString (cfg.proxyUrl != null) ''
        wrapper_args+=(
          --set-default HTTP_PROXY ${lib.escapeShellArg cfg.proxyUrl}
          --set-default HTTPS_PROXY ${lib.escapeShellArg cfg.proxyUrl}
          --set-default ALL_PROXY ${lib.escapeShellArg cfg.proxyUrl}
          --set-default http_proxy ${lib.escapeShellArg cfg.proxyUrl}
          --set-default https_proxy ${lib.escapeShellArg cfg.proxyUrl}
          --set-default all_proxy ${lib.escapeShellArg cfg.proxyUrl}
        )
      ''}
      makeWrapper ${lib.getExe basePi} "$out/bin/pi" "''${wrapper_args[@]}"
    '';
    meta.mainProgram = "pi";
  };

  # Translate only supported adapter fields. In particular, Codex's dynamic
  # header helper is a per-request executable in Pi, never a stored token.
  mcpServers = lib.mapAttrs (
    name: server:
    let
      remote = (server.url or null) != null;
      helper = server.http_headers_helper or null;
    in
    {
      lifecycle =
        if
          lib.elem name [
            "playwright"
            "zen-browser"
            "nvim"
          ]
        then
          "lazy-keep-alive"
        else
          "lazy";
      directTools = "search";
    }
    // (
      if remote then
        {
          inherit (server) url;
          headers = (server.headers or { }) // (server.http_headers or { });
        }
      else
        {
          inherit (server) command;
          args =
            (server.args or [ ])
            ++ lib.optionals (name == "playwright") [
              "--agent"
              "pi"
            ];
          env = server.env or { };
        }
    )
    // lib.optionalAttrs (helper != null) {
      requestHeadersCommand = {
        command = helper;
        timeoutMs = 5000;
      };
      auth = false;
    }
    // lib.optionalAttrs ((server.tool_timeout_sec or null) != null) {
      requestTimeoutMs = server.tool_timeout_sec * 1000;
    }
    # These service catalogs can change; explicit approval is conservative
    # until a server supplies a stable, reviewed set of mutating tool names.
    // lib.optionalAttrs ((server.default_tools_approval_mode or null) == "writes") {
      approveTools = true;
    }
  ) (lib.filterAttrs (_: server: !(server.disabled or false)) config.programs.mcp.servers);

  managedSettings = {
    defaultProvider = "openai-codex";
    defaultModel = cfg.model;
    defaultThinkingLevel = "high";
    enabledModels = [ "openai-codex/*" ];
    defaultProjectTrust = "ask";
    theme = "dark";
    quietStartup = false;
    collapseChangelog = true;
    enableInstallTelemetry = false;
    enableAnalytics = false;
    hideThinkingBlock = true;
    piVim.clipboardMirror = "yank";
    compaction = {
      enabled = true;
      reserveTokens = 16384;
      keepRecentTokens = 20000;
    };
    retry = {
      enabled = true;
      maxRetries = 3;
      baseDelayMs = 2000;
      maxAgentDelayMs = 60000;
      provider = {
        maxRetries = 0;
        maxRetryDelayMs = 60000;
      };
    };
    steeringMode = "one-at-a-time";
    followUpMode = "one-at-a-time";
    enableSkillCommands = true;
    terminal = {
      showImages = true;
      clearOnShrink = false;
    };
    packages =
      lib.optional cfg.enableMcp "${extensionRoot}/pi-mcp-adapter"
      ++ [
        "${extensionRoot}/@gotgenes/pi-permission-system"
        "${extensionRoot}/@mzwing/pi-permission-auto-review"
        "${extensionRoot}/pi-web-access"
        "${extensionRoot}/pi-subagents"
        "${extensionRoot}/@narumitw/pi-goal"
        "${extensionRoot}/pi-vim"
        "${extensionRoot}/pi-claude-code-ui"
        "${extensionRoot}/@juicesharp/rpiv-ask-user-question"
        "${extensionRoot}/@narumitw/pi-worktree"
        "${extensionRoot}/@narumitw/pi-stamp"
      ]
      ++ lib.optional cfg.enableProcesses "${extensionRoot}/@aliou/pi-processes";
    # Replace the old discovery lists as well as the old npm package list.
    extensions =
      lib.optional cfg.enableProcesses "${pkgs.mine.pi-extensions}/lib/pi-extensions/processes-status.js"
      ++ lib.optional cfg.enableNotifications "${pkgs.mine.pi-extensions}/lib/pi-extensions/desktop-notify.js";
    skills = [ (toString skills) ];
    subagents = {
      defaultProvider = "openai-codex";
      disableBuiltins = true;
      defaultExtensions = permissionExtensions;
      modelScope = {
        enforce = true;
        strict = true;
        allow = [ "openai-codex/*" ];
      };
      # Explicit role extensions replace defaults rather than extending them.
      agentOverrides.researcher.extensions = permissionExtensions ++ [
        "${extensionRoot}/pi-web-access/index.js"
      ];
    };
  };
  managedConfig = json.generate "pi-managed-settings.json" (
    managedSettings
    // lib.optionalAttrs config.mine.nixvim.enable {
      externalEditor = "${config.programs.nixvim.build.package}/bin/nvim";
    }
  );
  # This extension reads/writes ~/.pi/settings.json rather than Pi's agent
  # settings. Keep it writable for /cc-tools, /cc-theme and /cc-spinner.
  managedUiConfig = json.generate "pi-managed-ui-settings.json" {
    toolBackground = "border";
    groupToolCalls = true;
    thinkingMode = "live";
    liveToolPreview = true;
    liveToolPreviewLines = 5;
    bashCommandPreviewLines = 8;
    # Local display-only patch in packages/pi-extensions; keep settled results
    # readable without expanding every tool call in the transcript.
    completedToolPreview = true;
    outputPreviewFullLines = 8;
    outputPreviewHeadLines = 3;
    outputPreviewTailLines = 3;
    failurePreviewTailLines = 12;
    bashAlwaysShowCommand = true;
    diffCollapsedLines = 16;
    themeAdaptive = true;
    extraToolOutputExpanded = false;
  };
  managedStampConfig = json.generate "pi-managed-stamp-settings.json" {
    hourCycle = "24h";
    showSeconds = true;
    timeZone = "local";
    responseTiming = "duration";
    assistantMetadata = "off";
    toolStamps = false;
  };
  managedWorktreeConfig = json.generate "pi-managed-worktree-settings.json" {
    worktreeRoot = "~/worktrees";
  };
  managedProcessesConfig = json.generate "pi-managed-processes-settings.json" {
    # The read-only companion shows only live jobs; /ps retains all history.
    widget.showStatusWidget = false;
  };
  agents = import ./roles.nix;
in
{
  options.mine.pi = lib.mine.mkEnable config {
    tags = [
      "tui"
      "develop"
      "cli-tools"
      "ai"
    ];
    hostContext = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Host instructions for Pi.";
    };
    model = mkOption {
      type = types.str;
      default = "gpt-6-astra";
      description = "Default model on the OpenAI subscription provider.";
    };
    proxyUrl = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Default proxy for Pi and its tools.";
    };
    noProxy = mkOption {
      type = types.listOf types.str;
      default = [
        "localhost"
        "127.0.0.1"
        "::1"
      ];
      description = "Hosts reached without the proxy.";
    };
    enableMcp = mkOption {
      type = types.bool;
      default = true;
      description = "Load the pinned adapter and shared MCP servers.";
    };
    enableNotifications = mkOption {
      type = types.bool;
      default =
        lib.mine.listContainsList config.mine.tags.include [ "gui" ]
        && !lib.mine.listContainsList config.mine.tags.exclude [ "gui" ];
      description = "Notify the desktop when an interactive Pi response settles; disabled by default without the gui tag.";
    };
    enableProcesses = mkOption {
      type = types.bool;
      default = true;
      description = "Load background process management.";
    };
    package = mkOption {
      type = types.package;
      readOnly = true;
      default = package;
      description = "Configured Pi launcher.";
    };
    settingsFile = mkOption {
      type = types.path;
      readOnly = true;
      default = managedConfig;
      description = "Declarative settings used by activation and isolated verification.";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ package ];
    home.shellAliases.h = "pi";

    # Pi writes settings interactively. Preserve unmanaged preferences, replace
    # managed top-level sections, and never merge back a removed npm package.
    home.activation.piWritableConfig = config.lib.dag.entryAfter [ "writeBoundary" ] ''
      run ${pkgs.python3}/bin/python ${./merge-settings.py} \
        ${managedConfig} ${lib.escapeShellArg "${config.home.homeDirectory}/.pi/agent/settings.json"}
      run ${pkgs.python3}/bin/python ${./merge-settings.py} \
        ${managedUiConfig} ${lib.escapeShellArg "${config.home.homeDirectory}/.pi/settings.json"}
      run ${pkgs.python3}/bin/python ${./merge-settings.py} \
        ${managedStampConfig} ${lib.escapeShellArg "${config.home.homeDirectory}/.pi/agent/pi-stamp.json"}
      run ${pkgs.python3}/bin/python ${./merge-settings.py} \
        ${managedWorktreeConfig} ${lib.escapeShellArg "${config.home.homeDirectory}/.pi/agent/pi-worktree.json"}
      run ${pkgs.python3}/bin/python ${./merge-settings.py} \
        ${./permissions.json} ${lib.escapeShellArg "${config.home.homeDirectory}/.pi/agent/extensions/pi-permission-system/config.json"}
      run ${pkgs.python3}/bin/python ${./merge-settings.py} \
        ${./permission-review.json} ${lib.escapeShellArg "${config.home.homeDirectory}/.pi/agent/extensions/pi-permission-auto-review/config.json"}
      ${lib.optionalString cfg.enableProcesses ''
        run ${pkgs.python3}/bin/python ${./merge-settings.py} \
          ${managedProcessesConfig} ${lib.escapeShellArg "${config.home.homeDirectory}/.pi/agent/extensions/processes.json"}
      ''}
    '';

    home.file = {
      ".pi/agent/AGENTS.md" = mkIf (cfg.hostContext != null) { text = cfg.hostContext; };
      ".pi/agent/APPEND_SYSTEM.md".text =
        builtins.readFile ./instructions.md
        + lib.optionalString (cfg.enableMcp && config.mine.nixvim.enable) ''

          Treat Neovim configuration changes (Nix modules, plugins, keymaps, and
          startup behavior) as repository work: edit and validate the configuration
          without connecting to a running editor unless the user requests live
          inspection or testing.
          When the user asks to interact with a running Neovim session (inspect
          buffers, edit in the editor, or open a tour), discover the nvim MCP tools
          and connect to that editor. When DEV_NVIM_SOCKET is set, it identifies the
          editor paired with this dev workspace; use that connection. If it is
          unavailable, report that the workspace editor needs restarting.
          Otherwise match the instance to the current project and ask if multiple
          instances still match. Read editor state before acting.
          Use buffer edits for open files so unsaved changes and undo history are
          preserved. Save only as required by the task, then check diagnostics.
          For requested code tours or walkthroughs in Neovim, use the shared
          tour skill to author and open the walkthrough in that same editor.
        '';
      ".pi/agent/mcp.json".source = json.generate "pi-mcp.json" {
        settings = {
          hostConfigDiscovery = "off";
          requestTimeoutMs = 60000;
          toolResultRendering = "compact";
        };
        mcpServers = if cfg.enableMcp then mcpServers else { };
      };
      ".pi/agent/web-search.json".source = json.generate "pi-web-search.json" {
        provider = "openai";
        openaiSearchProviders = [ "openai-codex" ];
        webSearch.allowedProviders = [ "openai" ];
        workflow = "none";
        allowBrowserCookies = false;
        fetchRouting = {
          providers = [ "http" ];
          allowRemoteHostedProviders = false;
        };
      };
      ".pi/agent/extensions/subagent/config.json".source = json.generate "pi-subagents.json" {
        toolDescriptionMode = "compact";
        inlineToolDisplay = "summary";
        parallel = {
          maxTasks = 4;
          concurrency = 2;
        };
        maxSubagentDepth = 1;
        worktreeProvider = "native";
        scheduledRuns.enabled = false;
      };
      ".pi/agent/keybindings.json".source = json.generate "pi-keybindings.json" {
        "tui.input.newLine" = [
          "shift+enter"
          "ctrl+j"
        ];
        "app.model.select" = [ "ctrl+l" ];
        "app.session.tree" = [ "ctrl+alt+t" ];
        "app.session.resume" = [ "ctrl+alt+r" ];
      };
    }
    // lib.mapAttrs' (
      name: text: lib.nameValuePair ".pi/agent/agents/${name}.md" { inherit text; }
    ) agents;
  };
}
