#!/usr/bin/perl

use strict;
use warnings;

use strict;
use Getopt::Long;
use CXGN::Tools::File::Spreadsheet;

use Bio::Chado::Schema;
use CXGN::DB::InsertDBH;
use Carp qw /croak/ ;
use Try::Tiny;
use DateTime;
use Pod::Usage;

use CXGN::Metadata::Schema;
use CXGN::Phenome::Schema;
use CXGN::People::Person;
use Data::Dumper;
use CXGN::Phenotypes::StorePhenotypes;
use SGN::Model::Cvterm;

use Spreadsheet::ParseExcel;

use CXGN::Trial; # add project metadata 
use CXGN::Trial::TrialCreate;

use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;
use CXGN::Stock::StockLookup;
use CXGN::Location::LocationLookup;
use CXGN::Trial::TrialDesignStore;
use Data::Dumper;
use CXGN::DB::InsertDBH;


my ( $help, $dbhost, $dbname, $sites, $types, $test, $username, $breeding_program_name, $metadata_file );
GetOptions(
    # 'i=s'        => \$infile,
    'b=s'        => \$breeding_program_name,
    'm=s'        => \$metadata_file,
    't'          => \$test,
    'user|u=s'   => \$username,
    'dbname|D=s' => \$dbname,
    'dbhost|H=s' => \$dbhost,
    'help'       => \$help,
);

my $dbpass= 'Lagoas@7';
my $basepath='/home/production/cip/';
my $temp_file = '/home/production/cip/temp.txt';

pod2usage(1) if $help;
if (!$breeding_program_name || !$username || !$dbname || !$dbhost ) {
    pod2usage( { -msg => 'Error. Missing options!'  , -verbose => 1, -exitval => 1 } ) ;
}


my $dbh = CXGN::DB::InsertDBH->new( { dbhost=>$dbhost,
				      dbname=>$dbname,
				      dbargs => {AutoCommit => 1,
					  RaiseError => 1}
	}
);

# dbh->do('SET search_path TO public,sgn');
my $q = "SELECT sp_person_id from sgn_people.sp_person where username = '$username';";
my $h = $dbh->prepare($q);
$h->execute();
my ($user_id) = $h->fetchrow_array();
if (!$user_id){
    die "Not a valid -u\n";
}

my $schema= Bio::Chado::Schema->connect(  sub { $dbh->get_actual_dbh() } ,  { on_connect_do => ['SET search_path TO  public;'] } );
my $metadata_schema = CXGN::Metadata::Schema->connect( sub { $dbh->get_actual_dbh() } , {on_connect_do => ['SET search_path TO metadata;'] } );
my $phenome_schema = CXGN::Phenome::Schema->connect( sub { $dbh->get_actual_dbh() } , {on_connect_do => ['SET search_path TO phenome;'] } );


#################
#getting the last database ids for resetting at the end in case of rolling back
################

my $last_nd_experiment_id = $schema->resultset('NaturalDiversity::NdExperiment')->get_column('nd_experiment_id')->max;
my $last_cvterm_id = $schema->resultset('Cv::Cvterm')->get_column('cvterm_id')->max;

my $last_nd_experiment_project_id = $schema->resultset('NaturalDiversity::NdExperimentProject')->get_column('nd_experiment_project_id')->max;
my $last_nd_experiment_stock_id = $schema->resultset('NaturalDiversity::NdExperimentStock')->get_column('nd_experiment_stock_id')->max;
my $last_nd_experiment_phenotype_id = $schema->resultset('NaturalDiversity::NdExperimentPhenotype')->get_column('nd_experiment_phenotype_id')->max;
my $last_phenotype_id = $schema->resultset('Phenotype::Phenotype')->get_column('phenotype_id')->max;
my $last_stock_id = $schema->resultset('Stock::Stock')->get_column('stock_id')->max;
my $last_stock_relationship_id = $schema->resultset('Stock::StockRelationship')->get_column('stock_relationship_id')->max;
my $last_project_id = $schema->resultset('Project::Project')->get_column('project_id')->max;
my $last_nd_geolocation_id = $schema->resultset('NaturalDiversity::NdGeolocation')->get_column('nd_geolocation_id')->max;
my $last_geoprop_id = $schema->resultset('NaturalDiversity::NdGeolocationprop')->get_column('nd_geolocationprop_id')->max;
my $last_projectprop_id = $schema->resultset('Project::Projectprop')->get_column('projectprop_id')->max;

