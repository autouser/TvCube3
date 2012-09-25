#!/usr/bin/perl 

use strict;
use warnings;


use FindBin;
use lib "$FindBin::Bin/../lib";
use App::Daemon qw/detach/;
use Data::Dumper;
use YAML qw/LoadFile DumpFile/;


use Melted;
use Server::TvCube3;
use Getopt::Long;

my $base_path = '/etc/tvcube/';

my $result = GetOptions (
    "config=s"   => \$base_path
);
$base_path .= '/' if ($base_path !~ /\/$/);
my $config_path = $base_path.'server.yml';
my $command = shift || '';
my $unit_idx = shift || '';
my $config = {};
eval {
    $config = LoadFile($config_path);
};
if ($@) {
    print "Can't find config file $config_path\n";
    help();
    exit(1);

}
my $check_user = $config->{check_user};
my $pid_base = $config->{pid_base};
$pid_base .= '/' if ($pid_base !~ /\/$/);
my $log_base = $config->{log_base};
$log_base .= '/' if ($log_base !~ /\/$/);
my $emergencies_path = $config->{emergencies_path};
$emergencies_path .= '/' if ($emergencies_path !~ /\/$/);

my $units = $config->{units} || [];
my $dummy = $config->{dummy};


check_rights($check_user) if ($check_user);

if ($command eq 'start') {
	check_instance($pid_base);

	$SIG{CHLD} = 'IGNORE';

    $App::Daemon::pidfile = $pid_base."server.pid";
	my $server = Server::TvCube3->new({
        pid => $pid_base."server.pid",
        log_base => $log_base,
        pid_base => $pid_base,
        emergencies_path => $emergencies_path,
        units => $units,
        dummy => $dummy,
#		config => $config_path,
#		log => '/etc/tvcube/server.log',
	});


	detach();


	$server->run_melted() if (! $dummy);
	$server->run_units();
	


	my $crashes = 0;
	my $ok = 0;

	while(1) {


	eval { # escape iteration

		sleep(20);


		# check melted server
        if (! $dummy) {
			my $melted_restart = 0;
			if ($server->{melted_pid} ne '') {
				my $cnt = kill 0, $server->{melted_pid};
				if ($cnt) {
					$server->log("Melted with pid [$server->{melted_pid}] is ok");
					$crashes = 0;
				} else {
					$server->log("Melted with pid [$server->{melted_pid}] is not exists");
					$melted_restart = 1;
					$crashes++;
				}
			} else {
				$server->log("Seems like melted wasn't started");
				$melted_restart = 1;
				$crashes++;
			}
			if ($melted_restart) {
				if ($crashes > 10) {
					$server->log("FATAL: something crashes melted server. Exiting...");
				}
				$server->log("Restarting melted [$crashes]...");
				opendir(D, $pid_base);
				my @pids;
				while (my $file = readdir(D)) {
					if ($file =~ /^unit(\d+)\.pid$/) {
						open(P, $pid_base.$file);
						my $pid = <P>;
						chomp $pid;
						push @pids, $pid;
						$server->log("Found [$1] with pid [$pid]");
						close(P);
					}
				}
				for my $pid (@pids) {
					$server->log("Killing pid [$pid]");
					my $cnt = kill 2, $pid;
					$server->log("state: $cnt");
				}
				closedir(D);
				$server->run_melted();
				next;
	
			}

        }

		# checking units
#		opendir(D, '/etc/tvcube/');
		for (my $i = 0; $i < @{$server->{units}}; $i++) {
			my $unit = $server->{units}->[$i];
			next if ($unit->{disable});
			# checking pid
			my $pid = undef;
			my $exists = 0;
			eval {
				open(P, $pid_base."unit$i.pid");
				$pid = <P>;
				chomp $pid;
				close(P);
			};
			if (defined $pid && $pid =~ /^\d+$/) {
				if (kill 0, $pid) {
					$exists = 1;
				}
			}
			if ($exists == 0) {
				$server->log("not exists unit $i\nstarting...");
				$server->run_unit($i)

			} else {

			eval {

            if (! $dummy ) {

				my $melted = Melted->new({
					url => '127.0.0.1',
					port => 5242,
				});
				my $status = $melted->usta($unit->{unit});
				$server->log("Unit $i [U$unit->{unit}]: ".$status);
				if ($status ne 'playing') {
					$server->log("Restarting unit $i...");
					my $pid = undef;
					eval {
						open(P, "/etc/tvcube/unit$i.pid");
						$pid = <P>;
						chomp $pid;
						close(P);
					};
					if (defined $pid && $pid =~ /^\d+$/) {
						if (kill 1, $pid) {
						}
					}

				}
            }
			};
			$server->log($@) if ($@);
			};
		}
#		closedir(D);

	};
	$server->log("ERROR IN ITERATION: $@") if ($@);

	}


} elsif ($command eq 'stop') {
	open(D, "$pid_base/server.pid") || die "Can't find pidfile. Probably server has already been stopped\n";
	my $server_pid = <D>;
	chomp $server_pid;
	close(D);

    my $melted_pid;
    if (! $dummy) {
    	open(D, "$pid_base/melted.pid") || die "Can't find pidfile. Probably melted has already been stopped\n";
	    $melted_pid = <D>;
    	chomp $melted_pid;
    	close(D);
    }


	print "Stopping units...\n";
	opendir(D, $pid_base);
	my @pids;
	while (my $file = readdir(D)) {
		if ($file =~ /^unit(\d+)\.pid$/) {
			open(P, $pid_base.$file);
			my $pid = <P>;
			chomp $pid;
			push @pids, $pid;
			print "Found [$1] with pid [$pid]\n";
			close(P);
		}
	}
	for my $pid (@pids) {
		print "Killing pid [$pid]\n";
		my $cnt = kill 2, $pid;
		print "state: $cnt\n";
	}
	closedir(D);


	print "Stopping server [$server_pid]...\n";
	if (kill 2, $server_pid) {
		print "OK\n";
	} else {
		print "Can't stop process\n."
	}

    if (! $dummy) {
    	print "Shutdowning melted [$melted_pid]...\n";
	    my $melted = Melted->new({
    		url => '127.0.0.1',
	    	port => 5242,
    	});
    	$melted->connect();
    	$melted->shutdown();
    }

} elsif ($command eq 'status') {
	my $daemon_pid = 'NO';
	my $daemon_state = 'DEAD';
	eval {
		open(PID, "$pid_base/server.pid") || die "WRNG\n";
		$daemon_pid = <PID>; chomp $daemon_pid;
		close(PID);
		if (kill 0, $daemon_pid) {
			$daemon_state = 'ALIVE';
		}
	};
	print "DAEMON pid=[$daemon_pid] state=[$daemon_state]\n\n";

	my $format = "%3s %-10s %-3s %10s %10s %-5s\n";
	printf($format, "IDX", "NAME", "UNI", "CST", "PID", "STATE");
	if (ref($config->{units}) =~ /ARRAY/) {
		for (my $i = 0; $i < @{$config->{units}}; $i++) {
			my $unit = $config->{units}->[$i];
			my $unit_name = $unit->{name} || 'UNKNOWN';
			my $unit_number = ($unit->{unit} =~ /^(\d+)$/ ? "U$unit->{unit}" : "NO");
			my $unit_w = (defined $unit->{disable} && $unit->{disable} ? 'DIS' : 'ENA');
			my $unit_pid = 'NO';
			my $unit_state = 'DEAD';
			eval {
				open(PID, "$pid_base/unit$i.pid") || die "WRNG\n";
				$unit_pid = <PID>; chomp $unit_pid;
				close(PID);
				if (kill 0, $unit_pid) {
					$unit_state = 'ALIVE';
				}
			};
			printf($format, $i, $unit_name, $unit_number, $unit_w, $unit_pid, $unit_state);
		}
	} else {
		die "There is no units description in server config\n";
	}
} elsif ($command eq 'unitrestart') {
	open(P, $pid_base."unit".$unit_idx.'.pid') || die "Can't find unit pid\n";
	my $pid = <P>;
	chomp $pid;
	close(P);
	print "Restarting unit [$unit_idx] with pid [$pid]\n";
	my $cnt = kill 1, $pid;
	print "state: $cnt\n";

} else {
    help();
}

