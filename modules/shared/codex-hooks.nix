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

  boardTitleSink = pkgs.writeShellApplication {
    name = "codex-board-title-sink";
    text = ''
      exec ${lib.getExe codexBoard} title "$@"
    '';
  };

  agentDeckTitleSink = pkgs.writeShellApplication {
    name = "agent-deck-title-sink";
    text = ''
      if [ "$#" -ne 4 ] || [ "$1" != "--session" ] || [ "$3" != "--title" ]; then
        echo "usage: agent-deck-title-sink --session SESSION --title TITLE" >&2
        exit 2
      fi
      exec ${lib.getExe agentDeck} title "codex:$2" "$4" >/dev/null
    '';
  };

  titleSinks = pkgs.linkFarm "codex-title-sinks" [
    {
      name = "10-codex-board";
      path = lib.getExe boardTitleSink;
    }
    {
      name = "20-agent-deck";
      path = lib.getExe agentDeckTitleSink;
    }
  ];

  codexTitle = pkgs.callPackage ../../packages/codex-title {
    sinkDirectory = titleSinks;
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
        {
          type = "command";
          command = "${lib.getExe codexBoard} hook";
          timeout = 3;
        }
      ];
    }
  ]);

  deckAndDashboardHooks = deckHooks // lib.mapAttrs (
    event: groups: (deckHooks.${event} or [ ]) ++ groups
  ) dashboardHooks;

  mergedHooks = deckAndDashboardHooks // {
    UserPromptSubmit = (deckAndDashboardHooks.UserPromptSubmit or [ ]) ++ [
      {
        hooks = [
          {
            type = "command";
            command = "${lib.getExe codexTitle} hook";
            timeout = 3;
            additionalContextLimit = 180;
          }
        ];
      }
    ];
    SessionEnd = (deckAndDashboardHooks.SessionEnd or [ ]) ++ [
      {
        hooks = [
          {
            type = "command";
            command = "${lib.getExe codexTitle} hook";
            timeout = 3;
          }
        ];
      }
    ];
  };
in
{
  boardPackage = codexBoard;
  titlePackage = codexTitle;
  notifyCommand = lib.getExe codexNotify;

  requirements = deckRequirements // {
    hooks = mergedHooks;
  };
}
