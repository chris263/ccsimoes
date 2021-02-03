use strict;
use warnings;

my @array_1 = qw(A B C F);
my $size = scalar(@array_1);
my @new_data = qw(D E);
splice @array_1,3,0,@new_data;
$size = scalar(@array_1);
print("the final product is size = $size\n");
print "@array_1";

my $n = 10;
test_data(@array_1);

sub test_data {
	my (@reads) = @_;
	foreach my $data (@reads){
		print("\nThe read is $data and number is $n\n");
	}
}