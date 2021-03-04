use strict;
use warnings;
use Getopt::Long;
use Text::CSV_XS;
use Text::CSV;
use Spreadsheet::ParseExcel;
use Data::Dumper;


my ($folder, $new_folder);
GetOptions(
    'i=s'        => \$folder, #folder with all raw files
    'o=s'        => \$new_folder #this is the output folder
 );

print("My folder in is $folder\nMy folder out is $new_folder\n");


my $parser  = Spreadsheet::ParseExcel->new();

####
#Reading files from specific diretory ($folder).
opendir my $dir, $folder or die "Cannot open directory: $_ !";
my @files = readdir $dir;
closedir $dir;
my @list_files = ();
my @new_files = ();

my %list_files;

# Generating a list of file names in a specific folder ($folder) and making new names for xls.
foreach my $name (@files){
	if ($name ne "."){
		if ($name ne ".."){
			my $old_name = $folder.$name;
			# my ($rootname, $extension) = split /\./, $name;
   			
   			push(@list_files, $old_name);
   			my $excel_obj = $parser->parse($old_name);
			my $worksheet = ( $excel_obj->worksheets() )[0]; #support only one worksheet
			my $check_name = $worksheet->get_cell(1,0)->value();

			my $new_name = $new_folder."check_pheno_".$check_name.".csv";

			print("Reading $old_name\n");

   			$list_files{$check_name}{'old'} = $old_name;
   			$list_files{$check_name}{'new'} = $new_name;
		}
		
	}
	
}

# Creating a list of metadata.
my @trial_name= keys %list_files;

# print Dumper(\@trial_name)."\n";

my $plots = '2020_chris_test_';
#Processing new files
my $z = 0;
my @rows;
while ($z <= scalar(@trial_name)){

	my @header = ("studyYear","studyDbId","studyName","studyDesign","locationDbId","locationName","germplasmDbId","germplasmName","germplasmSynonyms","observationLevel","observationUnitDbId","observationUnitName","replicate","blockNumber","plotNumber");
	
	my $csv = Text::CSV_XS->new( { binary => 1, auto_diag => 1, always_quote=>1, eol => "\n" } );
	open my $fh, ">", $list_files{$trial_name[$z]}{'new'} or die "new.csv $!";
	my @traits= ();
	my @rows =();
	print(" $z saving $list_files{$trial_name[$z]}{'new'} \n ");

	#Reading input csv file with pheno data. 
	my $excel_obj = $parser->parse($list_files{$trial_name[$z]}{'old'});
	my $worksheet = ( $excel_obj->worksheets())[0];
	my ($row_min, $row_max, $col_min, $col_max );

	( $row_min, $row_max ) = $worksheet->row_range();
	( $col_min, $col_max ) = $worksheet->col_range();
	
	my $i =0;
	my $j;


	while ($i < 20) {
		if($i==0){
			$j=10;
			while ($j<=$col_max){
				my $trait_name  = $worksheet->get_cell($i,$j)->value();
				push(@header, $trait_name);
				$j++;
			}
			@rows = ([@header]);
			$csv->print ($fh, $_) for @rows;

		}else{
			my $ji = $i+101;
			my $trial_name = '2020_chris_test';
			my $plot_name = $plots.$ji;

			@traits = ("","",$trial_name,"","","","","","","","",$plot_name,"","","");
			
			$j=10;
			my $trait_value;

			my $test_value;
			while($j<=$col_max){
				$test_value = $worksheet->get_cell($i,$j);
				$trait_value = $test_value ? $test_value -> value : "";
				push(@traits, $trait_value);

				$j++;
			}
			@rows = ([@traits]);
			$csv->print ($fh, $_) for @rows;

		}
		$i++;

	}

	close $fh or die "new.csv: $!";
	$z++;
}

