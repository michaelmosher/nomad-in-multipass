locals {
  docker_tag   = "v1.0.3"
  docker_image = "hashicorpdemoapp/frontend:${local.docker_tag}"
}

job "hashicups-frontend" {
  datacenters = ["multipass"]
  type        = "service"

  group "server" {
    network {
      port "main" {}
    }

    service {
      provider = "nomad"
      port     = "main"
    }

    task "main" {
      driver = "docker"

      config {
        image = local.docker_image
        ports = ["main"]
      }

      env {
        NEXT_PUBLIC_PUBLIC_API_URL = "/"
        PORT                       = "${NOMAD_PORT_main}"
      }

      resources {
        cpu    = 100
        memory = 128 # MB
      }
    }
  }
}