{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf mkOption types;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "taskview";

  networkName = "taskview";
  databaseName = "taskviewdb";
  databaseUser = "taskview_db_user";
  webUrl = "http://${cfg.publicHost}:${toString cfg.webPort}";
  apiUrl = "http://${cfg.publicHost}:${toString cfg.apiPort}";
  internalApiUrl = "http://taskview-api:1401";
  mcpUrl = "http://${cfg.publicHost}:${toString cfg.mcpPort}/mcp";

  # Multi-architecture manifest digests published for TaskView 1.53.0.
  images = {
    api = "gimanhead/taskview-ce-api-server:1.53.0@sha256:faa371c81f46450f59453004c48cc3df60171fdb87e85ff21e7dc75fc59d07b8";
    migration = "gimanhead/taskview-ce-db-migration:1.53.0@sha256:0bdc9ee77945429a3d9c6e1a8d146a33cc1f54b0c9146395cc4029103b111dfb";
    web = "gimanhead/taskview-ce-webapp:1.53.0@sha256:b0c2e84724d76f69ebe80f678fda956146a63339f46282c35a5ce96a7c12e5fc";
    mcp = "gimanhead/taskview-ce-mcp:1.53.0@sha256:b2fbfdf5d7ee26d62bacec2a31930b115da60d939bee11429ab39fa5f86460d3";
  };

  applicationEnvironment = {
    DB_HOST = "taskview-db";
    DB_USER = databaseUser;
    DB_NAME = databaseName;
    DB_PORT = "5432";
    DB_POOL_MAX = "20";
    APP_PORT = "1401";
    PM2_INSTANCES = "2";
    JWT_ALG = "HS256";
    ACCESS_LIFE_TIME = "3d";
    REFRESH_LIFE_TIME = "9d";
    APP_URL = webUrl;
    API_PUBLIC_URL = apiUrl;
    TRUST_PROXY = "false";
    AUTH_LOGIN_METHODS = "password";
    PASSWORD_CHANGE_CONFIRMATION = "password";
    ALLOW_PUBLIC_REGISTRATION = "false";
    OAUTH_DYNAMIC_REGISTRATION = "true";
    CORS_ALLOWED_ORIGINS = lib.concatStringsSep "," [
      webUrl
      "http://elderwood:${toString cfg.webPort}"
      "http://taskview.elderwood:${toString cfg.webPort}"
    ];
  };

  containerServiceNames = [
    "docker-taskview-db"
    "docker-taskview-api"
    "docker-taskview-web"
    "docker-taskview-mcp"
  ];

  waitForDatabase = pkgs.writeShellApplication {
    name = "wait-for-taskview-database";
    runtimeInputs = [
      config.virtualisation.docker.package
      pkgs.coreutils
    ];
    text = ''
      for _attempt in $(seq 1 60); do
        health="$(docker inspect --format '{{.State.Health.Status}}' taskview-db 2>/dev/null || true)"
        if [[ "$health" == "healthy" ]]; then
          exit 0
        fi
        sleep 2
      done

      echo "TaskView database did not become healthy within 120 seconds" >&2
      exit 1
    '';
  };
in
{
  options.mine.${name} = mkEnable config {
    tags = [ "task-management" ];

    publicHost = mkOption {
      type = types.str;
      default = config.mine.host.name;
      description = "Host name or address used by TaskView clients.";
    };

    webPort = mkOption {
      type = types.port;
      default = 8888;
      description = "Host port for the TaskView web application.";
    };

    apiPort = mkOption {
      type = types.port;
      default = 1725;
      description = "Host port for the TaskView API.";
    };

    mcpPort = mkOption {
      type = types.port;
      default = 3100;
      description = "Host port for the TaskView Streamable HTTP MCP server.";
    };
  };

  config = mkIf cfg.enable {
    age.secrets.taskview-env.file = inputs.self + /secrets/taskview/taskview-env.age;

    virtualisation.oci-containers = {
      backend = "docker";
      containers = {
        taskview-db = {
          image = "postgres:17@sha256:67f41722b7a8cbdb868a44a4995c846eddfdc2973bccb291ce937dce88ad5675";
          environment = {
            POSTGRES_USER = databaseUser;
            POSTGRES_DB = databaseName;
          };
          environmentFiles = [ config.age.secrets.taskview-env.path ];
          volumes = [ "taskview-postgres:/var/lib/postgresql/data" ];
          networks = [ networkName ];
          extraOptions = [
            "--health-cmd=pg_isready -U ${databaseUser} -d ${databaseName}"
            "--health-interval=5s"
            "--health-timeout=5s"
            "--health-retries=12"
          ];
        };

        taskview-migration = {
          image = images.migration;
          environment = applicationEnvironment;
          environmentFiles = [ config.age.secrets.taskview-env.path ];
          networks = [ networkName ];
          dependsOn = [ "taskview-db" ];
        };

        taskview-api = {
          image = images.api;
          environment = applicationEnvironment;
          environmentFiles = [ config.age.secrets.taskview-env.path ];
          ports = [ "${toString cfg.apiPort}:1401" ];
          volumes = [ "taskview-logs:/usr/src/app/logs" ];
          networks = [ networkName ];
          dependsOn = [ "taskview-migration" ];
          extraOptions = [
            "--sysctl=net.ipv6.conf.all.disable_ipv6=1"
            "--sysctl=net.ipv6.conf.default.disable_ipv6=1"
          ];
        };

        taskview-web = {
          image = images.web;
          environment.TASKVIEW_API_URL = apiUrl;
          ports = [ "${toString cfg.webPort}:80" ];
          networks = [ networkName ];
          dependsOn = [ "taskview-api" ];
        };

        taskview-mcp = {
          image = images.mcp;
          environment = {
            TASKVIEW_URL = internalApiUrl;
            MCP_PUBLIC_URL = mcpUrl;
          };
          ports = [ "${toString cfg.mcpPort}:3100" ];
          networks = [ networkName ];
          dependsOn = [ "taskview-api" ];
        };
      };
    };

    systemd.services =
      lib.genAttrs containerServiceNames (_: {
        after = [ "taskview-network.service" ];
        requires = [ "taskview-network.service" ];
      })
      // {
        taskview-network = {
          description = "Create the TaskView Docker network";
          wantedBy = [ "multi-user.target" ];
          after = [ "docker.service" ];
          requires = [ "docker.service" ];
          path = [ config.virtualisation.docker.package ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = ''
            if ! docker network inspect ${networkName} >/dev/null 2>&1; then
              docker network create ${networkName}
            fi
          '';
        };

        docker-taskview-migration = {
          after = [ "taskview-network.service" ];
          requires = [ "taskview-network.service" ];
          serviceConfig = {
            Type = lib.mkForce "oneshot";
            RemainAfterExit = true;
            Restart = lib.mkForce "no";
            ExecStartPre = lib.mkAfter [ (lib.getExe waitForDatabase) ];
          };
        };
      };
  };
}
