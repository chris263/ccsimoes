#!/usr/bin/perl5.28
use strict;
use warnings;
 
my $file = $ARGV[0] or die "Need to get CSV file on the command line\n";
 
open(my $data, '<', $file) or die "Could not open '$file' $!\n";
 
while (my $line = <$data>) {
  chomp $line;
   my @fields = split "," , $line;
   print("$fields[2]\n");
}
