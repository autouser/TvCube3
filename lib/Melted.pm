package Melted;

use strict;
use warnings;

use Net::Telnet;
use Melted;

sub new {
	my $type = shift;
	my $classname = ref($type) || $type;
	my $href = shift || {};
	bless $href, $classname;
	return $href;
}

sub save_pid {
	my ($self, $pidfile) = @_;
	open(PID, '>'.$pidfile);
	print PID $$;
	close PID;
}



sub start_server {
	my ($self) = @_;
	next if ($self->{test});
	my $log = $self->{log} || '/etc/tvcube/melted.log';
	exec "melted -test -port $self->{port} 2> $log";
}

sub ps_string {
	my ($self) = @_;
	my $log = $self->{log} || '/etc/tvcube/melted.log';
	my $pstring = "sh -c melted -test -port $self->{port} 2> $log";
	my @ps_out = split(/\n/, `ps aux | grep melted`);
	my $pid = '';
	for my $line (@ps_out) {
		if ($line =~ $pstring) {
			$line =~ /^(\S+)\s+(\d+)/;
			$pid = $2;
			last;
		}
	}
	return $pid;
}

sub connect {
	my $self = shift;
	next if ($self->{test});
	warn "Connecting $self->{url}:$self->{port} [unit".($self->{unit} || '-unknown')."]\n";
    return if ($self->{dummy});
	$self->telnet(Net::Telnet->new(
		Host => $self->{url},
		Port => $self->{port},
	));
	$self->telnet->getline();
#	$self->telnet->getline();
}

#sub cmd {
#	my ($self, $cmd) = @_;
#	next if ($self->{test});
#	$self->telnet->print($cmd);
#}
#
sub cmd {
        my ($self, $cmd, $not_check) = @_;
        return '404 DUMMY MODE' if ($self->{dummy});
        my @lines = $self->telnet->cmd(String => $cmd, Prompt => '/\n/');
        if (! defined $not_check) {
                return $self->status_process(pop @lines);
        } else {
        }
        return @lines;
}

sub usta {
	my ($self, $unit) = @_;
	$self->connect();
	my @lines = $self->telnet->print("USTA U$unit");
	my $line1 = $self->telnet->getline();
	my $line2 = $self->telnet->getline();
	if ($line1 =~ /^(\d+) OK$/) {
		my $status = '';
		$line2 =~ /^(\d+) (\S+)/;
		$status = $2;
		return $status;
#		return "[".$line1."\n".$line2."]";
	} else {
		return "ERROR";
	}
}

sub status_process {
        my ($self, $line) = @_;
        if ($line =~ /^(\d\d\d)/) {
                my $code = $1;
                if ($code eq '200' or $code eq '201' or $code eq '202') {
					return "OK";
                } else {
					return "ERROR [$line]"
                }
        } else {
                return "UNKNOWN"
        }
}


sub batch {
	my ($self, $filepath) = @_;
	next if ($self->{test});
	open(F, $filepath) || die "Can't open batch file [$filepath]: $!\n";
	while(<F>) {
		chomp;
#		$self->telnet->print($_);
		$self->cmd($_);

		# it is to long
		#sleep(1);
	}
	close(F);
}

sub telnet {
	my ($self, $value) = @_;
	next if ($self->{test});
	$self->{telnet} = $value if (defined $value);
	return $self->{telnet};
}

sub shutdown {
	my ($self) = @_;
	$self->telnet->print("SHUTDOWN");
}

sub append {
	my ($self, $filename, $in, $out) = @_;
	next if ($self->{test});
	$in = $in * 25; $out = $out * 25;
	my $cmd = "APND U$self->{unit} \"$filename\" $in $out";
	return $self->cmd($cmd);
#	warn "$cmd\n";
}

sub load {
	my ($self, $filename, $in, $out) = @_;
	next if ($self->{test});
	$in = $in * 25; $out = $out * 25;
	my $cmd = "LOAD U$self->{unit} \"$filename\" $in $out";
	warn "$cmd\n";
	return $self->cmd($cmd);
#	return $cmd;
}

sub play {
	my ($self) = @_;
	next if ($self->{test});
	my $cmd = "PLAY U$self->{unit}";
	warn "$cmd\n";
	return $self->cmd($cmd);
#	return $cmd;
}

sub wipe {
	my ($self) = @_;
	next if ($self->{test});
	my $cmd = "WIPE U$self->{unit}";
	warn "$cmd\n";
	$self->cmd($cmd);
	return $cmd;
}



sub disconnect {
	my $self = shift;
	next if ($self->{test});
#	warn "Disconnecting $self->{url}:$self->{port} [unit$self->{unit}]\n";
}

1;
