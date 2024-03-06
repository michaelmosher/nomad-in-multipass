#!/usr/bin/env nomad job run

locals {
  release_version = "2.40.1"

  # eg. https://github.com/prometheus/prometheus/releases/download/v2.39.1/prometheus-2.39.1.linux-arm64.tar.gz
  releases_repo         = "https://github.com/prometheus/prometheus"
  artifact              = "prometheus-${local.release_version}.${attr.kernel.name}-${attr.cpu.arch}.tar.gz"
  artifact_url          = "${local.releases_repo}/releases/download/v${local.release_version}/${local.artifact}"
  artifact_checksum_url = "${local.releases_repo}/releases/download/v${local.release_version}/sha256sums.txt"

  executable = "prometheus-${local.release_version}.${attr.kernel.name}-${attr.cpu.arch}/prometheus"

  config_file = <<-EOF
    ---
    global:
      scrape_interval: 15s

    # Alertmanager configuration
    alerting:
      alertmanagers:
        - static_configs:
          - targets:
            # - alertmanager:9093

    # A scrape configuration containing exactly one endpoint to scrape:
    # Here it's Prometheus itself.
    scrape_configs:
      - job_name: "nomad_services"
        nomad_sd_configs:
          - server: "http://localhost:4646"
        relabel_configs:
          - source_labels: [__meta_nomad_service]
            target_label: nomad_service

  EOF
}

job "prometheus" {
  datacenters = ["multipass"]
  type        = "service"

  group "server" {
    count = 1

    network {
      port "main" {}
    }

    service {
      name     = "${JOB}-server"
      provider = "nomad"
      port     = "main"

      check {
        type     = "http"
        path     = "/-/healthy"
        interval = "30s"
        timeout  = "5s"
      }
    }

    task "main" {
      driver = "exec"

      config {
        command = "local/${local.executable}"
        args = [
          "--config.file", "local/prometheus.yml",
          "--web.listen-address", "${NOMAD_ADDR_main}",
        ]
      }

      artifact {
        source = local.artifact_url
        // options {
        //   checksum = "file:${local.artifact_checksum_url}"
        // }
      }

      template {
        destination   = "local/prometheus.yml"
        change_mode   = "signal"
        change_signal = "SIGHUP"
        data          = local.config_file
      }

      resources {
        cpu    = 100
        memory = 256 # MB
      }
    }
  }
}
