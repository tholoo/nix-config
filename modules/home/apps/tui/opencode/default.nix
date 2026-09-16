{
  inputs,
  pkgs,
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf mkOption types;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.opencode;
  opencode = pkgs.mine.opencode-v2;
  noProxy = lib.concatStringsSep "," cfg.noProxy;
  # Agenix's Home Manager path uses a shell variable; OpenCode expands {env:...}.
  experientialKeyPath =
    lib.replaceStrings [ "\${XDG_RUNTIME_DIR}" ] [ "{env:XDG_RUNTIME_DIR}" ]
      config.age.secrets.experiential-api-key.path;

  mkGatewayModel =
    {
      name,
      context,
      reasoningField ? "reasoning_content",
      images ? false,
    }:
    {
      inherit name;
      capabilities = {
        tools = true;
        input = [ "text" ] ++ lib.optional images "image";
        output = [ "text" ];
      };
      # Use conservative budgets across the gateway's fallback providers.
      limit = {
        inherit context;
        output = 32768;
      };
    }
    // lib.optionalAttrs (reasoningField != null) {
      compatibility.reasoningField = reasoningField;
    };

  runtimePackage = pkgs.symlinkJoin {
    name = "${opencode.name}-runtime";
    paths = [ opencode ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      rm "$out/bin/opencode"
      wrapper_args=(
        --set-default NO_PROXY ${lib.escapeShellArg noProxy}
        --set-default no_proxy ${lib.escapeShellArg noProxy}
        --set-default EDITOR hx
      )
      ${lib.optionalString (cfg.proxyUrl != null) ''
        wrapper_args+=(
          --set-default HTTP_PROXY ${lib.escapeShellArg cfg.proxyUrl}
          --set-default HTTPS_PROXY ${lib.escapeShellArg cfg.proxyUrl}
          --set-default http_proxy ${lib.escapeShellArg cfg.proxyUrl}
          --set-default https_proxy ${lib.escapeShellArg cfg.proxyUrl}
        )
      ''}
      makeWrapper ${lib.getExe opencode} "$out/bin/opencode" "''${wrapper_args[@]}"
    '';
    meta.mainProgram = "opencode";
  };
in
{
  options.mine.opencode = mkEnable config {
    tags = [ "opencode" ];

    proxyUrl = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Default HTTP proxy for OpenCode; existing environment variables take precedence.";
    };

    noProxy = mkOption {
      type = types.listOf types.str;
      default = [
        "localhost"
        "127.0.0.1"
        "::1"
      ];
      description = "Hosts that bypass OpenCode's proxy, including its local TUI server.";
    };
  };

  config = mkIf cfg.enable {
    age.secrets.experiential-api-key.file = inputs.self + /secrets/experiential/api-key.age;

    # Home Manager and Stylix still target V1's tui.json. Retain the generated
    # theme, but select it from V2's global CLI configuration instead.
    xdg.configFile."opencode/tui.json".enable = false;
    xdg.configFile."opencode/cli.json".source = (pkgs.formats.json { }).generate "opencode-cli.json" (
      {
        "$schema" = "https://opencode.ai/v2/cli.json";
        diffs = {
          source = "working";
          wrap = "word";
          tree = false;
          single = true;
          view = "unified";
        };
        terminal.copy = "select";
        attention = {
          enabled = true;
          notifications = true;
          sound = false;
        };
      }
      // lib.optionalAttrs (config.programs.opencode.tui ? theme) {
        theme.name = config.programs.opencode.tui.theme;
      }
    );

    programs.opencode = {
      enable = true;
      package = runtimePackage;
      settings = {
        # Updates are managed by the flake, not the application's installer.
        update = "disable";
        share = "manual";
        # Use a known shell path on NixOS for agent commands.
        shell = lib.getExe pkgs.bash;
        model = "experiential/deepseek-v4.1-flash";
        agents.title.disabled = true;
        providers.experiential = {
          name = "Experiential Labs";
          package = "@opencode/ai/providers/openai-compatible";
          settings = {
            baseURL = "https://api.experientiallabs.ai/v1";
            apiKey = "{file:${experientialKeyPath}}";
          };
          models = {
            "deepseek-v4.1-flash" =
              (mkGatewayModel {
                name = "DeepSeek V4.1 Flash";
                context = 1000000;
                images = true;
              })
              // {
                # Bun negotiates lossless WebSocket compression with the gateway.
                package = "@opencode/ai/providers/openai/responses";
                transport = "websocket";
                settings.store = false;
                # This route cannot return OpenAI's encrypted reasoning carrier.
                body.include = [ ];
              };
            "glm-5.3" = mkGatewayModel {
              name = "GLM 5.3";
              context = 1000000;
            };
            "glm-5.3-flash" = mkGatewayModel {
              name = "GLM 5.3 Flash";
              context = 1000000;
              images = true;
            };
            "gpt-5.6-luna" = mkGatewayModel {
              name = "GPT-5.6 Luna";
              context = 1000000;
              images = true;
              reasoningField = null;
            };
            "grok-4.6" = mkGatewayModel {
              name = "Grok 4.6";
              context = 500000;
              images = true;
              reasoningField = null;
            };
            "kimi-k3" = mkGatewayModel {
              name = "Kimi K3";
              context = 1000000;
              images = true;
            };
            "qwen3-coder-next" = mkGatewayModel {
              name = "Qwen3 Coder Next";
              context = 262144;
              reasoningField = null;
            };
          };
        };
      };
    };
  };
}
