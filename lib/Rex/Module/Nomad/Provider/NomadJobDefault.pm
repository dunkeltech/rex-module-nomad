package Rex::Module::Nomad::Provider::NomadJobDefault;

use strict;
use warnings;

use Rex -base;
use Rex::Resource::Common;
use Rex::Logger;

use Data::Dumper;
use Carp;
use JSON::XS;
use boolean;

sub new {
    my $that  = shift;
    my $proto = ref($that) || $that;
    my $self  = {@_};

    bless( $self, $proto );

    return $self;
}

# the ensure methods
sub present {
    my ( $self, $rule_config ) = @_;

    my $changed = 0;
    my $resource_name = resource_name;

    my $hcl = $self->generate_hcl($resource_name, $rule_config->{spec});

    my $job_file = "/etc/nomad.jobs/$resource_name.nomad";

    file $job_file,
        content => $hcl,
        owner => "root",
        group => "root",
        mode => "0600";
    
    my @output = run "nomad job run $job_file";

    Rex::Logger::info($_) for @output;

    return $changed;
}

sub absent {
    my ( $self, $rule_config ) = @_;

    my $changed = 0;

    return $changed;
}

sub generate_hcl {
    my ($self, $res_name, $ref) = @_;

    my @hcl = ();

    push @hcl, qq~job "$res_name" {~;
    push @hcl, $self->parse_spec($ref, 1);
    push @hcl, qq~}~;
    push @hcl, "";

    return join("\n", @hcl);
}

sub parse_spec {
    my ($self, $spec, $level) = @_;

    my @hcl = ();
    my $indention = "   "x$level;

    for my $key (keys $spec->%*) {
        if (ref $spec->{$key} eq "ARRAY" && ref $spec->{$key}->[0] ne "HASH") {
            push @hcl, $indention . $key . " = " . JSON::XS::encode_json($spec->{$key});
        }
        elsif (ref $spec->{$key} eq "ARRAY" && ref $spec->{$key}->[0] eq "HASH") {
            push @hcl, $indention . qq~$key {~;
            for my $sub_item ($spec->{$key}->@*) {
                push @hcl, $self->parse_spec($sub_item, $level+1);
            }
            push @hcl, $indention . qq~}~;
        }
        elsif (ref $spec->{$key} eq "HASH") {
            my @sub_keys = $spec->{$key}->%*;

            if (ref $spec->{$key}->{$sub_keys[0]} eq "HASH") {
                for my $sub_key (keys $spec->{$key}->%*) {
                    push @hcl, $indention . $key . qq~ "$sub_key" {~;
                    push @hcl, $self->parse_spec($spec->{$key}->{$sub_key}, $level+1);
                    push @hcl, $indention . qq~}~;
                }
            }
            else {
                push @hcl, $indention . $key . " {";
                push @hcl, $self->parse_spec($spec->{$key}, $level+1);
                push @hcl, $indention . "}";
            }
        }
        else {
            my $val = $spec->{$key};
            if(ref($val) eq "boolean") {
                push @hcl, $indention . $key . " = " . ($val ? 'true' : 'false');
            }
            elsif ($val =~ m/^\d*$/) {
                push @hcl, $indention . qq~$key = $val~;
            }
            else {
                push @hcl, $indention . qq~$key = "$val"~;
            }
        }
    }

    return @hcl;
}

1;