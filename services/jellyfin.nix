{
  users.groups = {
    jellyfin = {
      gid = 899;
    };
  };

  # TODO (nicholast): factor out hardcoded service paths
  users.users = {
    jellyfin = {
      uid = 899;
      group = "jellyfin";
      createHome = true;
      home = "/srv/jellyfin/jellyfin";
    };
  };

  # TODO (nicholast): factor out hardcoded persistence path
  environment.persistence."/persist" = {
    directories = [
      {
        directory = "/srv/jellyfin/jellyfin";
        user = "jellyfin";
        group = "jellyfin";
        mode = "0700";
      }
    ];
  };

  services.jellyfin = {
    enable = true;
    dataDir = "/srv/jellyfin/jellyfin";
    cacheDir = "/srv/jellyfin/jellyfin/cache";
    openFirewall = true;
  };
}
