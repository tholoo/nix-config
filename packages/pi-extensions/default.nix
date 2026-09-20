{
  lib,
  buildNpmPackage,
  esbuild,
  python3,
  inputs,
  stdenv,
}:
buildNpmPackage {
  pname = "pi-extensions";
  version = "1.0.0";
  src = ./.;
  npmDepsHash = "sha256-jK+NPcnaTS5tpOWboe4S4B7TySNno4nlOWXQG7DSBoo=";
  npmFlags = [ "--legacy-peer-deps" ];
  npmInstallFlags = [ "--ignore-scripts" ];
  nativeBuildInputs = [
    esbuild
    python3
  ];
  buildPhase = ''
    runHook preBuild
    # Dependencies only exist after npm's configure hook. Patch before bundling;
    # fail on upstream drift rather than silently shipping the old renderer.
    patch --batch --fuzz=0 -d node_modules/pi-claude-code-ui -p1 < claude-ui-previews.patch
    # Builds on the completed-preview renderer above; keep process commands visible.
    patch --batch --fuzz=0 -d node_modules/pi-claude-code-ui -p1 < claude-ui-process-commands.patch
    patch --batch --fuzz=0 -d node_modules/pi-claude-code-ui -p1 < claude-ui-spinner.patch
    # Retain core/extension Markdown transforms through the custom UI wrappers.
    patch --batch --fuzz=0 -d node_modules/pi-claude-code-ui -p1 < claude-ui-markdown.patch
    cp output-preview.ts node_modules/pi-claude-code-ui/extensions/output-preview.ts
    # Delegate outside-workspace asks to the configured reviewer, not blanket allow.
    # Explicit path asks remain human-only; denies and failure fallback are unchanged.
    patch --batch --fuzz=0 -d node_modules/@gotgenes/pi-permission-system -p1 < permission-external-review.patch
    python compile.py node_modules ${lib.getExe esbuild}
    # Local read-only widget; pi-processes itself remains unpatched.
    esbuild processes-status.ts desktop-notify.ts paired-editor.ts --format=esm --platform=node --target=es2022 \
      --outdir=. --log-level=warning
    runHook postBuild
  '';
  doCheck = true;
  nativeCheckInputs = [ inputs.llm-agents.packages.${stdenv.hostPlatform.system}.pi ];
  checkPhase = ''
    runHook preCheck
    node --disable-warning=MODULE_TYPELESS_PACKAGE_JSON --test tests/output-preview.test.mjs
    # Real Pi renderer/SDK, isolated settings and synthetic results, no provider.
    export HOME="$TMPDIR/ui-test-home"
    export PI_CODING_AGENT_DIR="$HOME/.pi/agent"
    export PI_OFFLINE=1 PI_TELEMETRY=0
    export SHELL=${lib.escapeShellArg stdenv.shell}
    mkdir -p "$PI_CODING_AGENT_DIR"
    export PI_PERMISSION_TEST_CONFIG=${../../modules/home/apps/tui/pi/permissions.json}
    export PI_REVIEW_TEST_CONFIG=${../../modules/home/apps/tui/pi/permission-review.json}
    for smoke in renderer spinner markdown processes-status permissions desktop-notify paired-editor; do
      timeout 90 pi --mode json --no-session --no-extensions --no-skills --no-prompt-templates \
        --no-themes --no-context-files -e "./tests/$smoke-smoke.ts" </dev/null
      test -s "$HOME/$smoke-smoke-passed"
    done
    runHook postCheck
  '';
  # Pi supplies its own SDK aliases. Installing peer copies here gives
  # extensions a second runtime and breaks shared provider registration.
  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/pi-extensions
    cp -r node_modules $out/lib/pi-extensions/
    cp processes-status.js desktop-notify.js paired-editor.js $out/lib/pi-extensions/
    runHook postInstall
  '';
  meta = {
    description = "Locked Pi extensions for permissions, tools, agents, goals, editing, UI, questions, worktrees and timestamps";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
