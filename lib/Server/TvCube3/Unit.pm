package Server::TvCube3::Unit;

use YAML qw/LoadFile DumpFile/;
use Schedule::Cron;

use strict;
use warnings;
use Data::Dumper;

use Melted;

use Server::TvCube3::Base qw/uts cts/;
use base qw/
  Server::TvCube3::Base
  Server::TvCube3::Cronable
/; 

sub load_schedule {
  my ($self, $fn) = @_;

  my $emergencies = {};
  eval {
    $emergencies = LoadFile($self->{emergencies_path});
  };
  
  $self->{emergencies} = $emergencies;
  $self->log("Emergencies:\n".Dumper($self->{emergencies}));

  $self->{schedule} = LoadFile($self->{filename});
}

sub dump_schedule {
  my ($self) = @_;
  warn "Schedule dump:\n";
  if (defined $self->{schedule}) {
    for my $block (@{$self->{schedule}}) {
      my $start_time_sec = $block->{start_time};
      warn "  block: [".$block->{name}."] start [".uts($start_time_sec)."] [".$start_time_sec." epoch]\n";
      for my $entry (@{$block->{entries}}) {
        my $start = $start_time_sec;
        $start_time_sec += $entry->{source_duration};
        $entry->{_start_time} = $start;
        $entry->{_stop_time} = $start_time_sec;
        warn "    - entry  [".sprintf("%6s", $entry->{source_duration})."] [".uts($start)."]<=>[".uts($start_time_sec)."] [".$entry->{source_uri}."]\n";
      }
    }
  }
}

sub current_file {
  my ($self, $file) = @_;
  my $fn = $self->{log_base}.'unit'.$self->{idx}.'.current';
  open(F, ">$fn");
  print F $file;
  close(F);
}

sub shift_schedule {
  my ($self, $sec) = @_;
  if (defined $self->{schedule}) {
    for my $block (@{$self->{schedule}}) {
      $block->{start_time} += $sec;
    }
  }

}

sub load_to_cron {
  my ($self) = @_;
  my $apnd = 0;
  $self->clean_timetable;
  if (defined $self->{schedule}) {
    my $count = 0;
    for my $block (@{$self->{schedule}}) {
      my $start_time_sec = $block->{start_time};
      my $last_entry = undef;
      my $count_entry = -1;
      for my $entry (@{$block->{entries}}) {
        $count_entry++;

        # resolve emergencies
        if ($self->{emergencies}->{$entry->{source_uri}}) {
          $entry->{name} = "[E]".$entry->{name};
          $entry->{source_uri} = $self->{emergencies}->{$entry->{source_uri}};
        }

        my $start = $start_time_sec;
        $start_time_sec += $entry->{source_duration};
        $entry->{_start_time} = $start;
        $entry->{_stop_time} = $start_time_sec;

        if ($entry->{_stop_time} <= time()) {
          next;
        } elsif ( ($entry->{_stop_time} > time() ) and ($entry->{_start_time} <= time)) {
          $self->current_file('['.$entry->{source_uri}.'][load]');
          $self->log("load entry ".uts($entry->{_start_time})." = ".cts($entry->{_start_time})." ".$entry->{source_uri});
          my $diff = time - $entry->{_start_time};
          $self->log("diff=$diff");
          my $load_state = $self->melted->load($entry->{source_uri}, $diff, $entry->{source_duration});
          $self->log($load_state);
          if ($load_state =~ /^ERROR/) {
            $self->fatal("DIE $load_state");
            die "!!!\n";
          }
          my $play_state = $self->melted->play();
          $self->log($play_state);
          if ($play_state =~ /^ERROR/) {
            $self->fatal("DIE $play_state");
            die "!!!\n";
          }
          $self->current_file('['.$entry->{source_uri}.'][play]');
          $apnd = 1;
          next;
        }
        if ($apnd) {

          $self->current_file('['.$entry->{source_uri}.'][load]');
          my $append_state = $self->melted->append($entry->{source_uri}, 0, $entry->{source_duration});
          $self->log($append_state);
          $apnd = 0;
          $self->current_file('['.$entry->{source_uri}.'][append]');
        }
        $self->log(uts($entry->{_start_time})." = ".cts($entry->{_start_time})." ".$entry->{source_uri});
        $self->cron()->add_entry(cts($entry->{_start_time}), \&evt_entry, $self, 
          $entry->{source_uri}, 
          'evt_entry',
          $entry,
          $block->{entries}->[$count_entry + 1],
          $self->{schedule}->[$count + 1]
        );
        $self->cron()->add_entry(cts($entry->{_start_time} + int($entry->{source_duration} / 2 )), \&evt_middle_of_entry, $self, 
          $entry->{source_uri}, 
          'evt_middle_of_entry', 
          $entry,
          $block->{entries}->[$count_entry + 1],
          $self->{schedule}->[$count + 1]
        );
        $last_entry = $entry;
      }
      $count++;
      if (defined $self->{schedule}->[$count] && $last_entry->{_stop_time} != $self->{schedule}->[$count]->{start_time}) { # found gap
        my $sec = ($self->{schedule}->[$count]->{start_time} - $last_entry->{_stop_time});
        $self->log("gap ".$sec." sec");
        $self->cron()->add_entry(cts($last_entry->{_stop_time}), \&evt_gap, $self, $sec);
        $self->cron()->add_entry(cts($last_entry->{_stop_time} + int($sec / 2)), \&evt_gap, $self, $sec);
      }
    }
  }

}

