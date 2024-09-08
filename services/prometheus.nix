{ config, agenix, ... }: {
    age.secrets.grafana_prometheus_remote_write_auth = {
        file = ../secrets/grafana_prometheus_remote_write_auth.age;
        owner = "prometheus";
        group = "prometheus";
    };

    environment.persistence."/persist" = {
        directories = [
            # "Directory below /var/lib to store Prometheus metrics data"
            # https://search.nixos.org/options?channel=unstable&show=services.prometheus.stateDir&from=0&size=50&sort=relevance&type=packages&query=prometheus+var
            "/var/lib/${config.services.prometheus.stateDir}"
        ];
    };

    services.prometheus = {
        enable = true;

        exporters = {
            node = {
                enable = true;
                # additional collectors beyond defaults
                enabledCollectors = [ 
                    "systemd"
                    "processes"
                ];
            };
        };

        scrapeConfigs = [
            {
                job_name = "node";
                static_configs = [{
                    targets = [ "localhost:${toString config.services.prometheus.exporters.node.port}" ];
                }];
            }
            {
                job_name = "jellyfin";
                static_configs = [{
                    # https://jellyfin.org/docs/general/networking/index.html#port-bindings
                    targets = [ "localhost:8096" ];
                }];
            }
        ];

        remoteWrite = [
            {
                url = "https://prometheus-prod-13-prod-us-east-0.grafana.net/api/prom/push";
                basic_auth = {
                    username = "1755859";
                    password_file = config.age.secrets.grafana_prometheus_remote_write_auth.path;
                };
            }
        ];
    };
}