sub help {
	print <<HERE;
USAGE tvcubed [-c path_to_config] COMMAND
COMMANDS:
	start - start server as daemon (and start all units)
	stop - stop existing daemon
	status - server status
	unitrestart idx - stop one channel with idx (daemon must be started)
HERE

}

sub check_rights {
    my $username = shift;
	my $suid = uid_by_name($username);
	if ($suid != $<) {
		my $name = name_by_uid($<);
		die "Your can't do any operation with server under user '$name' rights. Please, login as '$username'\n";
	}
}

sub uid_by_name {
	my $suid = shift;
	my ($name, $pass, $uid, $gid, $quota, $comment, $gcos, $dir, $shell, $expire) = getpwnam($suid);
	return $uid || -100;
}

sub name_by_uid {
	my $username = shift;
	my ($name, $pass, $uid, $gid, $quota, $comment, $gcos, $dir, $shell, $expire) = getpwuid($username);
	return $name;
}

sub check_instance {
    my $pid_base = shift;
	my $pid_file = $pid_base.'server.pid';
	if (-e $pid_file) {
		open(PID, $pid_file) || die "Can't open pidfile '$pid_file': $!\n";
		my $pid = <PID>; chomp $pid;
		close(PID);
		if (kill 0, $pid) {
			die "Server is already running with pid [$pid]. Please, stop it before starting with command './script/tvcubed.pl stop' or kill all 'tvcubed' processes manually\n"
		}
	}
}
