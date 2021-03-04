#!/usr/bin/perl5.28

use strict;
use warnings;
use Text::CSV;
use Getopt::Long;
use Data::Dumper;
use List::Util qw(max);

##############
# perl files_consistency.pl -i ~/Documents/datasets/Clean/Peru/SuperClean/ -b Peru
#############

my ($folder, $breeding);
GetOptions(
    'i=s'   => \$folder, #folder with all files;
    'breeding|b=s'	=> \$breeding,
     );

if(!$folder || !$breeding){die 'Missing folder and/or breeding name!'};

my $csv = Text::CSV->new({ sep_char => ',' });

# ####
#Reading files from specific diretory ($folder).
opendir my $dir, $folder or die "Cannot open directory: $_ !";
my @files = readdir $dir;
closedir $dir;

my @fields = ();
my @plot_number = ();
my %files_list = ();
my $trial_name;
my $name_tester;
my $i=0;

open my $fh, ">>", 'append_files.txt' or die "Can't save the file$!\n";

print $fh '***********************************************', "\n";
print $fh 'Breeding program: ',$breeding, "\n";
print $fh '***********************************************',"\n";

if($breeding eq 'Ghana'){
  print $fh "Not checking consistency between trial and file names for Ghana\ndue to complexit on the file name","\n";
  print $fh "#########################","\n";
}
    
foreach my $name (@files){
	if ($name ne "."){
		if ($name ne ".."){
			my $old_name = $folder.$name;
			my ($rootname, $extension) = split /\./, $name;
			open(my $data, '<', $old_name) or die "Could not open '$old_name' $!\n";
			@plot_number=();
			$i=0;
			while (my $line = <$data>) {
   				chomp $line;
   				@fields = split "," , $line;
   				if($i==1){
   					my ($p1_name, $p2_name, $p3_name) = split /\-/, $fields[1];
   					$name_tester = $p1_name."-".$p2_name;

   					if($breeding eq 'Mozambique'){
   						my ($mz_tester, $extra) = split /\_/, $rootname;
   						$rootname = $mz_tester;
   					}
   					$trial_name = $fields[0];
   					if($trial_name ne $name_tester){
   						print("Inconsistency between trial and plot names: $trial_name - $name_tester\n");
              print $fh "Inconsistency between trial and plot names: $trial_name - $name_tester","\n";
   					}
   					if($breeding ne 'Ghana'){
	   					if($rootname ne $trial_name){
	   						print("Inconsistency between trial and file names: $trial_name - $rootname\n");
                print $fh "Inconsistency between trial and file names: $trial_name - $rootname","\n";
	   					}
   					}
   				}
   				if($i>0){
   					push(@plot_number, $fields[3]);
   				}
   				$i++;
   		}
 			if($trial_name ne 'PEP2012SPE-AT02'){
 				if($trial_name ne 'PEP2012POC-AT02'){
 					$i=$i-1;
	   			my $max_plot = max values @plot_number;
	   			if ($max_plot != $i){
	   				print("Strange plot sequence in trial $trial_name\n");
            print $fh "Strange plot sequence in trial $trial_name","\n";
	   				# print Dumper(@plot_number)."\n";
	   			}
 				}
 			}
		}
	}
}

close $fh or die "Can't save it $!";