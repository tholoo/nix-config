{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf mkOption types;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "llama-cpp";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "service"
      "ai"
      "automation"
      "server"
    ];

    host = mkOption {
      type = types.str;
      default = "0.0.0.0";
    };

    port = mkOption {
      type = types.port;
      default = 8090;
    };

    hfRepo = mkOption {
      type = types.str;
      default = "bartowski/Qwen2.5-3B-Instruct-GGUF";
    };

    hfFile = mkOption {
      type = types.str;
      default = "Qwen2.5-3B-Instruct-Q4_K_M.gguf";
    };

    contextSize = mkOption {
      type = types.int;
      default = 8192;
    };
  };

  config = mkIf cfg.enable {
    services.llama-cpp = {
      enable = true;
      inherit (cfg) host port;
      openFirewall = true;
      extraFlags = [
        "--hf-repo"
        cfg.hfRepo
        "--hf-file"
        cfg.hfFile
        "-c"
        (toString cfg.contextSize)
        "--jinja"
      ];
    };
  };
}
