package Server::TvCube3::Unit::Melted;

use strict;
use warnings;

use base qw/
	Server::TvCube3::Unit
/;

use Melted;

sub evt_entry {
	my ($self,$uri, $type, $entry, $next_entry, $next_block) = @_;
	$self->log("play entry[$uri]");
	if (defined $next_entry) {
		$self->log("   - next entry ".$next_entry->{name});
		$self->log($self->melted->load($entry->{source_uri}, 0, 0));

	} elsif (defined $next_block) {
		$self->log("   - next block ".$next_block->{name})
	}
}

sub melted {
	my ($self, $value) = @_;
	$self->{melted} = $value if (defined $value);
	return $self->{melted};
}



sub init {
	my $self = shift;
	$self->melted(Melted->new({
		url => '127.0.0.1',
		port => 5242
	}));
	$self->SUPER::init();
}

1;
