#!/usr/bin/perl 

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";
use Getopt::Long;
use YAML qw/LoadFile DumpFile/;
use DateTime;

my $base_path = '/etc/tvcube/';
my $entry_duration = 5*60;
my $entry_prefix = 'entry';

my $result = GetOptions (
    "config=s"   => \$base_path,
    "dur=i"   => \$entry_duration,
);

$base_path .= '/' if ($base_path !~ /\/$/);
my $config_path = $base_path.'server.yml';
my $config = LoadFile($config_path);

die "No units provided\n" if (ref($config->{units}) !~ /ARRAY/);

my $today = DateTime->today();
my $epoch = $today->epoch();
print "Today: ".$today->ymd." ".$today->hms." Uts: ".$epoch."\n";
my $entries_count = int((24 * 3600) / $entry_duration);
for my $unit (@{$config->{units}}) {
    if (ref($unit) =~ /HASH/ && defined $unit->{schedule} ) {
        print "Generating dummy schedule $unit->{schedule} [$entries_count]\n";
        my $entries = [];
        for (my $i = 0; $i < $entries_count ; $i++) {
            push @$entries, {
				name=> $entry_prefix.$i,
				ord=> $i,
				source_duration=> $entry_duration,
				source_type=> "file",
				source_uri=> $entry_prefix.$i.".mpg",
				start_time=> 0
            }
        }
        print "Saving...\n";
        DumpFile($unit->{schedule}, [{name => 'Dummy Schedule', start_time => $epoch, entries => $entries}]);
    } else {
        print "Wrong unit configuration. Skipping\n";
    }
}
