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
  name = "firefox";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "browser"
    ];
  };

  config = mkIf cfg.enable {
    # tridactyl looks inside .mozilla instead of .floorp
    home.file.".mozilla/native-messaging-hosts/tridactyl.json".source =
      "${pkgs.tridactyl-native}/lib/mozilla/native-messaging-hosts/tridactyl.json";

    xdg.configFile."tridactyl/tridactylrc".source = ./tridactylrc;

    programs.floorp = {
      enable = true;
      # package = pkgs.floorp-unwrapped;
      # package = pkgs.floorp.override {
      #   cfg = {
      #     enableTridactylNative = true;
      #   };
      # };
      nativeMessagingHosts = with pkgs; [ tridactyl-native ];
      languagePacks = [
        "en-US"
        "fa"
      ];

      policies = {
        AppAutoUpdate = false; # Disable automatic application update
        BackgroundAppUpdate = false; # Disable automatic application update in the background, when the application is not running.
        # DisableBuiltinPDFViewer = true; # Considered a security liability
        DisableFirefoxStudies = true;
        # DisableFirefoxAccounts = true; # Disable Firefox Sync
        # DisableFirefoxScreenshots = true; # No screenshots?
        # DisableForgetButton = true; # Thing that can wipe history for X time, handled differently
        # DisableMasterPasswordCreation = true; # To be determined how to handle master password
        DisableProfileImport = true; # Purity enforcement: Only allow nix-defined profiles
        DisableProfileRefresh = true; # Disable the Refresh Firefox button on about:support and support.mozilla.org
        DisableSetDesktopBackground = true; # Remove the “Set As Desktop Background…” menuitem when right clicking on an image, because Nix is the only thing that can manage the background
        DisplayMenuBar = "default-off";
        DisablePocket = true;
        DisableTelemetry = true;
        DisableFormHistory = true;
        # DisablePasswordReveal = true;
        DontCheckDefaultBrowser = true; # Stop being attention whore
        # HardwareAcceleration = false; # Disabled as it's exposes points for fingerprinting
        OfferToSaveLogins = false; # Managed by KeepAss instead
        EnableTrackingProtection = {
          Value = true;
          Locked = true;
          Cryptomining = true;
          Fingerprinting = true;
          EmailTracking = true;
          # Exceptions = ["https://example.com"]
        };
        EncryptedMediaExtensions = {
          Enabled = true;
          Locked = true;
        };
        ExtensionUpdate = false;
        # FIXME(Krey): Review `~/.mozilla/firefox/Default/extensions.json` and uninstall all unwanted
        # Suggested by t0b0 thank you <3 https://gitlab.com/engmark/root/-/blob/60468eb82572d9a663b58498ce08fafbe545b808/configuration.nix#L293-310
        # NOTE(Krey): Check if the addon is packaged on https://gitlab.com/rycee/nur-expressions/-/blob/master/pkgs/firefox-addons/addons.json
        ExtensionSettings = {
          "*" = {
            installation_mode = "blocked";
          };
          # "addon@darkreader.org" = {
          # 	# Dark Reader
          # 	install_url = "file:///${self.inputs.firefox-addons.packages.x86_64-linux.darkreader}/share/mozilla/extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}/addon@darkreader.org.xpi";
          # 	installation_mode = "force_installed";
          # };
          # "7esoorv3@alefvanoon.anonaddy.me" = {
          #     # LibRedirect
          #     install_url = "file:///${self.inputs.firefox-addons.packages.x86_64-linux.libredirect}/share/mozilla/extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}/7esoorv3@alefvanoon.anonaddy.me.xpi";
          #     installation_mode = "force_installed";
          # };
          # "jid0-3GUEt1r69sQNSrca5p8kx9Ezc3U@jetpack" = {
          # 	# Terms of Service, Didn't Read
          # 	install_url = "file:///${self.inputs.firefox-addons.packages.x86_64-linux.terms-of-service-didnt-read}/share/mozilla/extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}/jid0-3GUEt1r69sQNSrca5p8kx9Ezc3U@jetpack.xpi";
          # 	installation_mode = "force_installed";
          # };
          # "keepassxc-browser@keepassxc.org" = {
          # 	# KeepAssXC-Browser
          # 	install_url = "file:///${self.inputs.firefox-addons.packages.x86_64-linux.keepassxc-browser}/share/mozilla/extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}/keepassxc-browser@keepassxc.org.xpi";
          # 	installation_mode = "force_installed";
          # };
          # # FIXME(Krey): Contribute this in NUR
          # "dont-track-me-google@robwu.nl" = {
          # 	# Don't Track Me Google
          # 	install_url = "https://addons.mozilla.org/firefox/downloads/latest/dont-track-me-google1/latest.xpi";
          # 	installation_mode = "force_installed";
          # };
          # "jid1-BoFifL9Vbdl2zQ@jetpack" = {
          # 	# Decentrayeles
          # 	install_url = "file:///${self.inputs.firefox-addons.packages.x86_64-linux.decentraleyes}/share/mozilla/extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}/jid1-BoFifL9Vbdl2zQ@jetpack.xpi";
          # 	installation_mode = "force_installed";
          # };
          # "{73a6fe31-595d-460b-a920-fcc0f8843232}" = {
          # 	# NoScript
          # 	install_url = "file:///${self.inputs.firefox-addons.packages.x86_64-linux.noscript}/share/mozilla/extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}/{73a6fe31-595d-460b-a920-fcc0f8843232}.xpi";
          # 	installation_mode = "force_installed";
          # };
          # "{74145f27-f039-47ce-a470-a662b129930a}" = {
          # 	# ClearURLs
          # 	install_url = "file:///${self.inputs.firefox-addons.packages.x86_64-linux.clearurls}/share/mozilla/extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}/{74145f27-f039-47ce-a470-a662b129930a}.xpi";
          # 	installation_mode = "force_installed";
          # };
          # "sponsorBlocker@ajay.app" = {
          # 	# Sponsor Block
          # 	install_url = "file:///${self.inputs.firefox-addons.packages.x86_64-linux.sponsorblock}/share/mozilla/extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}/sponsorBlocker@ajay.app.xpi";
          # 	installation_mode = "force_installed";
          # };
          # "jid1-MnnxcxisBPnSXQ@jetpack" = {
          # 	# Privacy Badger
          # 	install_url = "file:///${self.inputs.firefox-addons.packages.x86_64-linux.privacy-badger}/share/mozilla/extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}/jid1-MnnxcxisBPnSXQ@jetpack.xpi";
          # 	installation_mode = "force_installed";
          # };
          # "uBlock0@raymondhill.net" = {
          # 	# uBlock Origin
          # 	install_url = "file:///${self.inputs.firefox-addons.packages.x86_64-linux.ublock-origin}/share/mozilla/extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}/uBlock0@raymondhill.net.xpi";
          # 	installation_mode = "force_installed";
          # };
        };

        "3rdparty".Extensions = {
          # https://github.com/libredirect/browser_extension/blob/b3457faf1bdcca0b17872e30b379a7ae55bc8fd0/src/config.json
          # "7esoorv3@alefvanoon.anonaddy.me" = {
          #     # FIXME(Krey): This doesn't work
          #     services.youtube.options.enabled = true;
          # };
          # # https://github.com/gorhill/uBlock/blob/master/platform/common/managed_storage.json
          # "uBlock0@raymondhill.net".adminSettings = {
          #     userSettings = rec {
          #         uiTheme = "dark";
          #         uiAccentCustom = true;
          #         uiAccentCustom0 = "#8300ff";
          #         cloudStorageEnabled = mkForce false; # Security liability?
          #         importedLists = [
          #             "https://filters.adtidy.org/extension/ublock/filters/3.txt"
          #             "https://github.com/DandelionSprout/adfilt/raw/master/LegitimateURLShortener.txt"
          #         ];
          #         externalLists = lib.concatStringsSep "\n" importedLists;
          #     };
          #     selectedFilterLists = [
          #         "CZE-0"
          #         "adguard-generic"
          #         "adguard-annoyance"
          #         "adguard-social"
          #         "adguard-spyware-url"
          #         "easylist"
          #         "easyprivacy"
          #         "https://github.com/DandelionSprout/adfilt/raw/master/LegitimateURLShortener.txt"
          #         "plowe-0"
          #         "ublock-abuse"
          #         "ublock-badware"
          #         "ublock-filters"
          #         "ublock-privacy"
          #         "ublock-quick-fixes"
          #         "ublock-unbreak"
          #         "urlhaus-1"
          #     ];
          # };
        };

        FirefoxHome = {
          Search = true;
          TopSites = true;
          SponsoredTopSites = false; # Fuck you
          Highlights = true;
          Pocket = false;
          SponsoredPocket = false; # Fuck you
          # Snippets = false;
          Locked = true;
        };
        FirefoxSuggest = {
          # WebSuggestions = false;
          SponsoredSuggestions = false; # Fuck you
          # ImproveSuggest = false;
          Locked = true;
        };
        # Handlers = {
        #   # FIXME-QA(Krey): Should be openned in evince if on GNOME
        #   mimeTypes."application/pdf".action = "saveToDisk";
        # };
        extensions = {
          # pdf = {
          #   action = "useHelperApp";
          #   ask = true;
          #   # FIXME-QA(Krey): Should only happen on GNOME
          #   handlers = [
          #     {
          #       name = "GNOME Document Viewer";
          #       path = "${pkgs.evince}/bin/evince";
          #     }
          #   ];
          # };
        };
        NoDefaultBookmarks = true;
        PasswordManagerEnabled = false; # Managed by KeepAss
        # PDFjs = {
        #   Enabled = false;
        #   EnablePermissions = false;
        # };
        # Permissions = {
        # 	Camera = {
        # 		Allow = [https =//example.org,https =//example.org =1234];
        # 		Block = [https =//example.edu];
        # 		BlockNewRequests = true;
        # 		Locked = true
        # 	};
        # 	Microphone = {
        # 		Allow = [https =//example.org];
        # 		Block = [https =//example.edu];
        # 		BlockNewRequests = true;
        # 		Locked = true
        # 	};
        # 	Location = {
        # 		Allow = [https =//example.org];
        # 		Block = [https =//example.edu];
        # 		BlockNewRequests = true;
        # 		Locked = true
        # 	};
        # 	Notifications = {
        # 		Allow = [https =//example.org];
        # 		Block = [https =//example.edu];
        # 		BlockNewRequests = true;
        # 		Locked = true
        # 	};
        # 	Autoplay = {
        # 		Allow = [https =//example.org];
        # 		Block = [https =//example.edu];
        # 		Default = allow-audio-video | block-audio | block-audio-video;
        # 		Locked = true
        # 	};
        # };
        PictureInPicture = {
          Enabled = true;
          Locked = true;
        };
        # PromptForDownloadLocation = true;
        # Proxy = {
        #   Mode = "system"; # none | system | manual | autoDetect | autoConfig;
        #   # Locked = true;
        #   # HTTPProxy = hostname;
        #   # UseHTTPProxyForAllProtocols = true;
        #   # SSLProxy = hostname;
        #   # FTPProxy = hostname;
        #   # SOCKSProxy = "127.0.0.1:9050"; # Tor
        #   SOCKSVersion = 5; # 4 | 5
        #   #Passthrough = <local>;
        #   # AutoConfigURL = URL_TO_AUTOCONFIG;
        #   # AutoLogin = true;
        #   UseProxyForDNS = true;
        # };
        # SanitizeOnShutdown = {
        #   Cache = true;
        #   Cookies = false;
        #   Downloads = true;
        #   FormData = true;
        #   History = false;
        #   Sessions = false;
        #   SiteSettings = false;
        #   OfflineApps = true;
        #   Locked = true;
        # };
        # SearchEngines = {
        #   PreventInstalls = true;
        #   Add = [
        #     {
        #       Name = "SearXNG";
        #       URLTemplate = "http://searx3aolosaf3urwnhpynlhuokqsgz47si4pzz5hvb7uuzyjncl2tid.onion/search?q={searchTerms}";
        #       Method = "GET"; # GET | POST
        #       IconURL = "http://searx3aolosaf3urwnhpynlhuokqsgz47si4pzz5hvb7uuzyjncl2tid.onion/favicon.ico";
        #       # Alias = example;
        #       Description = "SearX instance ran by tiekoetter.com as onion-service";
        #       #PostData = name=value&q={searchTerms};
        #       #SuggestURLTemplate = https =//www.example.org/suggestions/q={searchTerms}
        #     }
        #   ];
        #   Remove = [
        #     "Amazon.com"
        #     "Bing"
        #     "Google"
        #   ];
        #   Default = "SearXNG";
        # };
        # SearchSuggestEnabled = false;
        ShowHomeButton = false;
        # FIXME-SECURITY(Krey): Decide what to do with this
        # SSLVersionMax = tls1 | tls1.1 | tls1.2 | tls1.3;
        # SSLVersionMin = tls1 | tls1.1 | tls1.2 | tls1.3;
        # SupportMenu = {
        # 	Title = Support Menu;
        # 	URL = http =//example.com/support;
        # 	AccessKey = S
        # };
        # StartDownloadsInTempDirectory = true; # For speed? May fuck up the system on low ram
        # UserMessaging = {
        #   ExtensionRecommendations = false; # Don’t recommend extensions while the user is visiting web pages
        #   FeatureRecommendations = false; # Don’t recommend browser features
        #   Locked = true; # Prevent the user from changing user messaging preferences
        #   MoreFromMozilla = false; # Don’t show the “More from Mozilla” section in Preferences
        #   SkipOnboarding = true; # Don’t show onboarding messages on the new tab page
        #   UrlbarInterventions = false; # Don’t offer suggestions in the URL bar
        #   WhatsNew = false; # Remove the “What’s New” icon and menuitem
        # };
        UseSystemPrintDialog = true;
        # WebsiteFilter = {
        # 	Block = [<all_urls>];
        # 	Exceptions = [http =//example.org/*]
        # };
      };
      # arkenfox = {
      #   enable = false; # Decide how we want to handle these things
      #   version = "118.0"; # Used on 119.0, because we don't have firefox 118.0 handy
      # };

      profiles.Default = {
        extensions = {
          force = true;
          packages = with pkgs.nur.repos.rycee.firefox-addons; [
            istilldontcareaboutcookies # removes cookie popup from websites
            consent-o-matic # automatically fill out consent popups
            sponsorblock
            ublock-origin
            # leechblock-ng # block websites
            # darkreader
            # browserpass
            tridactyl
            bitwarden
            switchyomega
            auto-tab-discard
            pkgs.nur.repos.meain.firefox-addons.global-speed
            # enhancer-for-youtube
          ];
          settings = {
            "{f4961478-ac79-4a18-87e9-d2fb8c0442c4}".settings = builtins.fromJSON (
              builtins.readFile ./global_speed.json
            );
            "uBlock0@raymondhill.net".settings = builtins.fromJSON (builtins.readFile ./ublock.json);
          };
        };
        settings = {
          "extensions.autoDisableScopes" = 0; # auto activate extensions
          "floorp.browser.sidebar.enable" = false;
          "floorp.browser.sidebar.is.displayed" = false;
          "floorp.browser.sidebar.right" = false;

          "floorp.browser.tabs.verticaltab.enabled" = false;
          # "floorp.tabbar.style" = 0;
          # "floorp.browser.tabbar.settings" = 4;
          "floorp.browser.sidebae.is.displayed" = 2;
          "floorp.browser.tabs.verticaltab" = false;
          "floorp.verticaltab.hover.enabled" = false;
          "floorp.verticaltab.show.newtab.button" = false;

          /**
            TELEMETRY **
          */
          "datareporting.policy.dataSubmissionEnabled" = false;
          "datareporting.healthreport.uploadEnabled" = false;
          "toolkit.telemetry.unified" = false;
          "toolkit.telemetry.enabled" = false;
          "toolkit.telemetry.server" = "data:,";
          "toolkit.telemetry.archive.enabled" = false;
          "toolkit.telemetry.newProfilePing.enabled" = false;
          "toolkit.telemetry.shutdownPingSender.enabled" = false;
          "toolkit.telemetry.updatePing.enabled" = false;
          "toolkit.telemetry.bhrPing.enabled" = false;
          "toolkit.telemetry.firstShutdownPing.enabled" = false;
          "toolkit.telemetry.coverage.opt-out" = true;
          "toolkit.coverage.opt-out" = true;
          "toolkit.coverage.endpoint.base" = "";
          "browser.newtabpage.activity-stream.feeds.telemetry" = false;
          "browser.newtabpage.activity-stream.telemetry" = false;

          /**
            CRASH REPORTS **
          */
          "breakpad.reportURL" = "";
          "browser.tabs.crashReporting.sendReport" = false;
          "browser.crashReports.unsubmittedCheck.autoSubmit2" = false;

          /**
            MOZILLA UI **
          */
          "extensions.getAddons.showPane" = false;
          "extensions.htmlaboutaddons.recommendations.enabled" = false;
          "browser.discovery.enabled" = false;
          "browser.shell.checkDefaultBrowser" = false;
          "browser.newtabpage.activity-stream.asrouter.userprefs.cfr.addons" = false;
          "browser.newtabpage.activity-stream.asrouter.userprefs.cfr.features" = false;
          "browser.preferences.moreFromMozilla" = false;
          "browser.tabs.tabmanager.enabled" = false;
          "browser.aboutConfig.showWarning" = false;
          "browser.aboutwelcome.enabled" = false;

          # "browser.compactmode.show" = true;
          # change from ctrl to alt to not interfere
          "ui.key.accelKey" = 18;

          "gfx.webrender.all" = true;
          "media.ffmpeg.vaapi.enabled" = true;

          "widget.use-xdg-desktop-portal.file-picker" = 1;
        };

        search = {
          force = true;
          engines = {
            "Nix Packages" = {
              urls = [
                {
                  template = "https://search.nixos.org/packages";
                  params = [
                    {
                      name = "type";
                      value = "packages";
                    }
                    {
                      name = "query";
                      value = "{searchTerms}";
                    }
                  ];
                }
              ];
              icon = "''${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
              definedAliases = [ "@np" ];
            };
            "NixOS Wiki" = {
              urls = [ { template = "https://nixos.wiki/index.php?search={searchTerms}"; } ];
              icon = "https://nixos.wiki/favicon.png";
              updateInterval = 24 * 60 * 60 * 1000; # every day
              definedAliases = [ "@nw" ];
            };
            "google".metaData.alias = "@g";
          };

        };

        # settings = {
        # # Enable letterboxing
        # "privacy.resistFingerprinting.letterboxing" = true;

        # # WebGL
        # "webgl.disabled" = true;

        # "browser.preferences.defaultPerformanceSettings.enabled" = false;
        # "layers.acceleration.disabled" = true;
        # "privacy.globalprivacycontrol.enabled" = true;

        # "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;

        # # "network.trr.mode" = 3;

        # # "network.dns.disableIPv6" = false;

        # "privacy.donottrackheader.enabled" = true;

        # # "privacy.clearOnShutdown.history" = true;
        # # "privacy.clearOnShutdown.downloads" = true;
        # # "browser.sessionstore.resume_from_crash" = true;

        # # See https://librewolf.net/docs/faq/#how-do-i-fully-prevent-autoplay for options
        # "media.autoplay.blocking_policy" = 2;

        # "privacy.resistFingerprinting" = true;
        # };
        # Documentation https://arkenfox.dwarfmaster.net
        # settings = {
        #   "network.proxy.socks_remote_dns" = true; # Do DNS lookup through proxy (required for tor to work)
        # };
      };
    };
  };
}
