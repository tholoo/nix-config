{
  lib,
  python3,
  sinkDirectory ? null,
  writeShellApplication,
}:
writeShellApplication {
  name = "codex-title";
  text = ''
    export CODEX_TITLE_COMMAND="$0"
    ${lib.optionalString (sinkDirectory != null) ''
      export CODEX_TITLE_SINK_DIR=${lib.escapeShellArg (toString sinkDirectory)}
    ''}
    exec ${python3}/bin/python3 ${./codex_title.py} "$@"
  '';

  meta = {
    description = "Shared Codex session-title registry";
    license = lib.licenses.mit;
    mainProgram = "codex-title";
    platforms = lib.platforms.unix;
  };
}
