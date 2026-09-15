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
  opencode = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode;
  noProxy = lib.concatStringsSep "," cfg.noProxy;
  # Agenix's Home Manager path uses a shell variable; OpenCode expands {env:...}.
  experientialKeyPath =
    lib.replaceStrings [ "\${XDG_RUNTIME_DIR}" ] [ "{env:XDG_RUNTIME_DIR}" ]
      config.age.secrets.experiential-api-key.path;

  mkGatewayModel =
    {
      name,
      context,
      reasoning ? true,
      images ? false,
    }:
    {
      inherit name reasoning;
      tool_call = true;
      modalities = {
        input = [ "text" ] ++ lib.optional images "image";
        output = [ "text" ];
      };
      # Use conservative budgets across the gateway's fallback providers.
      limit = {
        inherit context;
        output = 32768;
      };
    }
    // lib.optionalAttrs reasoning {
      interleaved.field = "reasoning_content";
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

    programs.opencode = {
      enable = true;
      package = runtimePackage;
      settings = {
        # Updates are managed by the flake, not the application's installer.
        autoupdate = false;
        share = "manual";
        # Use a known shell path on NixOS for agent commands.
        shell = lib.getExe pkgs.bash;
        model = "experiential/deepseek-v4.1-flash";
        agent.title.disable = true;
        provider.experiential = {
          name = "Experiential Labs";
          npm = "@ai-sdk/openai-compatible";
          options = {
            baseURL = "https://api.experientiallabs.ai/v1";
            apiKey = "{file:${experientialKeyPath}}";
          };
          models = {
            "deepseek-v4.1-flash" = mkGatewayModel {
              name = "DeepSeek V4.1 Flash";
              context = 1000000;
              images = true;
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
            "gpt-5.6-luna" =
              (mkGatewayModel {
                name = "GPT-5.6 Luna";
                context = 1000000;
                images = true;
              })
              // {
                interleaved = false;
                temperature = false;
              };
            "kimi-k3" = mkGatewayModel {
              name = "Kimi K3";
              context = 1000000;
              images = true;
            };
            "qwen3-coder-next" = mkGatewayModel {
              name = "Qwen3 Coder Next";
              context = 262144;
              reasoning = false;
            };
          };
        };
      };
    };
  };
}
