{ config, golink, agenix, ... }: {
  # TODO (nicholast): factor out hardcoded persistence path
  environment.persistence."/persist" = {
    directories = [
      {
        directory = "/srv/golink/golink";
        user = "golink";
        group = "golink";
        mode = "0700";
      }
    ];
  };

  # TODO (nicholast): factor out hardcoded secret paths
  age.secrets.golink_ts_auth = {
    file = ../secrets/golink_ts_auth.age;
    owner = "golink";
  };

  # TODO (nicholast): factor out hardcoded service paths
  services.golink = {
    enable = true;
    dataDir = "/srv/golink/golink";
    databaseFile = "/srv/golink/golink/golink.db";
    tailscaleAuthKeyFile = config.age.secrets.golink_ts_auth.path;
  };
}