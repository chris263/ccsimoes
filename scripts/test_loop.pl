#test for loop

use strict;
use warnings;

my @plots = (1,2,3,4,5,6,7,8,9,10,11,12,13,14,15);
my @reps = (1,2,3);
my $plants = scalar(@plots)/scalar(@reps);

my $round = 1;
my $p = 1;
for (my $i = 0 ; $i < scalar(@plots); $i++){
	print "The rest is " . ($i+1)%$plants . "\n";

	if (!( ($i+1) % $plants)){
		$round++;
		$p = 1;
	}else{
		$p++;
	}
}
