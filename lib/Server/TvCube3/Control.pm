package Server::TvCube3::Unit;

use YAML qw/LoadFile DumpFile/;
use Schedule::Cron;

use strict;
use warnings;

sub new {
	my $type = shift;
	my $classname = ref($type) || $type;
	my $href = shift || {};
	bless $href, $classname;
	$href->init();
	return $href;
}


