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

    claude-code.hostContext = ''
      # Host: glacier
      You are on **glacier**, a laptop (IdeaPad Slim 5, AMD CPU+GPU, x86_64).
      This is the primary mobile dev machine with full GUI + TUI suites.
    '';
  };
}
