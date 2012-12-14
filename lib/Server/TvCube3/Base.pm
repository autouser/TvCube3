package Server::TvCube3::Base;

use YAML qw/LoadFile DumpFile/;
use Schedule::Cron;

use strict;
use warnings;

use Exporter;
our @ISA = qw/Exporter/;
our @EXPORT_OK = qw/uts cts/;

sub new {
  my $type = shift;
  my $classname = ref($type) || $type;
  my $href = shift || {};
  bless $href, $classname;
  $href->init();
  return $href;
}

# unix epoch time to cron timestamp
sub cts{
  my $sec = shift;
  my ($year, $month, $day, $h, $m, $s) = (localtime($sec))[5,4,3,2,1,0];
  return "$m $h $day ".($month+1)." * $s";
}


# unix epoch time to timestamp
sub uts {
  my $sec = shift;
  my ($year, $month, $day, $h, $m, $s) = (localtime($sec))[5,4,3,2,1,0];
  return sprintf("%04d-%02d-%02d %02d:%02d:%02d", $year+1900, $month+1, $day, $h, $m, $s);
}


sub log {
  my ($self, $message) = @_;
  my $ts = uts(time());
  if (defined $self->{log}) {
    open(L, '>>'.$self->{log}) || die "Can't open log [".$self->{log}."]: $!\n";
    print L "$ts> $message\n";
    close(L);
  }
}


sub fatal {
  my ($self, $message) = @_;
  my $ts = uts(time());
  if (defined $self->{log}) {
    open(L, '>>'.$self->{log}) || die "Can't open log [".$self->{log}."]: $!\n";
    print L "$ts> $message\n";
    close(L);
  }
  die "$ts> $message\n";
}

### PID

sub save_pid {
  my ($self, $pidfile) = @_;
  open(PID, '>'.$pidfile);
  print PID $$;
  close PID;
}



sub init {
  my $self = shift;
}

1;
