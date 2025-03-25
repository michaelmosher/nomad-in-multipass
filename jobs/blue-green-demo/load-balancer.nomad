locals {
  docker_tag   = "alpine"
  docker_image = "nginx:${local.docker_tag}"
}

job "load-balancer" {
  datacenters = ["*"]
  type        = "service"

  constraint {
    attribute = "${attr.unique.hostname}"
    value     = "nomad-client-1"
  }

  ui {
    link {
      label = "Load-balancer main page"
      url   = "http://nomad-client-1.local:8080/services/nginx/"
    }
  }

  group "server" {
    count = 1

    network {
      port "main" {
        static = 8080
      }
    }

    task "main" {
      driver = "docker"

      config {
        image = local.docker_image
        ports = ["main"]
        mount {
          type   = "bind"
          source = "local/default.conf"
          target = "/etc/nginx/conf.d/default.conf"
        }
      }

      template {
        data        = local.nginx_config_template
        destination = "local/default.conf"
        change_mode = "restart"
      }

      resources {
        cpu    = 100
        memory = 64 # MB
      }
    }
  }
}

locals {
  nginx_config_template = <<-EOF
    {{- $live_upstream_servers := service "live.staticsite" -}}
    {{- $canary_upstream_servers := service "canary.staticsite" -}}

    {{- if $live_upstream_servers -}}
    upstream live {
    {{- range $live_upstream_servers }}
      server {{ .Address }}:{{ .Port }};{{- end }}
    }{{- end }}

    {{- if $canary_upstream_servers -}}
    upstream canary {
    {{- range $canary_upstream_servers }}
      server {{ .Address }}:{{ .Port }};{{- end }}
    }{{- end }}

    server {
      listen {{ env "NOMAD_PORT_main" }};
      server_name {{ env "NOMAD_IP_main" }};

      location /services/nginx {
          alias /usr/share/nginx/html;
          index  index.html index.htm;
      }

      {{ if $canary_upstream_servers -}}
      location /services/staticsite-canary/ {
        proxy_pass http://canary/;
      }{{- end }}

      {{ if $live_upstream_servers -}}
      location /services/staticsite/ {
        proxy_pass http://live/;
      }{{- end }}

      error_page 500 502 503 504  /50x.html;
      location = /50x.html {
          root   /usr/share/nginx/html;
      }
    }
  EOF
}
