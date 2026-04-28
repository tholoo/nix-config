{ ... }:
{
  mine = {
    user = {
      name = "tholo";
      fullName = "Ali Mohammadzadeh";
      email = "ali0mhmz@gmail.com";
    };

    gui.enable = true;
    tui.enable = true;

    # Disabled until `pass` is initialized and OAuth tokens are stored at
    # work/gmail/vdirsyncer/{clientid,clientsecret} + ~/secrets/access_tokens.
    calendar.enable = false;

    # polybar wants X11; this host is on Hyprland (Wayland).
    polybar.enable = false;
    # wluma needs an ALS device + wlroots brightness control wired up.
    wluma.enable = false;
    # darkman needs geo coords (sunrise/sunset) configured.
    darkman.enable = false;

    claude-code.hostContext = ''
      # Host: glacier
      You are on **glacier**, a laptop (IdeaPad Slim 5, AMD CPU+GPU, x86_64).
      This is the primary mobile dev machine with full GUI + TUI suites.
    '';
    claude-code.proxyUrl = "http://127.0.0.1:10808";

    # uv needs PyPI on first frdict launch — route through the local proxy
    # since direct PyPI is blocked here. Once ~/.cache/uv is warm, restarts
    # don't hit the network at all.
    frdict.proxy = "http://127.0.0.1:10808";
  };
}
