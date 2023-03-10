# Nomad Rex Module

Manage Nomad installations and deployments with Rex.

Nomad is a simple scheduler and orchestrator to deploy and manage containerized and non-containerized applications.

## Task Requirements

If you want to use the Deploy tasks, you have to define 2 server groups.

* master_nodes
* compute_nodes

## OS Requirements

This module is currently only tested with debian. But it might run on other distros as well.

## Examples

### Deploy Nomad on your hosts.

```perl
use boolean;
use Rex -feature => ['1.4'];

use Rex::Module::Nomad;
use Rex::Module::Nomad::Deploy;

report -on => "YAML";

group master_nodes => qw/192.168.1.10/;
group compute_nodes => qw/192.168.1.11 192.168.1.12 192.168.1.13/;

task deploy => sub {
    do_task [qw/
        prepare_nodes
        configure_master_nodes
        configure_compute_nodes
        ensure_nomad_running
    /];
};

task prepare_nodes => group => [qw/master_nodes compute_nodes/] => sub {
    Rex::Module::Nomad::Deploy::prepare;
    Rex::Module::Nomad::Deploy::deploy("1.5.0");
};

task configure_master_nodes => group => [qw/master_nodes/] => sub {
    Rex::Module::Nomad::Deploy::configure_master;
};

task configure_compute_nodes => group => [qw/compute_nodes/] => sub {
    Rex::Module::Nomad::Deploy::configure_node
};

task ensure_nomad_running => group => [qw/master_nodes compute_nodes/] => sub {
    Rex::Module::Nomad::Deploy::ensure_nomad_running;
};
```

### Manage Nomad Jobs

```perl
use boolean;
use Rex -feature => ['1.4'];

use Rex::Module::Nomad;
use Rex::Module::Nomad::Deploy;

report -on => "YAML";

group master_nodes => qw/192.168.1.10/;
group compute_nodes => qw/192.168.1.11 192.168.1.12 192.168.1.13/;

task deploy_whoami => group => [qw/master_nodes/] => sub {
    my @master_node = Rex::Group->get_group("master_nodes");
    my $first_master_node = $master_node[0];

    nomad_job "whoami",
        ensure => "present",
        spec => {
            datacenters => ["dc1"],
            type => "service",
            group => {
                demo => {
                    count => 1,

                    network => [
                        {
                            port => {
                                http => {
                                    to => 80
                                }
                            }
                        }
                    ],

                    service => {
                        name => "whoami-demo",
                        port => "http",
                        provider => "nomad",

                        tags => [
                            'traefik.enable=true',
                            'traefik.http.routers.http.rule=Host(`whoami.nomad.localhost`)'
                        ],
                    },

                    task => {
                        server => {
                            env => {
                                WHOAMI_PORT_NUMBER => '${NOMAD_PORT_http}',
                            },

                            driver => "docker",

                            config => {
                                image => "traefik/whoami",
                                ports => ["http"]
                            }
                        }
                    }
                }
            }
        };
};
```