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
    types
    ;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "pi";

  jsonFormat = pkgs.formats.json { };
  llmAgents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
  pi = llmAgents.pi.overrideAttrs (oldAttrs: {
    postInstall = (oldAttrs.postInstall or "") + ''
      substituteInPlace "$out/lib/node_modules/@mariozechner/pi-coding-agent/node_modules/@mariozechner/pi-tui/dist/tui.js" \
        --replace-fail 'buffer += "\x1b[2J\x1b[H\x1b[3J"; // Clear screen, home, then clear scrollback' \
                       'buffer += "\x1b[2J\x1b[H"; // Clear screen and home without clearing scrollback'

      substituteInPlace "$out/lib/node_modules/@mariozechner/pi-coding-agent/node_modules/@mariozechner/pi-tui/dist/terminal.js" \
        --replace-fail '        this.queryAndEnableKittyProtocol();' \
                       '        this.setupStdinBuffer(); process.stdin.on("data", this.stdinDataHandler);'

      substituteInPlace "$out/bin/pi" \
        --replace-fail "export PI_TELEMETRY='0'" \
                       "export PI_TELEMETRY='0'
      export PANDOC_PATH='${lib.getExe pkgs.pandoc}'
      export PANDOC_PDF_ENGINE='${lib.getExe' pkgs.texliveFull "xelatex"}'
      export PUPPETEER_EXECUTABLE_PATH='${lib.getExe pkgs.chromium}'
      export CHROME_PATH='${lib.getExe pkgs.chromium}'
      export MERMAID_CLI_PATH='${lib.getExe' pkgs.mermaid-cli "mmdc"}'"
    '';
  });

  piNpm = pkgs.writeShellScriptBin "pi-npm" ''
    export PATH="${
      lib.makeBinPath [
        pkgs.nodejs
        pkgs.bash
        pkgs.coreutils
      ]
    }:$PATH"
    export npm_config_fetch_retries="''${npm_config_fetch_retries:-3}"
    export npm_config_fetch_retry_mintimeout="''${npm_config_fetch_retry_mintimeout:-2000}"
    export npm_config_fetch_retry_maxtimeout="''${npm_config_fetch_retry_maxtimeout:-30000}"
    export npm_config_fetch_timeout="''${npm_config_fetch_timeout:-60000}"
    exec ${pkgs.nodejs}/bin/npm --prefix "$HOME/.pi/agent/npm" "$@"
  '';

  npx = "${pkgs.nodejs}/bin/npx";
  npxPath = lib.makeBinPath [
    pkgs.nodejs
    pkgs.bash
    pkgs.coreutils
  ];

  defaultPackages = [
    "npm:pi-wierd-statusline"
    "npm:pi-better-openai"
    "npm:pi-model-cycler"
    "npm:pi-subagents"
    "npm:pi-mcp-adapter"
    "npm:pi-web-access"
    "npm:pi-lens"
    "npm:pi-markdown-preview"
    "npm:pi-permission-system"
    "npm:taskplane"
    "npm:@aliou/pi-processes"
    "npm:@juicesharp/rpiv-ask-user-question"
    "npm:pi-btw"
    "npm:@pi-unipi/notify"
    "npm:@llblab/pi-telegram"
    "npm:pi-show"
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
      description = "Host-specific context for Pi (rendered as global AGENTS.md).";
    };

    enableUsageTools = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to install Pi usage/session analysis tools from llm-agents.nix.";
    };

    enableLSPs = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to install LSP, linter, and formatter binaries on PATH for Pi packages such as pi-lens.";
    };

    enableMcp = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to configure pi-mcp-adapter with shared MCP servers.";
    };

    enableMemctx = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to enable the pi-memctx package by default.";
    };

    enableCodexDelegation = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to enable the pi-codex package for nested Codex delegation.";
    };

    packages = mkOption {
      type = types.listOf types.str;
      default = defaultPackages;
      description = "Pi package specs to load from ~/.pi/agent/settings.json.";
    };

    extraPackages = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Additional Pi package specs to append to the default package list.";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [
      pi
      piNpm
      pkgs.chromium
      pkgs.mermaid-cli
      pkgs.pandoc
      pkgs.texliveFull
    ]
    ++ lib.optionals cfg.enableLSPs (
      with pkgs;
      [
        bash-language-server
        basedpyright
        clang-tools
        gopls
        jdt-language-server
        lua-language-server
        nil
        nixd
        ruff
        typescript-language-server
        vscode-langservers-extracted
        yaml-language-server
      ]
    )
    ++ lib.optionals cfg.enableUsageTools [
      llmAgents.ccusage-pi
      llmAgents.agentsview
    ];

    home.sessionVariables = {
      PI_SKIP_VERSION_CHECK = "1";
      PANDOC_PATH = lib.getExe pkgs.pandoc;
      PANDOC_PDF_ENGINE = lib.getExe' pkgs.texliveFull "xelatex";
      PUPPETEER_EXECUTABLE_PATH = lib.getExe pkgs.chromium;
      CHROME_PATH = lib.getExe pkgs.chromium;
      MERMAID_CLI_PATH = lib.getExe' pkgs.mermaid-cli "mmdc";
    };

    # pi-wierd-statusline has no persisted config/env for these defaults.
    # Disable the cost segment and its fixed editor compositor, which enters
    # alternate screen and prevents Zellij pane scrollback from working.
    home.activation.piExtensionPatches = config.lib.dag.entryAfter [ "writeBoundary" ] ''
      statusline="$HOME/.pi/agent/npm/lib/node_modules/pi-wierd-statusline/index.ts"
      if [ -f "$statusline" ]; then
        ${pkgs.gnused}/bin/sed -i '0,/if (cost > 0) {/s//if (false \&\& cost > 0) {/' "$statusline"
        ${pkgs.gnused}/bin/sed -i '0,/let fixedEditorEnabled = true;/s//let fixedEditorEnabled = false;/' "$statusline"
      fi
    '';

    home.file = {
      ".pi/agent/settings.json".source = jsonFormat.generate "pi-settings.json" {
        theme = "dark";
        quietStartup = false;
        collapseChangelog = true;
        enableInstallTelemetry = false;
        defaultThinkingLevel = "high";
        hideThinkingBlock = false;

        doubleEscapeAction = "tree";
        treeFilterMode = "default";
        editorPaddingX = 1;
        autocompleteMaxVisible = 10;
        showHardwareCursor = true;

        compaction = {
          enabled = true;
          reserveTokens = 16384;
          keepRecentTokens = 20000;
        };

        branchSummary = {
          reserveTokens = 16384;
          skipPrompt = false;
        };

        retry = {
          enabled = true;
          maxRetries = 3;
          baseDelayMs = 2000;
          provider = {
            timeoutMs = 3600000;
            maxRetryDelayMs = 60000;
          };
        };

        steeringMode = "one-at-a-time";
        followUpMode = "one-at-a-time";

        terminal = {
          showImages = true;
          imageWidthCells = 60;
          clearOnShrink = false;
        };

        images = {
          autoResize = true;
          blockImages = false;
        };

        npmCommand = [ "${piNpm}/bin/pi-npm" ];
        packages =
          cfg.packages
          ++ cfg.extraPackages
          ++ lib.optional cfg.enableMemctx "npm:pi-memctx"
          ++ lib.optional cfg.enableCodexDelegation "npm:pi-codex";
        enableSkillCommands = true;
      };

      ".pi/agent/keybindings.json".source = jsonFormat.generate "pi-keybindings.json" {
        "tui.input.newLine" = [
          "shift+enter"
          "ctrl+j"
        ];
        "app.model.select" = [ "ctrl+l" ];
        "app.model.cycleForward" = [ "ctrl+p" ];
        "app.model.cycleBackward" = [ "ctrl+shift+p" ];
        "app.session.tree" = [ "ctrl+alt+t" ];
        "app.session.resume" = [ "ctrl+alt+r" ];
      };

      ".pi/agent/extensions/pi-better-openai.json".source = jsonFormat.generate "pi-better-openai.json" {
        persistState = false;
        footer.mode = "off";
      };

      ".pi/agent/mcp.json" = mkIf cfg.enableMcp {
        source = jsonFormat.generate "pi-mcp.json" {
          settings = {
            toolPrefix = "mcp";
            requestTimeoutMs = 30000;
            maxRetries = 5;
          };

          mcpServers = {
            context7 = {
              command = npx;
              args = [
                "-y"
                "@upstash/context7-mcp"
              ];
              transport = "stdio";
              lifecycle = "lazy";
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
              transport = "stdio";
              lifecycle = "lazy";
              env = {
                PATH = npxPath;
                PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
                PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "true";
              };
            };
          };
        };
      };

      ".pi/agent/pi-permissions.jsonc".source = jsonFormat.generate "pi-permissions.jsonc" {
        defaultPolicy = {
          tools = "ask";
          bash = "ask";
          mcp = "ask";
          skills = "ask";
          special = "ask";
        };

        tools = {
          read = "allow";
          grep = "allow";
          find = "allow";
          ls = "allow";
          write = "ask";
          edit = "ask";
          bash = "ask";
          mcp = "ask";
          task = "ask";
        };

        bash = {
          "git status" = "allow";
          "git diff" = "allow";
          "git diff *" = "allow";
          "git log" = "allow";
          "git log *" = "allow";
          "git show" = "allow";
          "git show *" = "allow";
          "pwd" = "allow";
          "ls" = "allow";
          "ls *" = "allow";
          "find" = "allow";
          "find *" = "allow";
          "rg *" = "allow";
          "fd" = "allow";
          "fd *" = "allow";
          "cat" = "allow";
          "cat *" = "allow";
          "file *" = "allow";
          "realpath *" = "allow";
          "stat *" = "allow";
          "tree" = "allow";
          "tree *" = "allow";
          "wc *" = "allow";
          "which *" = "allow";
          "command -v *" = "allow";
          "rm *" = "ask";
          "rm -rf *" = "ask";
          "nixos-rebuild *" = "ask";
          "deploy *" = "ask";
        };

        skills = {
          "*" = "allow";
        };

        mcp = {
          mcp_status = "allow";
          mcp_list = "allow";
          mcp_search = "allow";
          mcp_describe = "allow";
          mcp_connect = "ask";
        };

        special = {
          external_directory = "allow";
          doom_loop = "deny";
        };
      };

      ".pi/agent/extensions/pi-permission-system/config.json".source =
        jsonFormat.generate "pi-permission-system-config.json"
          {
            debugLog = false;
            permissionReviewLog = true;
            yoloMode = false;
          };

      ".pi/agent/AGENTS.md" = mkIf (cfg.hostContext != null) {
        text = cfg.hostContext;
      };

    };
  };
}
