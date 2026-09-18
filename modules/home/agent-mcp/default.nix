{
  inputs,
  config,
  pkgs,
  lib,
  ...
}:
let
  enabled =
    (config.mine.codex.enable && config.mine.codex.enableSharedMcp)
    || (config.mine.pi.enable && config.mine.pi.enableMcp);
  npx = "${pkgs.nodejs}/bin/npx";
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
      export DOKPLOY_URL=${lib.escapeShellArg config.mine.agent-mcp.dokployUrl}
      export DOKPLOY_TOOL_PRESET="deploy"
      export DOKPLOY_REDACT_ENV="true"

      exec ${npx} -y @dokploy/mcp@0.30.2
    '';
  };

in
{
  options.mine.agent-mcp.dokployUrl = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = "Deployment service endpoint; credentials come from agenix at runtime.";
  };
  config = lib.mkIf enabled {
    age.secrets.dokploy-api-key = lib.mkIf (config.mine.agent-mcp.dokployUrl != null) {
      file = inputs.self + /secrets/dokploy/dokploy-api-key.age;
    };
    programs.mcp = {
      enable = true;
      servers = {
        context7.command = lib.getExe pkgs.context7-mcp;

        playwright = {
          command = lib.getExe pkgs.mine.agent-browser;
        };

        dokploy = lib.mkIf (config.mine.agent-mcp.dokployUrl != null) {
          command = lib.getExe dokployMcp;
          env_vars = [ "XDG_RUNTIME_DIR" ];
          startup_timeout_sec = 60;
          tool_timeout_sec = 300;
          default_tools_approval_mode = "writes";
        };
        zen-browser = lib.mkIf (config.mine.firefox.enable && config.mine.firefox.enableMcp) {
          command = lib.getExe pkgs.mine.zen-mcp;
          env.ZEN_DEBUG_PORT = "9222";
        };
      };
    };

  };
}
