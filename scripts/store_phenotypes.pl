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
			my $cmd = "perl ~/cxgn/sgn/bin/load_phenotypes_spreadsheet_csv.pl -H db5.sgn.cornell.edu -D cxgn_batatabase -U postgres -P 'Eo0vair1' -b /home/production/cxgn/sgn -i $init_name -a /home/production/cip -d plots -u chris_simoes -o 1 -r /tmp/delete_nd_experiment_id.txt";
			system ($cmd) == 0;
		}
	}
}
	