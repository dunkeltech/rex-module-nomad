client {
    enabled = true
    server_join {
        retry_join = ["<%= $master_node %>:4647"]
    }
    options {
        function_denylist = ""
    }
}
