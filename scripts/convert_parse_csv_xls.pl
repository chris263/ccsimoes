#!/usr/bin/perl5.28

use strict;
use warnings;
use Text::CSV_XS;
use Text::CSV;
my $csv = Text::CSV->new({ sep_char => ',' });
use Getopt::Long;
use Data::Dumper;
use Spreadsheet::WriteExcel;
use Spreadsheet::ParseExcel;

###############
#perl convert_parse_csv_xls.pl -i ~/Documents/datasets/Clean/Peru/SuperClean/ -o excel_new/ -n ~/Documents/datasets/Clean/Peru/Peru_trial_def_final_SPBase.csv -m teste_peru_final.xls
###############



my ($folder, $new_folder, $parse_file, $metadata_parse);
GetOptions(
    'i=s'        => \$folder,
    'o=s'        => \$new_folder, #this is the output folder
    'n=s'        => \$parse_file, #this is the input metadata
    'm=s'		 => \$metadata_parse # this is the output metadata;
 );

my $csv = Text::CSV->new({ sep_char => ',' });


print("My folder in is $folder\n My folder out is $new_folder\n The parse is $parse_file\n");



# ####
#Reading files from specific diretory ($folder).
opendir my $dir, $folder or die "Cannot open directory: $_ !";
my @files = readdir $dir;
closedir $dir;
my @list_files = ();
my @new_files = ();
my %files_list = ();

# Generating a list of file names in a specific folder
foreach my $name (@files){
	if ($name ne "."){
		if ($name ne ".."){
			my $old_name = $folder.$name;
			push @list_files, $old_name;
			my ($rootname, $extension) = split /\./, $name;
			
			open(my $data, '<', $old_name) or die "Could not open '$parse_file' $!\n";
			my $i=0;
			while (my $line = <$data>) {
   				chomp $line;
   				if($i=1){
   					my @fields = split "," , $line;
   					$files_list{$fields[0]}{'old'} = $old_name;
   				}
   				$i++;
   			}
		}
		
	}
	
}



#Creating a list of metadata.


# This is the file with metadata
# Grabbing data for trial deign, description, breeding program and others.
my $workbook;
my $worksheet;

open(my $metadata, '>', $metadata_parse) or die "could not open $metadata_parse $!\n";
$workbook  = Spreadsheet::WriteExcel->new($metadata);
$worksheet = $workbook->add_worksheet();


open(my $data, '<', $parse_file) or die "Could not open '$parse_file' $!\n";


my $i=0;
my $lc = shift;
while (my $line = <$data>) {
   chomp $line;
   my @fields = split "," , $line;
   $worksheet->write($i,0, $fields[2]); #trial name
   $worksheet->write($i,1, $fields[6]); #trial description
   $worksheet->write($i,2, $fields[3]); #trial type

   #Removing spaces in location name 
   $lc = $fields[1];
   $lc =~ s/^\s+|\s+$//g; #removing spaces from location names;
   $worksheet->write($i,3,$lc);
   
   $worksheet->write($i,4, $fields[4]); #year
   
   #Parsing and checking experimental design
   if ($fields[5] eq "Completely Randomized"){
   	$worksheet->write($i,5,"CRD");
   }elsif ( $fields[5] eq "Complete Block"){
   	$worksheet->write($i,5,"RCBD");
   }elsif( $fields[5] eq "Alpha Lattice"){
   	$worksheet->write($i,5,"Alpha");
   }else{
   	$worksheet->write($i,5, $fields[5]);
   }

   $worksheet->write($i,6, $fields[0]); #breeding program
   $worksheet->write($i,7, $fields[7]); #planting date
   $worksheet->write($i,8, $fields[9]); #harvest date
   $worksheet->write($i,9, $fields[11]); #plot width
   $worksheet->write($i,10, $fields[12]); #plot length
   $worksheet->write($i,11, $fields[10]); #sown plants
   $worksheet->write($i,12, $fields[13]); #field size
   if ($i==0){

   	$worksheet->write($i,13,"newFile") #new file address
   }else{
   	print("The trial is $fields[2]\n ");
   	my $correct_name = $new_folder."new_".$fields[2].".xls";
   	push(@new_files, $correct_name);
   	$files_list{$fields[2]}{'new'} = $correct_name;
   	$worksheet->write($i,13, $correct_name);

   }
   $i++;
}

$workbook->close();
binmode STDOUT;
print $metadata_parse."\n";
close $data;
# print Dumper(\%files_list)."\n";

my @trial_name= keys %files_list;

#Processing new files
my $z = 0;
my $line = 0;
my $tester = 0;
my $rm_column = 0;
while ($z <= scalar(@list_files)){

	# # Read/parse CSV
	my @rows;

	print("Saving trial $z $trial_name[$z]\n");
	
	#Reading input csv file with pheno data. 
	open my $fh3, "<", $files_list{$trial_name[$z]}{'old'} or die "Can't open the file '$files_list{$trial_name[$z]}{'old'}' $!\n";

	open my $fh4, '>', $files_list{$trial_name[$z]}{'new'} or die "Failed to open filehandle: $!";
	$workbook  = Spreadsheet::WriteExcel->new($fh4);
	$worksheet = $workbook->add_worksheet();
	
	my $i =0;
	my $j =0; #columns
	$tester = 0;
	$rm_column = 0;
	open(my $data, '<', $files_list{$trial_name[$z]}{'old'}) or die "Could not open '$files_list{$trial_name[$z]}{'old'}' $!\n";
	while (my $row = <$data>) {
	  chomp $row;
	 
	  @rows = split "," , $row;
	    
		if ($i == 0){
			$line=0;
			splice @rows,7,0, "range_number";
			foreach my $c (@rows){
				if($c =~ m/treatment/){
					splice @rows, $j, 1;
					$tester = 1;
					$rm_column = $j;
				}

				if($c eq "VARIABLE_OF COMP:0000024 Virus symptoms estimating 1-9|month 1|before harvest"){
					@rows[$j] = "Virus symptoms estimating 1-9|month 1|before harvest|COMP:0000024";
				}
				if($c eq "VARIABLE_OF COMP:0000023 Virus symptoms estimating 1-9|month 1|after planting"){
					@rows[$j] = "Virus symptoms estimating 1-9|month 1|after planting|COMP:0000023";
				}
				if($c eq "VARIABLE_OF COMP:0000022 Alternaria symptoms estimating 1-9|month 1|before harvest"){
					@rows[$j] = "Alternaria symptoms estimating 1-9|month 1|before harvest|COMP:0000022";
				}
				if($c eq "VARIABLE_OF COMP:0000026 Alternaria symptoms estimating 1-9|month 1|after planting"){
					@rows[$j] = "Alternaria symptoms estimating 1-9|month 1|after planting|COMP:0000026";
				}
				if($c eq "column_number"){
					@rows[$j] = "col_number";
				}
				$j++;
			}
			save_excel(@rows);
		}else{
			
			if($tester != 1){
				splice @rows, 7, 0,"";
			}else{
				splice @rows, $rm_column, 1;
			}
			$line++;
			save_excel(@rows);	
			
		}
		$i++;
	}
	 close $fh3;
	$workbook->close();
	binmode STDOUT;
	
	$z++;

}


#Subroutine to save in excel format;
sub save_excel {
	my (@reads) = @_;
	my $c = 0;
	foreach my $item (@reads){
		$worksheet->write($line,$c,$item);
		$c++;
	}
}

























