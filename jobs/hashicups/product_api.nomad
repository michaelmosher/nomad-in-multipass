locals {
  db_docker_tag   = "v0.0.20"
  db_docker_image = "hashicorpdemoapp/product-api-db:${local.db_docker_tag}"

  server_docker_tag   = "v0.0.20"
  server_docker_image = "hashicorpdemoapp/product-api:${local.server_docker_tag}"

  pg_database_name = "products"
}

job "productAPI" {
  datacenters = ["multipass"]
  type        = "service"

  group "server" {
    network {
      port "main" {}
    }

    service {
      provider = "nomad"
      port     = "main"

      check {
        type     = "http"
        path     = "/health"
        interval = "15s"
        timeout  = "1s"
      }
    }

    task "main" {
      driver = "docker"

      config {
        image = local.server_docker_image
        ports = ["main"]
      }

      env {
        BIND_ADDRESS = "0.0.0.0:${NOMAD_PORT_main}"
      }

      template {
        data = <<-EOF
          {{- $db_host := "" }}{{ $db_port := "" -}}
          {{- $db_username := "" }}{{ $db_password := "" -}}
          {{range nomadService "productAPI-database"}}
            {{- $db_host = .Address }}{{ $db_port = .Port  -}}
          {{- end }}
          {{- with nomadVar "nomad/jobs/productAPI" -}}
            {{- $db_username = .username }}{{ $db_password = .password -}}
          {{- end }}
          DB_CONNECTION={{printf "host=%s port=%d user=%s password=%s dbname=%s sslmode=disable"
            $db_host $db_port $db_username $db_password
            "${local.pg_database_name}"
          }}
        EOF

        destination = "backends.env"
        env         = true
      }

      resources {
        cpu    = 100
        memory = 64 # MB
      }
    }
  }

  group "database" {
    network {
      port "main" { to = 5432 }
    }

    service {
      provider = "nomad"
      port     = "main"
    }

    task "database" {
      driver = "docker"

      config {
        image = local.db_docker_image
        ports = ["main"]
      }

      env {
        POSTGRES_DB = local.pg_database_name
      }

      template {
        data = <<-EOF
          {{- with nomadVar "nomad/jobs/productAPI" -}}
          POSTGRES_USER={{.username}}
          POSTGRES_PASSWORD={{.password}}
          {{- end -}}
        EOF

        destination = "secrets.env"
        env         = true
      }

      resources {
        cpu    = 100
        memory = 256 # MB
      }
    }
  }
}