my %seq  = (
    'nd_experiment_nd_experiment_id_seq' => $last_nd_experiment_id,
    'cvterm_cvterm_id_seq' => $last_cvterm_id,
    'nd_experiment_project_nd_experiment_project_id_seq' => $last_nd_experiment_project_id,
    'nd_experiment_stock_nd_experiment_stock_id_seq' => $last_nd_experiment_stock_id,
    'nd_experiment_phenotype_nd_experiment_phenotype_id_seq' => $last_nd_experiment_phenotype_id,
    'phenotype_phenotype_id_seq' => $last_phenotype_id,
    'stock_stock_id_seq'         => $last_stock_id,
    'stock_relationship_stock_relationship_id_seq'  => $last_stock_relationship_id,
    'project_project_id_seq'     => $last_project_id,
    'nd_geolocation_nd_geolocation_id_seq'          => $last_nd_geolocation_id,
    'nd_geolocationprop_nd_geolocationprop_id_seq'  => $last_geoprop_id,
    'projectprop_projectprop_id_seq'                => $last_projectprop_id,
    );


###############
#Breeding program for associating the trial/s ##
###############

my $breeding_program = $schema->resultset("Project::Project")->find( 
            {
                'me.name'   => $breeding_program_name,
		'type.name' => 'breeding_program',
	    }, 
    {
    join =>  { projectprops => 'type' } , 
    } ) ;

if (!$breeding_program) { die "Breeding program $breeding_program_name does not exist in the database. Check your input \n"; }
print "Found breeding program $breeding_program_name " . $breeding_program->project_id . "\n";

my $sp_person_id= CXGN::People::Person->get_person_by_username($dbh, $username);

#Parsing files:
my $self = shift;
my %errors;
my @error_messages;
my $parser  = Spreadsheet::ParseExcel->new();
my $excel_obj;
my $worksheet;
my $row_min;
my $row_max;
my $col_min;
my $col_max;
my @trial_columns;
my @metadata_columns;
my $trial_name = shift;
my $design_type;
my $trial_year;
my $trial_location;
my ($planting_date, $fertilizer_date, $harvest_date, $sown_plants, $harvested_plants);
my %trial_params;
my %multi_trial_data;
my @traits;
my %trial_design_hash; 
my %phen_data_by_trial;
my $accession; 
my $plot_number;
my $block_number;
my $is_a_control;
my $rep_number;
my $range_number;
my $row_number;
my $col_number;
my %phenotype_metadata;
my %parsed_data;
my $location_id;
my $trial_type;
my $trial_description;
my @input_formated;
my $input_files;
my $properties_hash;


# my @inputs = ($metadata_file, $infile);
# foreach my $fl (@inputs){
# 	read_excel_file($fl);
# 	parse_infile($fl);
# }

read_excel_file($metadata_file);
parse_infile($metadata_file);

foreach my $fl (@input_formated){
	read_excel_file($fl);
	parse_infile($fl);
	get_traits($fl);
	get_trial_data($fl);
}



print Dumper(%parsed_data);




sub read_excel_file {
	my @files = @_;
	my $read_file = $files[0];
	
	$excel_obj = $parser->parse($read_file);
	if ( !$excel_obj ) {
		push @error_messages, $parser->error();
		$errors{'error_messages'} = \@error_messages;
		# $self->_set_parse_errors(\%errors);
		return;
	}

	$worksheet = ( $excel_obj->worksheets() )[0]; #support only one worksheet
	if (!$worksheet) {
		push @error_messages, "Spreadsheet must be on 1st tab in Excel (.xls) file";
		$errors{'error_messages'} = \@error_messages;
		$self->_set_parse_errors(\%errors);
		return;
	}
	( $row_min, $row_max ) = $worksheet->row_range();
	( $col_min, $col_max ) = $worksheet->col_range();
	if (($col_max - $col_min)  < 2 || ($row_max - $row_min) < 1 ) { #must have header and at least one row of plot data
		push @error_messages, "Spreadsheet is missing header or contains no rows";
		$errors{'error_messages'} = \@error_messages;
		# $self->_set_parse_errors(\%errors);
		return;
	}
	
}


