scaling "cluster_policy" {
    enabled = true
    min     = 2
    max     = 5

    policy {
        cooldown            = "2m"
        evaluation_interval = "1m"

        check "mem_allocated_percentage_high" {
            source = "nomad-apm"
            query  = "percentage-allocated_memory"
            group = "mem-usage"

            strategy "threshold" {
                lower_bound = 70
                delta       = 1

                within_bounds_trigger = 1
            }
        }

        check "mem_allocated_percentage_low" {
            source = "nomad-apm"
            query  = "percentage-allocated_memory"
            group = "mem-usage"

            strategy "threshold" {
                upper_bound = 50
                delta       = -1

                within_bounds_trigger = 1
            }
        }

        target "multipass-target" {
            instance_image_name       = "22.04"
            cloud_init_user_data_path = "local/user-data"

            node_drain_deadline = "5m"
            node_class = "nomad-client" # use this instead of instance prefix?
        }
    }
}