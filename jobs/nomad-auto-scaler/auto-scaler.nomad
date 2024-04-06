#!/usr/bin/env nomad job run

locals {
  release_version = "0.4.3"

  # eg. https://releases.hashicorp.com/nomad-autoscaler/0.3.7/nomad-autoscaler_0.3.7_linux_arm64.zip
  releases_repo         = "https://releases.hashicorp.com/nomad-autoscaler"
  artifact              = "nomad-autoscaler_${local.release_version}_${attr.kernel.name}_${attr.cpu.arch}.zip"
  artifact_url          = "${local.releases_repo}/${local.release_version}/${local.artifact}"
  artifact_checksum_url = "${local.releases_repo}/${local.release_version}/nomad-autoscaler_${local.release_version}_SHA256SUMS"

  # eg. https://github.com/michaelmosher/nomad-plugin-multipass-target/releases/download/v1/nomad-plugin-multipass-target-linux-amd64
  plugin_repo     = "https://github.com/michaelmosher/nomad-plugin-multipass-target"
  plugin_version  = "v12"
  plugin_artifact = "multipass-target-${attr.kernel.name}-${attr.cpu.arch}.zip"
  plugin_artifact_url = format("%s/releases/download/%s/%s",
    local.plugin_repo, local.plugin_version, local.plugin_artifact,
  )

  config_file            = file("./jobs/nomad-auto-scaler/config.hcl")
  cluster_scaling_policy = file("./jobs/nomad-auto-scaler/cluster_scaling_policy.hcl")
  multipass_user_data    = file("./user-data-client")
}

job "auto-scaler" {
  datacenters = ["multipass"]
  type        = "service"

  constraint {
    attribute = "${attr.unique.hostname}"
    value     = "nomad-client-1"
  }

  // To always run on ^that client, we need the abilty to preempt other jobs.
  priority = 65

  group "agent" {
    count = 1

    network {
      port "main" {}
    }

    task "main" {
      driver = "exec"

      config {
        command = "local/nomad-autoscaler"
        args = [
          "agent",
          "-config", "local/auto-scaler.hcl",
          "-http-bind-port", "${NOMAD_PORT_main}",
        ]
      }

      artifact {
        source = local.artifact_url
        // options {
        //   checksum = "file:${local.artifact_checksum_url}"
        // }
      }

      artifact {
        source      = local.plugin_artifact_url
        destination = "local/plugins"
      }

      template {
        destination   = "local/auto-scaler.hcl"
        change_mode   = "signal"
        change_signal = "SIGHUP"
        data          = local.config_file
      }

      template {
        destination = "local/client_cert.pem"
        data        = <<-EOF
          {{- with nomadVar "nomad/jobs/nomad-auto-scaler" -}}
          {{ .client_cert }}
          {{- end }}
        EOF
      }

      template {
        destination = "secrets/client_key.pem"
        data        = <<-EOF
          {{- with nomadVar "nomad/jobs/nomad-auto-scaler" -}}
          {{ .client_key }}
          {{- end }}
        EOF
      }

      template {
        destination   = "local/policies/cluster_scaling_policy.hcl"
        data          = local.cluster_scaling_policy
      }

      template {
        destination = "local/user-data"
        data        = local.multipass_user_data
        // Override the {{ and }} default to avoid conflicts with Jinja syntax.
        left_delimiter = "<<"
        right_delimiter = ">>"
      }

      resources {
        cpu    = 100
        memory = 256 # MB
      }
    }
  }
}