sub parse_infile {
	my $col = 0;
	my $row=1;
	my $print_name;
	my @files2 = @_;
	$excel_obj = $parser->parse($files2[0]);
	$worksheet = ( $excel_obj->worksheets() )[0]; #support only one worksheet
	while ($col <= $col_max){
		$print_name= $worksheet->get_cell(0,$col)->value();
		
		if ($files2[0] eq $metadata_file){
			push(@metadata_columns, $print_name);

		}else {
			push(@trial_columns, $print_name)
		}
				
		$col++;
	}

	if ($files2[0] eq $metadata_file){
		%trial_params = map { $_ => 1 } @metadata_columns;
	}

	print("the row max is $row_max\n");
	
	while ($row <= $row_max){
		if ($files2[0] eq $metadata_file){
			$trial_name			= $worksheet->get_cell($row,0)->value();
			$trial_description  = $worksheet->get_cell($row,1)->value();
			$trial_type 		= $worksheet->get_cell($row,2)->value();
			$trial_location 	= $worksheet->get_cell($row,3)->value();
			$trial_year  		= $worksheet->get_cell($row,4)->value();
			$design_type		= $worksheet->get_cell($row,5)->value();
			$planting_date		= $worksheet->get_cell($row,7)->value();
			$harvest_date		= $worksheet->get_cell($row,8)->value();
			$input_files		= $worksheet->get_cell($row,9)->value();

			if ($row > 0){
				print "Trial = $trial_name, design = $design_type, year = $trial_year\n";
				push(@input_formated, $input_files);
				########
			    #check that the location exists in the database
			    ########
			    print("searching for location ...\n");
			    my $location_rs =  $schema->resultset("NaturalDiversity::NdGeolocation")->search( 
				{ description => { ilike => '%' . $trial_location . '%' }, }
				);
			    if (scalar($location_rs) == 0 ) { 
				die "ERROR: location must be pre-loaded in the database. Location name = '" . $trial_location . "'\n";
			    }else{
			    	print("found location in the database!\n");
			    }
			    $location_id = $location_rs->first->nd_geolocation_id;
			    
			    ####################################################
			    ###optional params
			    
			    #trial_description defaults to $trial_name
			    my $trial_description = $trial_name;
			    
			    if(exists($trial_params{trial_description} )) { 
				$trial_description = $worksheet->get_cell($row,1)->value();
			    }
			    
			    if(exists($trial_params{planting_date} )) { 
				$planting_date = $worksheet->get_cell($row,7)->value();
				$properties_hash->{"project planting date"} = $planting_date;
			    }

			    if(exists($trial_params{harvest_date} )) { 
				$harvest_date = $worksheet->get_cell($row,8)->value();
				$properties_hash->{"project harvest date"} = $harvest_date;
			    }
			    
			    if(exists($trial_params{sown_plants} )) { 
				$sown_plants = $worksheet->get_cell($row,10)->value();;
				$properties_hash->{"project sown plants"} = $sown_plants;
			    }

			    if(exists($trial_params{harvested_plants} )) { 
				$harvested_plants = $worksheet->get_cell($row,11)->value();;
				$properties_hash->{"project harvested plants"} = $harvested_plants ;
			    }
			    #####################################################
			    $multi_trial_data{$trial_name}->{design_type} = $design_type;
			    $multi_trial_data{$trial_name}->{program} = $breeding_program->name;
			    $multi_trial_data{$trial_name}->{trial_year} = $trial_year;
			    $multi_trial_data{$trial_name}->{trial_description} = $trial_description;
			    $multi_trial_data{$trial_name}->{trial_location} = $trial_location;
			    $multi_trial_data{$trial_name}->{trial_properties} = $properties_hash;

			    $row++;
			}
			
		}
		$row++;
		
	} 

}

my @trial_rows;

