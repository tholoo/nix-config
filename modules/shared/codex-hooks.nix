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

  managedDir = pkgs.linkFarm "codex-managed-hooks" [
    {
      name = "agent-deck";
      path = lib.getExe agentDeck;
    }
    {
      name = "notify";
      path = lib.getExe codexNotify;
    }
  ];

  agentDeckHook = {
    type = "command";
    command = "${managedDir}/agent-deck hook";
    timeout = 4;
  };

  deckHooks = [
    {
      hooks = [ agentDeckHook ];
    }
  ];
in
{
  notifyCommand = lib.getExe codexNotify;

  requirements = {
    features.hooks = true;

    hooks = {
      managed_dir = "${managedDir}";

      SessionStart = deckHooks;
      SessionEnd = [
        {
          hooks = [
            (agentDeckHook // { timeout = 3; })
          ];
        }
      ];
      UserPromptSubmit = deckHooks;
      PreToolUse = deckHooks;
      Stop = deckHooks;
      SubagentStart = deckHooks;
      SubagentStop = deckHooks;

      PermissionRequest = [
        {
          hooks = [
            agentDeckHook
            {
              type = "command";
              command = "${managedDir}/notify";
              timeout = 10;
              statusMessage = "Sending approval notification";
            }
          ];
        }
      ];
    };
  };
}
