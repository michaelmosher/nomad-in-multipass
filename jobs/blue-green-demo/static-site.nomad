locals {
  my_website = <<-EOF
    HTTP/1.0 200 OK
    Content-Type: text/html; charset=UTF-8

    <!DOCTYPE html>
    <html>
      <body>
        <style>
          html {
              min-height: 100vh;
              display: flex;
              justify-content: center;
              align-items: center;
              display: grid;
              place-content: center;
          }
          html * {
              text-align: center
          }
        </style>
        <h3>You are looking at</h3>
        <h1>Version 1</h1>
        <h1>🥇</h1>
      </body>
    </html>
  EOF
}

job "staticsite" {
  datacenters = ["*"]
  type        = "service"

  group "server" {
    count = 1
    network {
      port "main" {}
    }

    task "main" {
      driver = "exec"

      config {
        command = "local/server.sh"
      }

      template {
        destination = "local/server.sh"
        data        = <<-EOF
          #!/usr/bin/env sh

          while true; do
            echo "${local.my_website}" | nc -l -q 1 0.0.0.0 ${NOMAD_PORT_main}
          done
        EOF
      }

      resources {
        cpu    = 100
        memory = 64 # MB
      }
    }
  }
}
