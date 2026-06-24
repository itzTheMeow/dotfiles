{ config, xelib, ... }:
let
  app = config.apps.open-webui;

  #TODO: add mtp
  MAIN_MODEL = "qwen3.6:35b-a3b-q4_K_M";
  OTHER_MODELS = [
    "qwen3.5:9b-q8_0"
    "qwen3:14b-q8_0"
  ];
  TASK_MODEL = "qwen3:0.6b";
in
{
  apps.open-webui = {
    domain = "openweb.xela";
    port = 12093;
    enableProxy = true;

    name = "Open WebUI";
    description = "AI Interface";
  };

  # load the model
  services.ollama.loadModels = [
    MAIN_MODEL
    TASK_MODEL
  ]
  ++ OTHER_MODELS;

  services.open-webui = {
    enable = true;
    host = app.ip;
    port = app.port;
    environment = {
      ENABLE_PERSISTENT_CONFIG = "False"; # only use declarative config
      WEBUI_URL = app.url;
      OLLAMA_BASE_URL = xelib.apps.ollama.url;
      ENABLE_DIRECT_CONNECTIONS = "True"; # then enable direct connections for users
      DEFAULT_MODELS = MAIN_MODEL;
      inherit TASK_MODEL;
      TASK_MODEL_EXTERNAL = TASK_MODEL;

      # oauth
      ENABLE_PASSWORD_AUTH = "False";
      ENABLE_LOGIN_FORM = "False";
      ENABLE_OAUTH_SIGNUP = "True";
      OAUTH_PROVIDER_NAME = "Pocket ID";
      OAUTH_SCOPES = "openid email profile groups";
      OAUTH_UPDATE_PICTURE_ON_LOGIN = "True";
      OPENID_PROVIDER_URL = "${xelib.apps.pocket-id.url}/.well-known/openid-configuration";
      OAUTH_MERGE_ACCOUNTS_BY_EMAIL = "True";
      DEFAULT_USER_ROLE = "user"; # approve new users automatically

      BYPASS_MODEL_ACCESS_CONTROL = "True"; # all users get all models
      MCP_INITIALIZE_TIMEOUT = "45"; # allow MCP servers to take longer
      THREAD_POOL_SIZE = "2000"; # concurrency for production servers

      # analytics/stuff- undocumented but in the env example..
      ANONYMIZED_TELEMETRY = "False";
      DO_NOT_TRACK = "True";
      SCARF_NO_ANALYTICS = "True";

      # de-clutter
      ENABLE_CALENDAR = "False";
      ENABLE_COMMUNITY_SHARING = "False";
      ENABLE_NOTES = "False";
      # speeds stuff up since we don't really need these
      ENABLE_TAGS_GENERATION = "False";
      ENABLE_FOLLOW_UP_GENERATION = "False";

      #ENABLE_WEB_SEARCH = "True";
      #WEB_SEARCH_ENGINE = "searxng";
      #SEARXNG_QUERY_URL = "http://127.0.0.1:8888/search?q=<query>&format=json";
    };
    environmentFile = config.sops.secrets.open-webui.path;
  };
  systemd.services.open-webui.after = [ "tailscale-online.service" ];

  sops.envFiles.open-webui = {
    WEBUI_SECRET_KEY = "op://Private/daxqfmcl234pjr7bunfn66ubhy/Secret Key";

    OAUTH_CLIENT_ID = "op://Private/daxqfmcl234pjr7bunfn66ubhy/OAuth Client ID";
    OAUTH_CLIENT_SECRET = "op://Private/daxqfmcl234pjr7bunfn66ubhy/OAuth Client Secret";

    OPENAI_API_BASE_URLS = "op://Private/daxqfmcl234pjr7bunfn66ubhy/OpenAI URLs";
    OPENAI_API_KEYS = "op://Private/daxqfmcl234pjr7bunfn66ubhy/OpenAI Keys";
  };
}
