server {
    enabled = true
    bootstrap_expect = 1

    server_join {
        retry_join = ["<%= $master_node %>:4648"]
    }
}
