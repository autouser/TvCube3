package TvCube3;

use strict;
use warnings;

$VERSION = "3.0";

1;

=head1 NAME

Server::TvCube3 - Video Broadcasting Server

=head1 SYNOPSIS

    tvcubed.pl [-c path_to_config] start|stop|status|unitrestart

=head1 DESCRIPTION

The Server::TvCube3 module is used for broadcasting of scheduled video through
MLT Video Server  L<http://mltframework.org/gitweb/melted.git>


=head1 CONFIGURATION

TvCube3 use YAML config file. Default location: /etc/tvcube/server.yml, but you can specify another location with -c option

server.yml

  ---
  units:
    # Unit idx. must be unique
    - unit: 0
      # Unit handler
      type: 'Server::TvCube3::Unit'
      # Melted server url
      url: '127.0.0.1'
      # Melted server port
      port: 5242
      # schedule file path
      schedule: './examples/channel0.yml'
      # Name of the channel
      name: 'channel1'
  # Directory for log files: server.log, unitN.log
  log_base: './examples/'
  # Directory for pid files: server.pid, unitN.pid
  pid_base: './examples/'
  # Path to emergency files
  emergencies_path: './example/'
  # Check if server running under special user rights (default: don't check)
  check_user: tvcube
  # Turn on dummy mode
  dummy: 1

channel0.yml

  ---
  - entries:
        # entry name
      - name: entry0
        # Entry duration in seconds
        source_duration: 300
        # Source type (always 'file')
        source_type: file
        # Path to file
        source_uri: entry0.mpg
        # Start time of entry (alway 0)
        start_time: 0
      - name: entry1
        ord: 1
        source_duration: 300
        source_type: file
        source_uri: entry1.mpg
        start_time: 0
    # Schedule name
    name: Dummy Schedule
    # Schedule start time
    start_time: 1329004800

=head1 AUTHOR

Evgeny Grep, C<< <gyorms at gmail.com> >>

=head1 LICENSE AND COPYRIGHT

Copyright 2012 Evgeny Grep.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

