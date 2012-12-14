package Server::TvCube3::Cronable;

use strict;
use warnings;

use Schedule::Cron;

sub cron {
  my ($self, $value) = @_;
  $self->{cron} = $value if (defined $value);
  return $self->{cron};
}

sub run {
  my ($self) = @_;
  $self->log("Run unit");
  $self->cron()->run()
}

sub init_cron {
  my $self = shift;
  $self->cron(Schedule::Cron->new(sub {
    warn "dispatch...\n";
  }, {
    nofork => 1
  }));
  $self->cron()->add_entry('*/1 * * * *', sub {});
}

sub list_entries {
  my $self = shift;
  my @entries = $self->cron->list_entries;
  return \@entries
}

sub clean_timetable {
  my $self = shift;
  my @entries = $self->cron->clean_timetable;
}


1;