# events

sub evt_entry {
  my ($self,$uri, $type, $entry, $next_entry, $next_block) = @_;
  $self->log("play entry[$uri]");

  if (defined $self->{play_mode} && $self->{play_mode} eq 'play') {
  my $load_state = $self->melted->load($entry->{source_uri}, 0, $entry->{source_duration});
  my $play_state = $self->melted->play();

  $self->log($play_state);
  if ($play_state =~ /^ERROR/) {
    $self->fatal("DIE $play_state");
    die "!!!\n";
  }

  if (defined $next_entry) {

    $self->log("   - next [d]entry ".$next_entry->{name});
  } elsif (defined $next_block) {
    $next_entry = $next_block->{entries}->[0];
    $self->log("   - next [d]block ".$next_block->{name})
  }

  }
}

sub evt_middle_of_entry {
  my ($self,$uri, $type, $entry, $next_entry, $next_block) = @_;
  $self->log("middle of entry [$uri]");

  if (defined $self->{play_mode} && $self->{play_mode} eq 'append') {

  if (defined $next_entry) {
    $self->log("   - next [d]entry ".$next_entry->{name});
    my $append_state = $self->melted->append($next_entry->{source_uri}, 0, $next_entry->{source_duration});

    $self->log($append_state);
    if ($append_state =~ /^ERROR/) {
      $self->fatal("DIE $append_state");
      die "!!!\n";
    }

  } elsif (defined $next_block) {
    $next_entry = $next_block->{entries}->[0];
    $self->log("   - next [d]entry ".$next_entry->{name}." (next block!)");
    my $append_state = $self->melted->append($next_entry->{source_uri}, 0, $next_entry->{source_duration});
    $self->log($append_state);
    if ($append_state =~ /^ERROR/) {
      $self->fatal("DIE $append_state");
      die "!!!\n";
    }

  }

  }

}

sub evt_gap {
  my ($self,$sec) = @_;
  $self->log("play gap[$sec]");
}


sub evt_middle_of_gap {
  my ($self, $sec) = @_;
  $self->log("middle of gap[$sec]");
}


sub sig_hup {
  my $self = shift;
  $self->log("HUP [$self]!");
  my $schedule_path = "./schedules/unit".$self->{unit}.".schedule.yml";
  eval {
    $self->load_schedule($schedule_path);
  };
  if ($@) {
    $self->log("Can't load schedule [$schedule_path]: $@");
  }

  $self->load_to_cron();
}

sub sig_int {
  my $self = shift;
  $self->fatal("INT [$self]!");
}

sub melted {
  my ($self, $value) = @_;
  $self->{melted} = $value if (defined $value);
  return $self->{melted};
}

sub save_pid {
  my ($self) = @_;
  open(PID, '>'.$self->{pid});
  print PID $$;
  close PID;
}


sub init {
  my $self = shift;
  $self->log("melted ".$self->{url}.':'.$self->{port});
  $self->save_pid();

  $self->fatal("Unit number is not set or not integer!") if ($self->{unit} !~ /^\d+$/);
    $self->melted(Melted->new({
      url => $self->{url} || '127.0.0.1',
      port => $self->{port} || 5242,
      unit => $self->{unit},
        dummy => $self->{dummy}
    }));

    $self->melted->connect();

  $self->{schedule} = [] if (! defined $self->{schedule});
  eval {
    $self->load_schedule();
  };
  if ($@) {
    $self->log("Can't load schedule [$self->{filename}]: $@");
  }
  $self->init_cron();

  $self->load_to_cron();

  $SIG{HUP} = sub {
    $self->sig_hup();
  };
  $SIG{INT} = sub {
    $self->sig_int();
  };
  
}

1;
