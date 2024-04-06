locals {
  release_version = "0.0.16"

  # eg. https://github.com/hashicorp-demoapp/payments/releases/download/v0.0.16/spring-boot-payments-0.0.16.jar
  release_repo = "https://github.com/hashicorp-demoapp/payments"
  artifact     = "spring-boot-payments-${local.release_version}.jar"
  artifact_url = "${local.release_repo}/releases/download/v${local.release_version}/${local.artifact}"

  artifact_checksum = {
    "0.0.16" = "md5:068c6f787033c1ccc58cef4f3a6fe603"
  }[local.release_version]
}

job "hashicups-payments" {
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
        path     = "/actuator/health"
        interval = "15s"
        timeout  = "1s"
      }
    }

    task "main" {
      driver = "java"

      config {
        jar_path = "local/${local.artifact}"
      }

      artifact {
        source = local.artifact_url

        options {
          checksum = local.artifact_checksum
        }
      }

      template {
        data        = "server.port=${NOMAD_PORT_main}"
        destination = "config/application.properties"
      }

      resources {
        cpu    = 100
        memory = 256 # MB
      }
    }
  }
}