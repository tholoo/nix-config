{
  pkgs,
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "glance";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "media"
      "news"
    ];
  };

  config = mkIf cfg.enable {
    services.glance = {
      enable = true;
      settings = {
        pages = [
          {
            name = "Home";
            columns = [
              {
                size = "small";
                widgets = [
                  {
                    type = "calendar";
                  }
                  {
                    type = "rss";
                    limit = 10;
                    collapse-after = 3;
                    cache = "3h";
                    feeds = [
                      { url = "https://samwho.dev/rss.xml"; }
                      { url = "https://shen.hong.io/rss"; }
                    ];
                  }
                  {
                    type = "twitch-channels";
                    channels = [
                      "theprimeagen"
                      "christitustech"
                      "jerma985"
                    ];
                  }
                ];
              }
              {
                size = "full";
                widgets = [
                  {
                    type = "hacker-news";
                  }
                  # {
                  #   type = "videos";
                  #   channels = [];
                  # }
                  {
                    type = "group";
                    widgets = [
                      {
                        type = "reddit";
                        subreddit = "selfhosted";
                        show-thumbnails = true;
                      }
                      {
                        type = "reddit";
                        subreddit = "pcgaming";
                        show-thumbnails = true;
                      }
                    ];
                  }
                ];
              }
              {
                size = "small";
                widgets = [
                  {
                    type = "weather";
                    location = "Tehran, Iran";
                  }
                ];
              }
            ];
          }
        ];
        server = {
          port = 5678;
        };
      };
    };
  };
}
