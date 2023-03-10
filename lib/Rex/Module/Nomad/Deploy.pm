package Rex::Module::Nomad::Deploy;

use strict;
use warnings;

use Data::Dumper;

use Rex -base;
use Rex::Logger;
use Rex::Group;

task prepare => sub {
    update_package_db;
    pkg ["wget", "unzip", "docker.io"], ensure => "present";
};

task deploy => sub {
    my ($version) = @_;

    if (is_file("/etc/nomad.d/.ready")) {
        Rex::Logger::info ("Nomad already installed.");
        return;
    }

    download_and_extract($version);
};

task configure_master => sub {
    my @master_node = Rex::Group->get_group("master_nodes");

    file "/etc/nomad.d",
        ensure => "directory",
        mode => "0700",
        owner => "root",
        group => "root";

    file "/etc/nomad.jobs",
        ensure => "directory",
        mode => "0700",
        owner => "root",
        group => "root";

    file "/etc/nomad.d/nomad.hcl",
        content => template("templates/master/nomad.hcl", {}),
        mode => "0644",
        owner => "root",
        group => "root";

    file "/etc/nomad.d/server.hcl",
        content => template("templates/master/server.hcl", {master_node => $master_node[0]}),
        mode => "0644",
        owner => "root",
        group => "root";

    file "/etc/systemd/system/nomad.service",
        content => template("templates/master/nomad.service", {}),
        mode => "0644",
        owner => "root",
        group => "root",
        on_change => sub {
            run "systemctl daemon-reload";
        };
};

task configure_node => sub {
    my @master_node = Rex::Group->get_group("master_nodes");

    file "/etc/nomad.d",
        ensure => "directory",
        mode => "0700",
        owner => "root",
        group => "root";

    file "/etc/nomad.d/nomad.hcl",
        content => template("templates/node/nomad.hcl", {}),
        mode => "0644",
        owner => "root",
        group => "root";

    file "/etc/nomad.d/client.hcl",
        content => template("templates/node/client.hcl", {master_node => $master_node[0]}),
        mode => "0644",
        owner => "root",
        group => "root";

    file "/etc/systemd/system/nomad.service",
        content => template("templates/node/nomad.service", {}),
        mode => "0644",
        owner => "root",
        group => "root",
        on_change => sub {
            run "systemctl daemon-reload";
        };
};

task ensure_nomad_running => sub {
    service "nomad",
        ensure => "started";
};

task download_and_extract => sub {
    my ($version) = @_;

    run "wget -O /tmp/nomad.zip https://releases.hashicorp.com/nomad/${version}/nomad_${version}_linux_amd64.zip";
    run "unzip -d /usr/local/bin/ /tmp/nomad.zip";
    run "chmod 755 /usr/local/bin/nomad";
};

1;