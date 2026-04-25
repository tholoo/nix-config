{ inputs, ... }:
final: _prev: {
  claude-code = inputs.claude-code-nix.packages.${final.system}.claude-code.overrideAttrs (oldAttrs: {
    nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ final.makeWrapper ];

    postInstall =
      (oldAttrs.postInstall or "")
      + ''
        # Set stream idle timeout via env var
        # and read proxyUrl from settings, exporting only if reachable
        wrapProgram $out/bin/claude \
          --set-default CLAUDE_STREAM_IDLE_TIMEOUT_MS 999999999 \
          --run '
            _cfg="''${HOME}/.claude"
            _proxy=""
            for _f in "$_cfg/settings.local.json" "$_cfg/settings.json"; do
              if [ -z "$_proxy" ] && [ -f "$_f" ]; then
                _proxy=$(${final.jq}/bin/jq -r ".proxyUrl // empty" "$_f" 2>/dev/null)
              fi
            done
            if [ -n "$_proxy" ]; then
              _host="''${_proxy##*://}"
              _port="''${_host##*:}"
              _host="''${_host%%:*}"
              if timeout 2 ${final.bash}/bin/bash -c "</dev/tcp/$_host/$_port" 2>/dev/null; then
                export HTTPS_PROXY="$_proxy"
                export HTTP_PROXY="$_proxy"
                export ALL_PROXY="$_proxy"
              else
                echo "error: proxy $_proxy is not reachable" >&2
                exit 1
              fi
            fi
          '
      '';
  });
}
