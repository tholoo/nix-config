{
  pkgs,
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf mkOption types;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "glance";

  proxyEnv = lib.optionals (cfg.proxy != null) [
    "HTTP_PROXY=${cfg.proxy}"
    "HTTPS_PROXY=${cfg.proxy}"
    "ALL_PROXY=${cfg.proxy}"
    "http_proxy=${cfg.proxy}"
    "https_proxy=${cfg.proxy}"
    "all_proxy=${cfg.proxy}"
    "NO_PROXY=localhost,127.0.0.1,::1"
    "no_proxy=localhost,127.0.0.1,::1"
  ];

  generativeSketch = pkgs.writeTextDir "generative.html" ''
    <!doctype html>
    <html>
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <style>
          html, body { margin: 0; height: 100%; overflow: hidden; background: #0b0f16; }
          canvas { width: 100vw; height: 100vh; display: block; }
        </style>
      </head>
      <body>
        <canvas id="c"></canvas>
        <script>
          const canvas = document.getElementById('c');
          const ctx = canvas.getContext('2d');
          const seed = new Uint32Array(1);
          crypto.getRandomValues(seed);
          let state = seed[0] || Date.now();
          let t = 0;

          function rand() {
            state = (state * 1664525 + 1013904223) >>> 0;
            return state / 4294967296;
          }

          const variant = {
            points: 80 + Math.floor(rand() * 90),
            turns: 5 + rand() * 11,
            wobble: 10 + rand() * 36,
            drift: 0.65 + rand() * 0.7,
            baseHue: Math.floor(rand() * 360),
            hueSpread: 80 + rand() * 190,
            fade: 0.055 + rand() * 0.08,
            radius: 0.36 + rand() * 0.24,
            phase: rand() * Math.PI * 2,
            mode: Math.floor(rand() * 3)
          };

          function resize() {
            const dpr = Math.min(window.devicePixelRatio || 1, 2);
            canvas.width = Math.floor(innerWidth * dpr);
            canvas.height = Math.floor(innerHeight * dpr);
            ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
          }

          function frame() {
            const w = innerWidth;
            const h = innerHeight;
            ctx.fillStyle = 'rgba(8, 11, 18, ' + variant.fade + ')';
            ctx.fillRect(0, 0, w, h);
            ctx.save();
            ctx.translate(w / 2, h / 2);
            ctx.rotate(Math.sin(t * 0.0015 + variant.phase) * 0.22);

            for (let i = 0; i < variant.points; i++) {
              const p = i / variant.points;
              const a = t * 0.006 * variant.drift + p * Math.PI * 2 * variant.turns + variant.phase;
              const wave = Math.sin(t * 0.005 + i * 0.17 + variant.phase);
              const baseR = p * Math.min(w, h) * variant.radius;
              const r = baseR + wave * variant.wobble;
              const fold = variant.mode === 0 ? a : variant.mode === 1 ? a * 0.72 : a * 1.37;
              const x = Math.cos(a) * r + Math.sin(t * 0.003 + i) * variant.wobble;
              const y = Math.sin(fold) * r + Math.cos(t * 0.004 + i * 1.7) * variant.wobble;
              const hue = (variant.baseHue + p * variant.hueSpread + t * 0.045) % 360;
              const alpha = 0.16 + 0.42 * Math.sin(t * 0.01 + i + variant.phase) ** 2;
              ctx.beginPath();
              ctx.arc(x, y, 1 + 3.4 * Math.sin(t * 0.012 + i) ** 2, 0, Math.PI * 2);
              ctx.fillStyle = 'hsla(' + hue + ', 72%, 62%, ' + alpha + ')';
              ctx.fill();
            }

            ctx.restore();
            t++;
            requestAnimationFrame(frame);
          }

          addEventListener('resize', resize);
          resize();
          frame();
        </script>
      </body>
    </html>
  '';
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "media"
      "news"
    ];
  } // {
    proxy = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "http://127.0.0.1:10808";
      description = ''
        Proxy URL exported to the Glance service for server-side widgets
        such as Hacker News, Reddit, RSS, and Twitch.
      '';
    };
  };

  config = mkIf cfg.enable {
    systemd.user.services.glance.Service.Environment = proxyEnv;

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
                    first-day-of-week = "saturday";
                  }
                  {
                    type = "weather";
                    location = "Tehran, Iran";
                    hour-format = "24h";
                  }
                  {
                    type = "bookmarks";
                    title = "Launch";
                    groups = [
                      {
                        title = "Daily";
                        color = "220 35 62";
                        links = [
                          {
                            title = "Hacker News";
                            url = "https://news.ycombinator.com/";
                            icon = "si:ycombinator";
                          }
                          {
                            title = "GitHub";
                            url = "https://github.com/";
                            icon = "si:github";
                          }
                          {
                            title = "Wikipedia";
                            url = "https://en.wikipedia.org/";
                            icon = "si:wikipedia";
                          }
                        ];
                      }
                      {
                        title = "Art";
                        color = "175 46 48";
                        links = [
                          {
                            title = "OpenProcessing";
                            url = "https://openprocessing.org/";
                            icon = "si:processingfoundation";
                          }
                          {
                            title = "p5.js Editor";
                            url = "https://editor.p5js.org/";
                            icon = "si:p5dotjs";
                          }
                          {
                            title = "Shadertoy";
                            url = "https://www.shadertoy.com/";
                            icon = "si:shadertoy";
                          }
                        ];
                      }
                      {
                        title = "PlayStation";
                        color = "225 68 56";
                        links = [
                          {
                            title = "PS Store";
                            url = "https://store.playstation.com/";
                            icon = "si:playstation";
                          }
                          {
                            title = "PS Blog";
                            url = "https://blog.playstation.com/";
                            icon = "si:playstation";
                          }
                          {
                            title = "PS Plus";
                            url = "https://www.playstation.com/ps-plus/";
                            icon = "si:playstation";
                          }
                        ];
                      }
                    ];
                  }
                ];
              }
              {
                size = "full";
                widgets = [
                  {
                    type = "html";
                    title = "Quote";
                    source = ''
                      <div class="flex flex-column gap-10">
                        <p class="size-h3 color-highlight margin-0">The mind is its own place, and in itself can make a heaven of hell, a hell of heaven.</p>
                        <p class="size-h6 color-subdue margin-0">John Milton, Paradise Lost</p>
                      </div>
                    '';
                  }
                  {
                    type = "rss";
                    title = "Reading";
                    style = "detailed-list";
                    limit = 12;
                    collapse-after = 6;
                    cache = "3h";
                    feeds = [
                      {
                        url = "https://aeon.co/feed.rss";
                        title = "Aeon";
                        limit = 4;
                      }
                      {
                        url = "https://www.themarginalian.org/feed/";
                        title = "The Marginalian";
                        limit = 4;
                      }
                      {
                        url = "https://dailynous.com/feed/";
                        title = "Daily Nous";
                        limit = 4;
                      }
                    ];
                  }
                  {
                    type = "split-column";
                    widgets = [
                      {
                        type = "rss";
                        title = "HN";
                        limit = 10;
                        collapse-after = 5;
                        cache = "30m";
                        feeds = [
                          {
                            url = "https://news.ycombinator.com/rss";
                            title = "Hacker News";
                          }
                        ];
                      }
                      {
                        type = "rss";
                        title = "Personal Tech";
                        limit = 8;
                        collapse-after = 4;
                        cache = "3h";
                        feeds = [
                          {
                            url = "https://samwho.dev/rss.xml";
                            title = "samwho";
                          }
                          {
                            url = "https://shen.hong.io/rss";
                            title = "shen.hong.io";
                          }
                        ];
                      }
                    ];
                  }
                ];
              }
              {
                size = "small";
                widgets = [
                  {
                    type = "clock";
                    hour-format = "24h";
                    timezones = [
                      {
                        timezone = "Europe/London";
                        label = "London";
                      }
                      {
                        timezone = "America/New_York";
                        label = "New York";
                      }
                      {
                        timezone = "America/Toronto";
                        label = "Canada";
                      }
                    ];
                  }
                  {
                    type = "rss";
                    title = "Generative Notes";
                    limit = 8;
                    collapse-after = 4;
                    cache = "6h";
                    feeds = [
                      {
                        url = "https://www.creativeapplications.net/feed/";
                        title = "CreativeApplications";
                      }
                      {
                        url = "https://medium.com/feed/processing-foundation";
                        title = "Processing Foundation";
                      }
                    ];
                  }
                ];
              }
            ];
          }
          {
            name = "Play";
            columns = [
              {
                size = "small";
                widgets = [
                  {
                    type = "bookmarks";
                    title = "Make";
                    groups = [
                      {
                        title = "Sketch";
                        color = "174 54 48";
                        links = [
                          {
                            title = "p5 Reference";
                            url = "https://p5js.org/reference/";
                            icon = "si:p5dotjs";
                          }
                          {
                            title = "The Book of Shaders";
                            url = "https://thebookofshaders.com/";
                            icon = "si:opengl";
                          }
                          {
                            title = "Inigo Quilez";
                            url = "https://iquilezles.org/";
                          }
                        ];
                      }
                      {
                        title = "Games";
                        color = "225 68 56";
                        links = [
                          {
                            title = "PS Store Deals";
                            url = "https://store.playstation.com/category/deals";
                            icon = "si:playstation";
                          }
                          {
                            title = "PS5 Games";
                            url = "https://www.playstation.com/ps5/games/";
                            icon = "si:playstation";
                          }
                          {
                            title = "HowLongToBeat";
                            url = "https://howlongtobeat.com/";
                          }
                        ];
                      }
                    ];
                  }
                  {
                    type = "repository";
                    title = "Glance";
                    repository = "glanceapp/glance";
                    pull-requests-limit = 2;
                    issues-limit = 2;
                    commits-limit = 2;
                  }
                ];
              }
              {
                size = "full";
                widgets = [
                  {
                    type = "iframe";
                    title = "Generative Sketch";
                    source = "/assets/generative.html";
                    height = 320;
                  }
                  {
                    type = "rss";
                    title = "Generative Art";
                    style = "horizontal-cards";
                    limit = 10;
                    collapse-after-rows = 2;
                    cache = "6h";
                    feeds = [
                      {
                        url = "https://www.creativeapplications.net/feed/";
                        title = "CreativeApplications";
                        limit = 5;
                      }
                      {
                        url = "https://medium.com/feed/processing-foundation";
                        title = "Processing Foundation";
                        limit = 5;
                      }
                    ];
                  }
                  {
                    type = "videos";
                    title = "Game Video";
                    style = "horizontal-cards";
                    limit = 12;
                    collapse-after-rows = 2;
                    channels = [
                      "UC-2Y8dQb0S6DtpxNgAKoJKA"
                      "UC9PBzalIcEQCsiIkq36PyUA"
                      "UC0fDG3byEcMtbOqPMymDNbw"
                    ];
                  }
                ];
              }
              {
                size = "small";
                widgets = [
                  {
                    type = "rss";
                    title = "PlayStation";
                    limit = 10;
                    collapse-after = 5;
                    cache = "3h";
                    feeds = [
                      {
                        url = "https://blog.playstation.com/feed/";
                        title = "PS Blog";
                        limit = 5;
                      }
                      {
                        url = "https://www.gematsu.com/platforms/playstation/ps5/feed";
                        title = "Gematsu PS5";
                        limit = 5;
                      }
                    ];
                  }
                  {
                    type = "rss";
                    title = "Games Culture";
                    limit = 8;
                    collapse-after = 4;
                    cache = "3h";
                    feeds = [
                      {
                        url = "https://www.eurogamer.net/feed";
                        title = "Eurogamer";
                      }
                      {
                        url = "https://www.polygon.com/rss/index.xml";
                        title = "Polygon";
                      }
                    ];
                  }
                ];
              }
            ];
          }
        ];
        server = {
          port = 5678;
          assets-path = "${generativeSketch}";
        };
      };
    };
  };
}
