#!/usr/bin/perl5.28

use strict;
use warnings;
use Text::CSV_XS;


my $csv = Text::CSV_XS->new ({ 
	binary => 1, 
	auto_diag => 1 
	});

my $folder = $ARGV[0] or die "Need to get CSV file on the command line\n";
my $new_folder = $ARGV[1] or die "Need to get CSV file on the command line\n";
my $parse_file = $ARGV[2] or die "Need to get CSV file on the command line\n";

print("My folder in is $folder\n My folder out is $new_folder\n The parse is $parse_file\n");


####
#Reading files from specific diretory.
opendir my $dir, $folder or die "Cannot open directory: $_ !";
my @files = readdir $dir;
closedir $dir;
my @list_files = ();
my @new_files = ();

# Generating a list of file names in a specific folder
foreach my $name (@files){
	if ($name ne "."){
		if ($name ne ".."){
			my $old_name = $folder.$name;
			push @list_files, $old_name;
			my ($rootname, $extension) = split /\./, $name;
			my $new_name = $new_folder."new_".$rootname.".txt";
			push @new_files, $new_name;
		}
		
	}
	
}

#Creating a list of metadata.
my @trial_name=();
my @study_year=();
my @trial_design=();
my @trial_type=();
my @trial_description=();
my @planting_date=();
my @harvest_date=();
my @location=();
my @breeding_program=();


# This is the file with metadata
# Grabbing data for trial deign, description, breeding program and others.

my $file = $ARGV[2] or die "Need to get CSV file on the command line\n";
open(my $data, '<', $file) or die "Could not open '$file' $!\n";
 
while (my $line = <$data>) {
   chomp $line;
   my @fields = split "," , $line;
   push @breeding_program, $fields[0];
   push @trial_name, $fields[2];
   push @location, $fields[1];
   push @study_year, $fields[4];
   push @trial_design, $fields[5];
   push @trial_type, $fields[3];
   push @trial_description, $fields[6];
   push @planting_date, $fields[7];
   push @harvest_date, $fields[9];
}
close $data;

#Processing new files
my $z = 0; 
while ($z <= scalar(@list_files)){
	# Read/parse CSV
	my @rows;
	# print "The file is $list_files[$z]\n";
	open my $fh2, "<", $list_files[$z] or die "Can't open the file '$list_files[$z]' $!\n";
	my $size = scalar(@trial_name);
	my $count =0;
	my $match;
	my $j=1;
	print "The scalar is $size\n";
	foreach (<$fh2>) {
	   chomp;
	   my @fd = split(/\,/);
	   if ($j>1){
		   while ($count <= $size){
		   		if ($fd[0] eq $trial_name[$count]){
		   			$match = $count;
		   			$count = $size+1;	
		   		}else{
		   			$count++;
		   		}
		   	}
		}
	   $j++;
	   
	}

	close $fh2;


	open my $fh3, "<", $list_files[$z] or die "Can't open the file '$list_files[$z]' $!\n";
	my $i =1;
	while (my $row = $csv->getline ($fh3)) {
		if ($i == 1){
			print "Lendo headers\n";
			# splice @$row, 9, $size;
			splice @$row, 1,0, "breeding_program", "location","year","design","description","trial_type","plot_width","plot_length","field_size","planting_date","harvest_date";
			splice @$row, 18,0, "range_number";
			splice @$row, 20,0,"col_number";
			splice @$row,21,1;
			push @rows, $row;
		}else{
			# splice @$row, 9, $size;
			splice @$row, 1,0, $breeding_program[$match],$location[$match], $study_year[$match],$trial_design[$match],$trial_description[$match],$trial_type[$match],"","","",$planting_date[$match],$harvest_date[$match];
			splice @$row, 18, 0, "";
			push @rows, $row;
		}
		$i++;
	}
	close $fh3;

	 
	# and write as txt
	open $fh3, ">", $new_files[$z] or die "Can't save the file '$new_files[$z]' $!\n";
	print "The new file is $new_files[$z]\n";
	print $fh3 (join("\t", @$_), "\n") for @rows;
	# $csv->say ($fh3, $_) for @rows;
	close $fh3 or die "Can't save it $!";
	$z++;
}
