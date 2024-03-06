locals {
  docker_tag   = "v0.0.7"
  docker_image = "hashicorpdemoapp/public-api:${local.docker_tag}"
}

job "publicAPI" {
  datacenters = ["multipass"]
  type        = "service"

  group "server" {
    count = 2

    constraint {
      operator = "distinct_hosts"
      value    = "true"
    }

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
        image = local.docker_image
        ports = ["main"]
      }

      env {
        BIND_ADDRESS = ":${NOMAD_PORT_main}"
      }

      template {
        data = <<-EOF
          {{- range nomadService "productAPI-server"}}
            PRODUCT_API_URI=http://{{ .Address }}:{{ .Port }}
          {{- end }}

          {{- range nomadService "payments-server"}}
            PAYMENT_API_URI=http://{{ .Address }}:{{ .Port }}
          {{- end }}
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
}