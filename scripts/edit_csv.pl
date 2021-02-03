
use strict;
use warnings;
use Text::CSV;
 
my $file = $ARGV[0] or die "Need to get CSV file on the command line\n";
 
my $sum = 0;
open(my $data, '<', $file) or die "Could not open '$file' $!\n";
 
while (my $line = <$data>) {
  chomp $line;
 
  my @fields = split "," , $line;
  $sum += $fields[2];
}
print "$sum\n";

open(my $fh, '>', 'result.csv') or die 'could not open the file $!\n';
my $csv = Text::CSV->new ( { binary => 1, quote_char => "'", escape_char => "\\" } );
my @rows = ("studyYear","studyDbId","studyName","studyDesign","locationDbId","locationName","germplasmDbId","germplasmName","germplasmSynonyms","observationLevel","observationUnitDbId","observationUnitName","replicate","blockNumber","plotNumber");
push(@rows, "chris");	
my @records = ([@rows],["name","dadi","chris","nem"]);
$csv->print ($fh, $_) for @records;
close $fh or die "new.csv: $!";