sub get_trial_data {
	my @trial_file = @_;
	$excel_obj = $parser->parse($trial_file[0]);
	$worksheet = ( $excel_obj->worksheets() )[0];
	
	my $row =1;
	my $tr_rows = 1;
	
	
	while ($row <= $row_max){
		$tr_rows = $worksheet ->get_cell($row,1)->value();
		push(@trial_rows, $tr_rows);
		$row++;
	}
	
	my $i=1;
	foreach my $plot_name (@trial_rows) {
		$trial_name 	= $worksheet->get_cell($i,0)->value(); 
	    $accession 		= $worksheet->get_cell($i,2)->value();
	    $plot_number 	= $worksheet->get_cell($i,3)->value();
	    $block_number 	= $worksheet->get_cell($i,4)->value();
	    my $test_control 	= $worksheet->get_cell($i,5);
	    my $test_rep_nu 	= $worksheet->get_cell($i,6);
	    my $test_range 		= $worksheet->get_cell($i,7);
	    my $test_row_nu 	= $worksheet->get_cell($i,8);
	    my $test_col_nu 	= $worksheet->get_cell($i,9);


	    $is_a_control = $test_control ? $test_control -> value : undef;
	    $rep_number = $test_rep_nu ? $test_rep_nu -> value : undef;
	    $range_number = $test_range ? $test_range -> value : undef;
	    $row_number = $test_row_nu ? $test_row_nu -> value : undef;
	    $col_number = $test_col_nu ? $test_col_nu -> value : undef;

	    if (!$plot_number) {
		$plot_number = 1;
		use List::Util qw(max);
		my @keys = (keys %{ $trial_design_hash{$trial_name} } );
		my $max = max( @keys );
		if ( $max ) {
		    $max++;
		    $plot_number = $max ;
		}
	    }

	    
	    $trial_design_hash{$trial_name}{$plot_number}->{plot_number} = $plot_number;
	    $trial_design_hash{$trial_name}{$plot_number}->{stock_name} = $accession;
	    $trial_design_hash{$trial_name}{$plot_number}->{plot_name} = $plot_name;
	    $trial_design_hash{$trial_name}{$plot_number}->{block_number} = $block_number;
	    $trial_design_hash{$trial_name}{$plot_number}->{rep_number} = $rep_number;
	    $trial_design_hash{$trial_name}{$plot_number}->{is_a_control} = $is_a_control;
	    $trial_design_hash{$trial_name}{$plot_number}->{range_number} = $range_number;
	    $trial_design_hash{$trial_name}{$plot_number}->{row_number} = $row_number;
	    $trial_design_hash{$trial_name}{$plot_number}->{col_number} = $col_number;

	    push( @{ $multi_trial_data{$trial_name}->{plots} } , $plot_name );

	    # print Dumper(\%multi_trial_data);
	    $i++;
	}
	return %trial_design_hash;

}

sub get_traits{
	my @trial_file = @_;
	my $i = 0;
	foreach my $name (@trial_columns){
		if ($i>9){
			push(@traits, $name);
		}
		$i++;
	}

	$excel_obj = $parser->parse($trial_file[0]);
	$worksheet = ( $excel_obj->worksheets() )[0];



	# my $timestamp=''; # add here timestamp value if storing those 
	my $col = 10;
	my $row = 1;
	my $c1 = $worksheet->get_cell($row,0);
	$trial_name = $c1 ? $c1->value:undef;

	my $plot_name;
	my $phen_value;
	my $trait_string;
    foreach $trait_string (@traits) {
    	while($row <= $row_max){
    		my $test_phen 	= $worksheet->get_cell($row, $col);
    		$plot_name 	= $worksheet->get_cell($row,1)->value();
    		$phen_value	= $test_phen ? $test_phen -> value : undef;
    		$phen_data_by_trial{$trial_name}{$plot_name}{$trait_string} = [$phen_value];
			
			$row++;
    	}
		$col++;
    }

    my $date = localtime();

	####required phenotypeprops###
	$phenotype_metadata{'archived_file'} = $metadata_file;
	$phenotype_metadata{'archived_file_type'} = "spreadsheet phenotype file";
	$phenotype_metadata{'operator'} = $username;
	$phenotype_metadata{'date'} = $date;

}

