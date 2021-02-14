use strict;
use warnings;
use Data::Dumper;

my $folder = $ARGV[0];
my $new_folder = $ARGV[1];

opendir my $dir, $folder or die "Cannot open directory: $_ !";
my @files = readdir $dir;
closedir $dir;

print Dumper(\@files)."\n";

foreach my $name (@files){
	if ($name ne "."){
		if ($name ne ".."){
			my $init_name = $folder."/".$name;
			my $cmd = "perl ~/Documents/cxgn/sgn/bin/load_phenotypes_spreadsheet_csv.pl -H localhost -D fixture -U postgres -P 'postgres' -b ~/Documents/cxgn/sgn -i $init_name -a ~/Documents -d plots -u janedoe -o 1 -r ~/Documents/delete_nd_experiment_id.txt";
			system ($cmd) == 0 or die 'There is a problem in the trait value';
		}
	}
}
	