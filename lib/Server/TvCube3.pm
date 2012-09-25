package Server::TvCube3;

use strict;
use warnings;
use YAML qw/LoadFile/;
use Data::Dumper;

use Melted;

use base qw/Server::TvCube3::Base/;

sub units {
	my ($self, $value) = @_;
	if (defined $value) {
		die "Units must be array" if (ref($value) !~ /^ARRAY/);
	}
	return $self->{units};
}

sub unit_conf {
	my ($self, $idx) = @_;
	return $self->{units}->[$idx];
}

sub unit {
	my ($self, $idx, $value) = @_;
	$self->{units}->[$idx] = $value if (defined $value);
	return $self->{units}->[$idx];
}

sub run_melted {
	my ($self) = @_;
	$self->log("Starting melted server...");
	my $child = fork;
	if ($child) {
		# to be sure that melted is started
		sleep(10);
		my $melted = Melted->new({
			url => '127.0.0.1',
			port => 5242
		});
		my $pid = $melted->ps_string();
		$self->log("MELTED PID [$pid]");
		open(P,'>/etc/tvcube/melted.pid');
		print P $pid;
		close(P);
		$self->{melted_pid} = $pid;
		$melted->connect();
		$self->log("Initializing melted server...");
		$melted->batch('/etc/tvcube/init.melted');
#		$melted->disconnect();
	} else {
		my $melted = Melted->new({
			url => '127.0.0.1',
			port => 5242
		});
		eval {
			$melted->start_server();
		};
		exit;
	}
}

sub run_unit {
	my ($self, $idx) = @_;
	my $child = fork();
	if ($child) {
		$self->log("unit$idx : $child");
	} else {
		eval {

		my $unit = $self->{units}->[$idx];
		my $unit_type = $unit->{type} || 'Server::TvCube3::Unit';

		my $log_base = $self->{log_base};

		eval "use $unit_type";
		$self->fatal("Wrong type [$unit_type] for unit with idx $idx : $@") if ($@);
		my $unit_obj = $unit_type->new({
			unit => $unit->{unit},
			log => (defined $self->{log_base} ? $self->{log_base}."unit".$idx.".log" : $unit->{log}),
			pid => (defined $self->{pid_base} ? $self->{pid_base}."unit".$idx.".pid" : $unit->{pid}),
			url => $unit->{url},
			port => $unit->{port},
			filename => $unit->{schedule},
			base => $self->{log_base},
			idx => $idx,
			play_mode => $unit->{play_mode} || 'append',
            dummy => $self->{dummy},
            emergencies_path => $self->{emergencies_path}
		});


		$unit_obj->run();

		};
		exit(1);
	}
}

sub run_units {
	my ($self) = @_;
	for (my $i = 0; $i < @{$self->{units}}; $i++) {
		$self->run_unit($i);
	}
}

sub init {
	my $self = shift;
    $self->{log} = $self->{log_base}."server.log";
    $self->log("Starting server...\n");
	$self->save_pid($self->{pid});
}

1;
