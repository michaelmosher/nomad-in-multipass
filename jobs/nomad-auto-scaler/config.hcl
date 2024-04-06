log_level  = "INFO"
plugin_dir = "local/plugins"

policy {
    dir              = "local/policies"
    default_cooldown = "2m"

    source "nomad" {
    enabled = false
    }
}

apm "nomad-apm" {
    driver = "nomad-apm"
}

target "multipass-target" {
    driver = "multipass-target"

    config = {
        multipass_address = "192.168.1.215:50051"
        client_cert_path  = "local/client_cert.pem"
        client_key_path   = "secrets/client_key.pem"

        {{ with nomadVar "nomad/jobs/nomad-auto-scaler" -}}
        passphrase = "{{.passphrase}}"
        {{- end }}
    }
}
