{
  inputs,
  lib,
  pkgs,
}:
let
  agentDeck = inputs.zellij-agent-deck.packages.${pkgs.stdenv.hostPlatform.system}.default;

  codexNotify = pkgs.writeShellApplication {
    name = "codex-notify";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
      pkgs.libnotify
      pkgs.dunst
    ];
    text = builtins.readFile ../home/apps/tui/codex/notify.sh;
  };

  codexBoardPython = pkgs.python3.withPackages (pythonPackages: [
    pythonPackages.pyserial
  ]);
  codexBoardSource = pkgs.writeText "codex-board.py" (
    builtins.readFile ../../breadboard/host/codex_board.py
  );
  codexBoard = pkgs.writeShellApplication {
    name = "codex-board";
    text = ''
      export CODEX_BOARD_COMMAND="$0"
      exec ${codexBoardPython}/bin/python3 ${codexBoardSource} "$@"
    '';
  };

  managedDir = pkgs.linkFarm "codex-managed-hooks" [
    {
      name = "agent-deck";
      path = lib.getExe agentDeck;
    }
    {
      name = "agent-deck-codex";
      path = "${agentDeck}/bin/zellij-agent-deck-codex";
    }
  ];

  agentDeckHook = {
    type = "command";
    command = "${managedDir}/agent-deck hook";
    timeout = 4;
  };

  deckRequirements = inputs.zellij-agent-deck.lib.mkCodexRequirements {
    agentDeckCommand = "${managedDir}/agent-deck";
    resurrectionCommand = "${managedDir}/agent-deck-codex";
    managedDir = "${managedDir}";
  };

  deckHooks = deckRequirements.hooks // {
    PermissionRequest = [
      {
        # Keep lifecycle tracking here, but leave notifications to
        # tui.notifications after auto-review has had a chance to decide.
        hooks = [ agentDeckHook ];
      }
    ];
  };

  dashboardEvents = [
    "SessionStart"
    "SessionEnd"
    "UserPromptSubmit"
    "PreToolUse"
    "PostToolUse"
    "PermissionRequest"
    "SubagentStart"
    "SubagentStop"
    "Stop"
  ];
  dashboardHooks = lib.genAttrs dashboardEvents (event: [
    {
      hooks = [
        (
          {
            type = "command";
            command = "${lib.getExe codexBoard} hook";
            timeout = 3;
          }
          // lib.optionalAttrs (event == "UserPromptSubmit") {
            additionalContextLimit = 160;
          }
        )
      ];
    }
  ]);

  mergedHooks = deckHooks // lib.mapAttrs (
    event: groups: (deckHooks.${event} or [ ]) ++ groups
  ) dashboardHooks;
in
{
  boardPackage = codexBoard;
  notifyCommand = lib.getExe codexNotify;

  requirements = deckRequirements // {
    hooks = mergedHooks;
  };
}
