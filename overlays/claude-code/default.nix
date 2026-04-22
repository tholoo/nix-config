{ ... }:
final: prev: {
  claude-code = prev.claude-code.overrideAttrs (oldAttrs: {
    nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ final.makeWrapper ];

    postPatch =
      (oldAttrs.postPatch or "")
      + ''
        # Increase API maxRetries: 2 -> 999 (effectively unlimited)
        substituteInPlace cli.js \
          --replace-fail 'this.maxRetries=Y.maxRetries??2' 'this.maxRetries=Y.maxRetries??999'

        # Tune SSE reconnect for unstable connections:
        #   FUY  (initial delay):    1000ms -> 300ms       (retry faster)
        #   UUY  (max delay):       30000ms -> 8000ms      (lower backoff cap)
        #   QUY  (total budget):   600000ms -> 999999999ms (essentially infinite)
        #   dUY  (liveness timeout): 45000ms -> 600000ms   (10min tolerance)
        substituteInPlace cli.js \
          --replace-fail 'FUY=1000,UUY=30000,QUY=600000,dUY=45000' \
                         'FUY=300,UUY=8000,QUY=999999999,dUY=600000'
      '';

    postInstall =
      (oldAttrs.postInstall or "")
      + ''
        # Set stream idle timeout via env var (no need to patch JS)
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
