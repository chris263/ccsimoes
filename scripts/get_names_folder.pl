use strict;
use warnings;
use Data::Dumper;

my $folder = $ARGV[0];
my $new_folder = $ARGV[1];

opendir my $dir, $folder or die "Cannot open directory: $_ !";
my @files = readdir $dir;
closedir $dir;

# print Dumper(\@files)."\n";

foreach my $name (@files){
	if ($name ne "."){
		if ($name ne ".."){
			print("saving file $name\n");
			my $init_name = $folder."/".$name;
			my $final_name = $new_folder."/unix_".$name;
			my $cmd = "tr -d '\\15\\32' < $init_name > $final_name";
			system ($cmd) == 0 or die "command was unable to run to completion:\n$cmd\n";
		}
	}

}
