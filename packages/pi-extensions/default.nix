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
  npmDepsHash = "sha256-IKD3ao75at1gMHpYCJzFdXrgM5k8XZOr0PECu1UYqVI=";
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
    python compile.py node_modules ${lib.getExe esbuild}
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
    mkdir -p "$PI_CODING_AGENT_DIR"
    for smoke in renderer spinner markdown; do
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
    runHook postInstall
  '';
  meta = {
    description = "Locked Pi extensions for tools, agents, goals, editing, UI, questions, worktrees and timestamps";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
