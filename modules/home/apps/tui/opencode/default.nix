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
    programs.opencode = {
      enable = true;
      package = runtimePackage;
      settings = {
        # Updates are managed by the flake, not the application's installer.
        autoupdate = false;
        share = "manual";
        # Use a known shell path on NixOS for agent commands.
        shell = lib.getExe pkgs.bash;
      };
    };
  };
}
