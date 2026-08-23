{ ... }:
let
  kbModel = "Qwen3.5-9B-UD-Q4_K_XL";
  kbModelFile = "${kbModel}.gguf";
in
{
  imports = [ ./internet.nix ];

  mine = {
    user = {
      name = "tholo";
      fullName = "Ali Mohammadzadeh";
      email = "ali0mhmz@gmail.com";
    };

    gui.enable = true;
    tui.enable = true;
    terminal.emulator = "cosmic-term";

    # Disabled until `pass` is initialized and OAuth tokens are stored at
    # work/gmail/vdirsyncer/{clientid,clientsecret} + ~/secrets/access_tokens.
    calendar.enable = false;

    # polybar wants X11; this host is on Hyprland (Wayland).
    polybar.enable = false;
    # wluma needs an ALS device + wlroots brightness control wired up.
    wluma.enable = false;
    # darkman needs geo coords (sunrise/sunset) configured.
    darkman.enable = false;

    claude-code.hostContext = ''
      # Host: glacier
      You are on **glacier**, a laptop (IdeaPad Slim 5, AMD CPU+GPU, x86_64).
      This is the primary mobile dev machine with full GUI + TUI suites.
    '';
    claude-code.proxyUrl = "http://127.0.0.1:10808";

    pi.hostContext = ''
      # Host: glacier
      You are on **glacier**, a laptop (IdeaPad Slim 5, AMD CPU+GPU, x86_64).
      This is the primary mobile dev machine with full GUI + TUI suites.
    '';

    # uv needs PyPI on first frdict launch — route through the local proxy
    # since direct PyPI is blocked here. Once ~/.cache/uv is warm, restarts
    # don't hit the network at all.
    frdict.proxy = "http://127.0.0.1:10808";
    glance.proxy = "http://127.0.0.1:10808";

  };

  programs.kb = {
    enable = true;
    profiles.tholos = {
      include = [ "**/*.md" ];
      exclude = [ "_assets/**" ];
      workflow = [
        "Input"
        "Materia"
        "Output"
      ];
      inboxRole = "Void";
    };
    retrieval = {
      forceCpu = false;
      gpuBackend = "vulkan";
      gpuPreloadLibrary = "/run/opengl-driver/lib/libvulkan.so.1";
    };
    inference = {
      url = "http://127.0.0.1:18080";
      model = kbModel;
      control = "ssh-powershell";
    };
    ssh = {
      host = "kb-windows";
      # The agenix Home Manager path contains a literal ${XDG_RUNTIME_DIR},
      # while kb passes this value directly to OpenSSH without shell expansion.
      configFile = "/run/user/1000/agenix/kb-windows-ssh-config";
      remoteScriptsDir = ''D:\KB\scripts'';
    };
    tunnel = {
      enable = true;
      localPort = 18080;
      remotePort = 18080;
    };
    windows = {
      enable = true;
      root = "D:\\KB";
      taskName = "KB-llama-server";
      downloadProxy = "http://127.0.0.1:2080";
      server = {
        model = "models\\${kbModelFile}";
        modelAlias = kbModel;
        port = 18080;
        arguments = [
          "--ctx-size"
          "16384"
          "--parallel"
          "1"
          "--n-gpu-layers"
          "10"
          "--threads"
          "6"
          "--threads-batch"
          "12"
          "--batch-size"
          "512"
          "--ubatch-size"
          "256"
          "--cache-type-k"
          "q8_0"
          "--cache-type-v"
          "f16"
          "--flash-attn"
          "off"
          "--jinja"
          "--no-webui"
        ];
      };
      artifacts = [
        {
          name = "llama-runtime";
          url = "https://github.com/ggml-org/llama.cpp/releases/download/b10549/llama-b10549-bin-win-cuda-12.4-x64.zip";
          sha256 = "2e980ae28b40c92c9c30bdbcf3f28064b40104472e213c52edbeb89b920d65fe";
          destination = "cache\\downloads\\llama-b10549-bin-win-cuda-12.4-x64.zip";
          extractTo = "bin";
          flatten = true;
        }
        {
          name = "cuda-runtime";
          url = "https://github.com/ggml-org/llama.cpp/releases/download/b10549/cudart-llama-bin-win-cuda-12.4-x64.zip";
          sha256 = "8c79a9b226de4b3cacfd1f83d24f962d0773be79f1e7b75c6af4ded7e32ae1d6";
          destination = "cache\\downloads\\cudart-llama-bin-win-cuda-12.4-x64.zip";
          extractTo = "bin";
          flatten = true;
        }
        {
          name = "model";
          url = "https://huggingface.co/unsloth/Qwen3.5-9B-GGUF/resolve/main/${kbModelFile}";
          sha256 = "6f5d30666c2d8ae16a306e616d95341dcf3cc46810df84d7e6f5a7d1e4c1b293";
          destination = "models\\${kbModelFile}";
        }
      ];
    };
  };
}
