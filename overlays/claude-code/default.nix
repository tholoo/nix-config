{ ... }:
final: prev: {
  claude-code = prev.claude-code.overrideAttrs (oldAttrs: {
    nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ final.makeWrapper ];

    postPatch =
      (oldAttrs.postPatch or "")
      + ''
        # Increase API maxRetries: 2 -> 6
        substituteInPlace cli.js \
          --replace-fail 'this.maxRetries=Y.maxRetries??2' 'this.maxRetries=Y.maxRetries??6'

        # Tune SSE reconnect for unstable connections:
        #   FUY  (initial delay):    1000ms -> 300ms   (retry faster)
        #   UUY  (max delay):       30000ms -> 8000ms  (lower backoff cap)
        #   QUY  (total budget):   600000ms -> 1200000ms (20min instead of 10min)
        #   dUY  (liveness timeout): 45000ms -> 90000ms (tolerate longer gaps)
        substituteInPlace cli.js \
          --replace-fail 'FUY=1000,UUY=30000,QUY=600000,dUY=45000' \
                         'FUY=300,UUY=8000,QUY=1200000,dUY=90000'

        # Increase default stream idle timeout: 90s -> 180s
        substituteInPlace cli.js \
          --replace-fail 'CLAUDE_STREAM_IDLE_TIMEOUT_MS||"",10)||90000' \
                         'CLAUDE_STREAM_IDLE_TIMEOUT_MS||"",10)||180000'
      '';

    postInstall =
      (oldAttrs.postInstall or "")
      + ''
        # Read proxyUrl from settings and export as env vars for claude only
        wrapProgram $out/bin/claude \
          --run '
            _cfg="''${HOME}/.claude"
            _proxy=""
            for _f in "$_cfg/settings.local.json" "$_cfg/settings.json"; do
              if [ -z "$_proxy" ] && [ -f "$_f" ]; then
                _proxy=$(${final.jq}/bin/jq -r ".proxyUrl // empty" "$_f" 2>/dev/null)
              fi
            done
            if [ -n "$_proxy" ]; then
              export HTTPS_PROXY="$_proxy"
              export HTTP_PROXY="$_proxy"
              export ALL_PROXY="$_proxy"
            fi
          '
      '';
  });
}
