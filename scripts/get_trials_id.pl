#!/usr/bin/perl
use strict;
use warnings;
 
use Text::CSV;
my $csv = Text::CSV->new({ sep_char => ',' });
 
my $file = "list_trials.csv";
 
# my $sum = 0;
open(my $data, '<', $file) or die "Could not open '$file' $!\n";
while (my $line = <$data>) {
  chomp $line;
  print "$line\n";
}
print "It worked\n";