my $coderef= sub  {
    foreach $trial_name (keys %multi_trial_data ) {
    	$multi_trial_data{$trial_name}->{design_type} = $design_type;
		$multi_trial_data{$trial_name}->{program} = $breeding_program->name;
	    $multi_trial_data{$trial_name}->{trial_year} = $trial_year;
	    $multi_trial_data{$trial_name}->{trial_description} = $trial_description;
	    $multi_trial_data{$trial_name}->{trial_location} = $trial_location;
	    $multi_trial_data{$trial_name}->{trial_properties} = $properties_hash;

    	my $test = $multi_trial_data{$trial_name}->{trial_location};

    	print "LOCATION FOR THIS TRIAL: $test id:$location_id user_id $user_id\n";
	    
	    my $trial_create = CXGN::Trial::TrialCreate->new({
	    chado_schema      => $schema,
	    dbh               => $dbh,
	    design_type       => $multi_trial_data{$trial_name}->{design_type} ||  'RCBD',
	    design            => $trial_design_hash{$trial_name}, #$multi_trial_data{$trial_name}->{design},
	    program           => $breeding_program->name(),
	    trial_year        => $multi_trial_data{$trial_name}->{trial_year} ,
	    trial_description => $multi_trial_data{$trial_name}->{trial_description},
	    trial_location    => $multi_trial_data{$trial_name}->{trial_location},
	    trial_name        => $trial_name,
	    operator		  => $username,
	    user_id			  => $user_id
							 });

		try {
		    $trial_create->save_trial();
		} catch {
		    print STDERR "ERROR SAVING TRIAL!\n";
		};


		# my @plots = @{ $multi_trial_data{$trial_name}->{plots} };
		my @plots = @{ $multi_trial_data{$trial_name}->{plots} };
		print "TRIAL NAME = $trial_name\n";
		my %parsed_data = %{$phen_data_by_trial{$trial_name}} ; #hash of keys = plot name, values = hash of trait strings as keys
		foreach my $pname (keys %parsed_data) {
		    print "PLOT = $pname\n";
		    my %trait_string_hash = %{$parsed_data{$pname}};
		  
		    foreach my $trait_string (keys %trait_string_hash ) { 
			print "trait = $trait_string\n";
			print "value =  " . %{$trait_string_hash{$trait_string}}[0] . "\n";
		    }
		}
	
		my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new(
		    bcs_schema=>$schema,
		    dbuser=>$username,
		    dbhost=>$dbhost,
		    dbpass=>$dbpass,
		    dbname=>$dbname,
		    basepath=> $basepath,
		    temp_file_nd_experiment_id=>$temp_file,
		    metadata_schema=>$metadata_schema,
		    phenome_schema=>$phenome_schema,
		    user_id=>$sp_person_id,
		    stock_list=>\@plots,
		    trait_list=>\@traits,
		    values_hash=>\%parsed_data,
		    has_timestamps=>0,
		    overwrite_values=>0,
		    metadata_hash=>\%phenotype_metadata,
		    # nd_geolocation_id => $location_id,
		    );
		
		
		#validate, store, add project_properties from %properties_hash
		
		#store the phenotypes
		my ($verified_warning, $verified_error) = $store_phenotypes->verify();
		print "Verified phenotypes. warning = $verified_warning, error = $verified_error\n";
		my $stored_phenotype_error = $store_phenotypes->store();
		print "Stored phenotypes. Error = $stored_phenotype_error \n";
		
    }
};

try {
    $schema->txn_do($coderef);
    if (!$test) { print "Transaction succeeded! Commiting project and its metadata \n\n"; }
} catch {
    # Transaction failed
    foreach my $value ( sort  keys %seq ) {
        my $maxval= $seq{$value} || 0;
        if ($maxval) { $dbh->do("SELECT setval ('$value', $maxval, true)") ;  }
        else {  $dbh->do("SELECT setval ('$value', 1, false)");  }
    }
    die "An error occured! Rolling back  and reseting database sequences!" . $_ . "\n";
};






