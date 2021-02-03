use strict;
use warnings;
use Data::Dumper;

my @ar1 = ("chris", "dadi", "nem");
my @ar2 = (1,2,3);
my @ar3 = (4,5,"");


my $i=0;
foreach my $nd (@ar1){
	my @row = ();
	push @row, $ar1[$i];
	push @row, $ar2[$i];
	push @row, $ar3[$i];
	# print("The name is $row[$i]\n");
	print Dumper(\@row)."\n";
	$i++;
}

