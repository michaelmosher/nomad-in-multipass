locals {
  docker_tag   = "alpine"
  docker_image = "nginx:${local.docker_tag}"
}

job "nginx" {
  datacenters = ["multipass"]
  type        = "service"

  constraint {
    attribute = "${attr.unique.hostname}"
    value     = "nomad-client-1"
  }

  // To always run on ^that client, we need the abilty to preempt other jobs.
  priority = 65

  group "server" {
    network {
      port "main" {
        static = 8080
      }
    }

    service {
      provider = "nomad"
      port     = "main"
    }

    task "main" {
      driver = "docker"

      config {
        image = "nginx:alpine"
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
    proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=STATIC:10m inactive=7d use_temp_path=off;
    upstream api {
      {{- range nomadService "publicAPI-server" }}
        server {{ .Address }}:{{ .Port }};
      {{- end }}
    }
    upstream frontend_upstream {
      {{ range nomadService "frontend-server" -}}
        server {{ .Address }}:{{ .Port }};
      {{- end }}
    }
    server {
      listen {{ env "NOMAD_PORT_main" }};
      server_name {{ env "NOMAD_IP_main" }};
      server_tokens off;
      gzip on;
      gzip_proxied any;
      gzip_comp_level 4;
      gzip_types text/css application/javascript image/svg+xml;
      proxy_http_version 1.1;
      proxy_set_header Upgrade $http_upgrade;
      proxy_set_header Connection 'upgrade';
      proxy_set_header Host $host;
      proxy_cache_bypass $http_upgrade;
      location /_next/static {
        proxy_cache STATIC;
        proxy_pass http://frontend_upstream;
        # For testing cache - remove before deploying to production
        add_header X-Cache-Status $upstream_cache_status;
      }
      location /static {
        proxy_cache STATIC;
        proxy_ignore_headers Cache-Control;
        proxy_cache_valid 60m;
        proxy_pass http://frontend_upstream;
        # For testing cache - remove before deploying to production
        add_header X-Cache-Status $upstream_cache_status;
      }
      location / {
        proxy_pass http://frontend_upstream;
      }
      location /api {
        proxy_pass http://api;
      }
    }
  EOF
}
