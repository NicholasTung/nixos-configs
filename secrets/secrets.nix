let
  user_mbp = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILRpk45aMtMZY+9MAysPHaWZA3hEPsB2feQUUz3Cn1mU";

  system_agrotera = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBIDVPZg6HRNCg9IcqPIgr76bHpMVp7xrVly0aUHHAmt";
in
{
  "ts_auth.age".publicKeys = [user_mbp system_agrotera];
  "golink_ts_auth.age".publicKeys = [user_mbp system_agrotera];
  "grafana_prometheus_remote_write_auth.age".publicKeys = [user_mbp system_agrotera];
}