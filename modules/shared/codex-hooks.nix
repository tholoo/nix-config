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
in
{
  notifyCommand = lib.getExe codexNotify;

  requirements = deckRequirements // {
    hooks = deckRequirements.hooks // {
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
