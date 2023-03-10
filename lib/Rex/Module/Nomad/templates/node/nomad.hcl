datacenter = "dc1"
data_dir = "/srv/nomad"
plugin "docker" {
    config {
    allow_privileged = true
        volumes {
            enabled = true
        }
    }
}
