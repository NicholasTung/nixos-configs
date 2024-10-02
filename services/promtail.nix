{ config, ... }: {
  age.secrets.grafana_promtail_remote_write_auth = {
    file = ../secrets/grafana_promtail_remote_write_auth.age;
    owner = "promtail";
    group = "promtail";
  };

  services.promtail.enable = true;

  # written based on: 
  # - grafana-generated config.yaml when setting up hosted logs connection
  # - https://grafana.com/docs/loki/latest/send-data/promtail/configuration/#clients
  # - https://xeiaso.net/blog/prometheus-grafana-loki-nixos-2020-11-20/
  services.promtail.configuration = {
    server = {
      http_listen_port = 0;
      grpc_listen_port = 0;
    };

    positions.filename = "/tmp/positions.yaml";

    clients = [
      {
        url = "https://logs-prod-006.grafana.net/loki/api/v1/push";
        basic_auth = {
          username = "977649";
          password_file = config.age.secrets.grafana_promtail_remote_write_auth.path;
        };
      }
    ];

    scrape_configs = [
      {
        job_name = "system";
        journal = {
          max_age = "12h";
          labels = {
            job = "systemd-journal";
            host = "agrotera";
          };
        };
      }
    ];
  };
}
