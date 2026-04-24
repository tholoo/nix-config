{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkIf
    mkOption
    types
    ;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.claude-code;
  name = "claude-code";

  jsonFormat = pkgs.formats.json { };
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
      description = "Host-specific context for Claude Code (rendered as a rule file).";
    };

    proxyUrl = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "socks5://127.0.0.1:1080";
      description = "Proxy URL for Claude Code API requests. Read by the overlay wrapper.";
    };
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      claude-monitor
    ];

    programs.claude-code = {
      enable = true;

      settings = {
        theme = "dark";
        includeCoAuthoredBy = false;
        effortLevel = "high";
      }
      // lib.optionalAttrs (cfg.proxyUrl != null) {
        proxyUrl = cfg.proxyUrl;
      }
      // {
        permissions = {
          defaultMode = "acceptEdits";
          allow = [
            # built-in tools
            "Edit"
            "Read"
            "Write"
            "Glob"
            "Grep"
            "WebFetch"
            "WebSearch"
            "Agent"

            # git
            "Bash(git *)"
            "Bash(gh *)"

            # nix
            "Bash(nix fmt:*)"
            "Bash(nix build:*)"
            "Bash(nix develop:*)"
            "Bash(nix run:*)"
            "Bash(nix flake *)"
            "Bash(nix eval:*)"
            "Bash(nix search:*)"
            "Bash(nix path-info:*)"
            "Bash(nix why-depends:*)"
            "Bash(nix log:*)"
            "Bash(nix-store *)"
            "Bash(nix hash:*)"
            "Bash(nixos-option:*)"
            "Bash(agenix *)"
            "Bash(home-manager generations:*)"

            # filesystem & search
            "Bash(ls:*)"
            "Bash(tree:*)"
            "Bash(find:*)"
            "Bash(fd:*)"
            "Bash(rg:*)"
            "Bash(cat:*)"
            "Bash(head:*)"
            "Bash(tail:*)"
            "Bash(wc:*)"
            "Bash(diff:*)"
            "Bash(file:*)"
            "Bash(stat:*)"
            "Bash(du:*)"
            "Bash(df:*)"
            "Bash(basename:*)"
            "Bash(dirname:*)"
            "Bash(pwd:*)"
            "Bash(realpath:*)"
            "Bash(readlink:*)"
            "Bash(mkdir:*)"
            "Bash(cp:*)"
            "Bash(mv:*)"
            "Bash(touch:*)"

            # text processing
            "Bash(grep:*)"
            "Bash(sed:*)"
            "Bash(awk:*)"
            "Bash(sort:*)"
            "Bash(uniq:*)"
            "Bash(tr:*)"
            "Bash(cut:*)"
            "Bash(jq:*)"
            "Bash(yq:*)"

            # system info
            "Bash(which:*)"
            "Bash(man:*)"
            "Bash(uname:*)"
            "Bash(hostname:*)"
            "Bash(echo:*)"
            "Bash(printf:*)"
            "Bash(env:*)"
            "Bash(printenv:*)"

            # process & service inspection
            "Bash(ps:*)"
            "Bash(pgrep:*)"
            "Bash(systemctl status:*)"
            "Bash(systemctl show:*)"
            "Bash(systemctl list-units:*)"
            "Bash(systemctl list-timers:*)"
            "Bash(systemctl is-active:*)"
            "Bash(systemctl is-enabled:*)"
            "Bash(systemctl cat:*)"
            "Bash(journalctl:*)"

            # network (read-only)
            "Bash(ip addr:*)"
            "Bash(ip route:*)"
            "Bash(ss:*)"
            "Bash(ping:*)"
            "Bash(curl:*)"
            "Bash(dig:*)"
            "Bash(host:*)"

            # cargo
            "Bash(cargo build:*)"
            "Bash(cargo check:*)"
            "Bash(cargo clippy:*)"
            "Bash(cargo fmt:*)"
            "Bash(cargo test:*)"
            "Bash(cargo run:*)"
            "Bash(cargo doc:*)"
            "Bash(cargo add:*)"
            "Bash(cargo remove:*)"
            "Bash(cargo update:*)"
            "Bash(cargo tree:*)"
            "Bash(cargo search:*)"
            "Bash(cargo bench:*)"
            "Bash(cargo clean:*)"
            "Bash(cargo metadata:*)"

            # go
            "Bash(go build:*)"
            "Bash(go test:*)"
            "Bash(go run:*)"
            "Bash(go fmt:*)"
            "Bash(go vet:*)"
            "Bash(go mod:*)"
            "Bash(go get:*)"
            "Bash(go generate:*)"
            "Bash(go doc:*)"
            "Bash(go env:*)"
            "Bash(go version:*)"
            "Bash(go list:*)"
            "Bash(go clean:*)"

            # python
            "Bash(python -c:*)"
            "Bash(python -m:*)"
            "Bash(python --version:*)"
            "Bash(python3 -c:*)"
            "Bash(python3 -m:*)"
            "Bash(python3 --version:*)"
            "Bash(pytest:*)"

            # uv
            "Bash(uv run:*)"
            "Bash(uv sync:*)"
            "Bash(uv add:*)"
            "Bash(uv remove:*)"
            "Bash(uv lock:*)"
            "Bash(uv init:*)"
            "Bash(uv venv:*)"
            "Bash(uv pip:*)"
            "Bash(uv tree:*)"
            "Bash(uv version:*)"
            "Bash(uvx:*)"

            # node/npm
            "Bash(npm install:*)"
            "Bash(npm ci:*)"
            "Bash(npm run:*)"
            "Bash(npm test:*)"
            "Bash(npm build:*)"
            "Bash(npm list:*)"
            "Bash(npm outdated:*)"
            "Bash(npm info:*)"
            "Bash(npm audit:*)"
            "Bash(npm init:*)"
            "Bash(npx:*)"
            "Bash(node -e:*)"
            "Bash(node -p:*)"
            "Bash(node --version:*)"

            # pip
            "Bash(pip install:*)"
            "Bash(pip list:*)"
            "Bash(pip show:*)"
            "Bash(pip freeze:*)"
            "Bash(pip check:*)"
          ];
          ask = [
            "Bash(nixos-rebuild *)"
            "Bash(deploy *)"
            "Bash(rm *)"
            "Bash(rm -rf:*)"
            "Read(./.env)"
          ];
        };

        hooks = {
          PostToolUse = [
            {
              matcher = "Edit|MultiEdit|Write";
              hooks = [
                {
                  type = "command";
                  command = ''
                    file=$(jq -r '.tool_input.file_path // empty' <<< "$CLAUDE_TOOL_INPUT")
                    [[ "$file" == *.nix ]] && nix fmt "$file" 2>/dev/null || true
                  '';
                }
              ];
            }
          ];
        };
      };

      mcpServers =
        let
          npx = "${pkgs.nodejs}/bin/npx";
          npxPath = lib.makeBinPath [
            pkgs.nodejs
            pkgs.bash
            pkgs.coreutils
          ];
        in
        {
          serena = {
            command = lib.getExe' pkgs.uv "uvx";
            args = [
              "--from"
              "git+https://github.com/oraios/serena"
              "serena"
              "start-mcp-server"
              "--open-web-dashboard"
              "False"
            ];
          };
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

      skills = {
        debug = ./debug-skill.md;
        grill = ./grill-skill.md;
      };

      rules = lib.optionalAttrs (cfg.hostContext != null) {
        host-context = cfg.hostContext;
      };
    };

    # Keybindings: shift+enter for newline, unbind alt+enter
    home.file.".claude/keybindings.json" = {
      source = jsonFormat.generate "claude-code-keybindings.json" {
        "$schema" = "https://www.schemastore.org/claude-code-keybindings.json";
        bindings = [
          {
            context = "Chat";
            bindings = {
              "shift+enter" = "chat:newline";
              "alt+enter" = null;
            };
          }
        ];
      };
    };
  };
}
