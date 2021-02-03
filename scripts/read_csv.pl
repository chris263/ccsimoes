use strict;
use warnings;
use Text::CSV_XS;
use Getopt::Long;
use Data::Dumper;


my $read_file =  $ARGV[0] or die "Need to get CSV file on the command line\n";;
my $csv = Text::CSV_XS->new ({ binary =>1, sep_char => ',' });
open(my $data, '<', $read_file) or die "Could not open '$read_file' $!\n";
print("Openning $read_file\n");
while (my $line = <$data>) {
  chomp $line;
 
  my @fields = split "," , $line;
  print("$fields[11]\n");
}

# open(my $fh,">:encoding(utf8)","new.csv") or die "falhou $!";

# my @rows = (["Chris","Dadi","Nem"]);

# $csv->print ($fh, $_) for @rows;

# close $fh;