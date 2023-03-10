#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

=head1 NAME

Rex::Module::Nomad

=head1 DESCRIPTION

Manage Nomad installations and deployments.

=head1 SYNOPSIS

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

=head1 EXPORTED RESOURCES

=cut

package Rex::Module::Nomad;

use strict;
use warnings;

use Rex -minimal;
use Rex::Resource::Common;
use Rex::Commands::Gather;

use Carp;

my $__provider = {
    default => "Rex::Module::Nomad::Provider::NomadJobDefault"
};

=head 2

With this resource you can manage nomad jobs.

=over 4

=item ensure

Whether the resource should be present or absent

=item spec

The nomad job spec. See nomad job spec documentation for more information.

=back

=cut

resource "nomad_job", { export => 1 }, sub {
    my $rule_name = resource_name;

    my $rule_config = {
        ensure  => param_lookup( "ensure",  "present" ),
        spec => param_lookup( "spec", {} ),
    };

    my $provider =
      param_lookup( "provider", case ( lc(operating_system), $__provider ) );

    $provider->require;

    my $provider_o = $provider->new();

    # and execute the requested state.
    if ( $rule_config->{ensure} eq "present" ) {
        if ( $provider_o->present($rule_config) ) {
            emit created, "NomadJob resource created.";
        }
    }
    elsif ( $rule_config->{ensure} eq "absent" ) {
        if ( $provider_o->absent($rule_config) ) {
            emit removed, "NomadJob resource removed.";
        }
    }
    else {
        die "Error: $rule_config->{ensure} not a valid option for 'ensure'.";
    }
};


1;