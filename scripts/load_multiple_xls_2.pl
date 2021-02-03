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
    'm=s'        => \$metadata_file,
    't'          => \$test,
    'user|u=s'   => \$username,
    'dbname|D=s' => \$dbname,
    'dbhost|H=s' => \$dbhost,
    'help'       => \$help,
);

my $dbpass= 'secretpw';
my $basepath='/home/chris/cxgn/sgn';
my $temp_file = '/tmp/delete_nd_experiment_ids.txt';

# pod2usage(1) if $help;
# if (!$username || !$dbname || !$dbhost || $metadata_file ) {
#     pod2usage( { -msg => 'Error. Missing options!'  , -verbose => 1, -exitval => 1 } ) ;
# }


my $dbh = CXGN::DB::InsertDBH->new( { dbhost=>$dbhost,
				      dbname=>$dbname,
				      dbargs => {AutoCommit => 1,
					  RaiseError => 1}
	}
);


my $schema= Bio::Chado::Schema->connect(  sub { $dbh->get_actual_dbh() } ,  { on_connect_do => ['SET search_path TO  public;'] } );
my $metadata_schema = CXGN::Metadata::Schema->connect( sub { $dbh->get_actual_dbh() } , {on_connect_do => ['SET search_path TO metadata;'] } );
my $phenome_schema = CXGN::Phenome::Schema->connect( sub { $dbh->get_actual_dbh() } , {on_connect_do => ['SET search_path TO phenome;'] } );


#################
#getting the last database ids for resetting at the end in case of rolling back
################

my $last_nd_experiment_id;
my $last_cvterm_id;

my ($last_nd_experiment_project_id, $last_nd_experiment_stock_id,$last_nd_experiment_phenotype_id, $last_phenotype_id, $last_stock_id, $last_stock_relationship_id, $last_project_id, $last_nd_geolocation_id,$last_geoprop_id, $last_projectprop_id); 

my %seq  = ();



my $sp_person_id= CXGN::People::Person->get_person_by_username($dbh, $username);

#Parsing files:
my $self = shift;
my $breeding_program;
my %errors;
my @error_messages;
my $parser  = Spreadsheet::ParseExcel->new();
my $excel_obj;
my $worksheet;
my $row_min;
my $row_max;
my $col_min;
my $col_max;
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
my @trials;
my ($plot_width, $plot_length, $field_size);
my $count =0;
my @trial_rows;
my $timestamp;


read_excel_file($metadata_file);
parse_infile($metadata_file);


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
	
		
}


sub parse_infile {
	my $col = 0;
	
	my $print_name;
	my @files2 = @_;

	

	print Dumper(@files2)."\n";

	$excel_obj = $parser->parse($files2[0]);
	$worksheet = ( $excel_obj->worksheets() )[0]; #support only one worksheet

	my ($row_min, $row_max, $col_min, $col_max );

	( $row_min, $row_max ) = $worksheet->row_range();
	( $col_min, $col_max ) = $worksheet->col_range();

	print("the row max is $row_max\n");

	while ($col <= $col_max){
		$print_name= $worksheet->get_cell(0,$col)->value();
		push(@metadata_columns, $print_name);
		$col++;
	}

	if ($files2[0] eq $metadata_file){
		%trial_params = map { $_ => 1 } @metadata_columns;
	}

	

	my $ref=1;
	while ($ref <= $row_max){
		if ($files2[0] eq $metadata_file){

			$excel_obj = $parser->parse($files2[0]);
			$worksheet = ( $excel_obj->worksheets() )[0]; #support only one worksheet

			$trial_name			= $worksheet->get_cell($ref,0)->value();
			print("Now calling $ref $trial_name ... \n");
			$trial_description  = $worksheet->get_cell($ref,1)->value();
			$trial_type 		= $worksheet->get_cell($ref,2)->value();
			$trial_location 	= $worksheet->get_cell($ref,3)->value();
			$trial_year  		= $worksheet->get_cell($ref,4)->value();
			$design_type		= $worksheet->get_cell($ref,5)->value();
			$breeding_program_name 	= $worksheet->get_cell($ref,6)->value();
			my $t_planting_date		= $worksheet->get_cell($ref,7);
			my $t_harvest_date		= $worksheet->get_cell($ref,8);
			my $t_plot_width		= $worksheet->get_cell($ref,9);
			my $t_plot_length		= $worksheet->get_cell($ref,10);
			my $t_sown_plants		= $worksheet->get_cell($ref,11);
			# $field_size			= $worksheet->get_cell($ref,12)->value();

			$planting_date = $t_planting_date ? $t_planting_date -> value : undef;
			$harvest_date = $t_harvest_date ? $t_harvest_date -> value : undef;
			$plot_width = $t_plot_width ? $t_plot_width -> value : undef;
			$plot_length = $t_plot_length ? $t_plot_length -> value : undef;
			$sown_plants = $t_sown_plants ? $t_sown_plants -> value : undef;

			###############
			#Breeding program for associating the trial/s ##
			###############

			$breeding_program = $schema->resultset("Project::Project")->find( 
			            {
			                'me.name'   => $breeding_program_name,
					'type.name' => 'breeding_program',
				    }, 
			    {
			    join =>  { projectprops => 'type' } , 
			    } ) ;

			if (!$breeding_program) { die "Breeding program $breeding_program_name does not exist in the database. Check your input \n"; }
			print "Found breeding program $breeding_program_name " . $breeding_program->project_id . "\n";



			
			
			push(@trials, $trial_name);

			#Grebing list of files to open;
			$input_files = $worksheet->get_cell($ref, 13)->value();
			push(@input_formated, $input_files);
			print "Input = $input_files Trial = $trial_name, design = $design_type, year = $trial_year\n";
			
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
		    
		    ###optional params

		    $properties_hash->{"project sown plants"} = $sown_plants;

		   
		    %multi_trial_data = ();
		    #####################################################
		    $multi_trial_data{$trial_name}->{design_type} = $design_type;
		    $multi_trial_data{$trial_name}->{program} = $breeding_program->name;
		    $multi_trial_data{$trial_name}->{trial_year} = $trial_year;
		    $multi_trial_data{$trial_name}->{trial_description} = $trial_description;
		    $multi_trial_data{$trial_name}->{trial_location} = $trial_location;
		    $multi_trial_data{$trial_name}->{planting_date} = $planting_date;
		    $multi_trial_data{$trial_name}->{harvest_date} = $harvest_date;
		    $multi_trial_data{$trial_name}->{plot_width} = $plot_width;
		    $multi_trial_data{$trial_name}->{plot_length} = $plot_length;

		    run_store($input_files);

		    
		    $ref++;

		}
		
	} 


}


sub run_store{
	my @readFile = @_;

	print("\nThe input is $readFile[0]\n");

	$last_nd_experiment_id = $schema->resultset('NaturalDiversity::NdExperiment')->get_column('nd_experiment_id')->max;
	$last_cvterm_id = $schema->resultset('Cv::Cvterm')->get_column('cvterm_id')->max;

	$last_nd_experiment_project_id = $schema->resultset('NaturalDiversity::NdExperimentProject')->get_column('nd_experiment_project_id')->max;
	$last_nd_experiment_stock_id = $schema->resultset('NaturalDiversity::NdExperimentStock')->get_column('nd_experiment_stock_id')->max;
	$last_nd_experiment_phenotype_id = $schema->resultset('NaturalDiversity::NdExperimentPhenotype')->get_column('nd_experiment_phenotype_id')->max;
	$last_phenotype_id = $schema->resultset('Phenotype::Phenotype')->get_column('phenotype_id')->max;
	$last_stock_id = $schema->resultset('Stock::Stock')->get_column('stock_id')->max;
	$last_stock_relationship_id = $schema->resultset('Stock::StockRelationship')->get_column('stock_relationship_id')->max;
	$last_project_id = $schema->resultset('Project::Project')->get_column('project_id')->max;
	$last_nd_geolocation_id = $schema->resultset('NaturalDiversity::NdGeolocation')->get_column('nd_geolocation_id')->max;
	$last_geoprop_id = $schema->resultset('NaturalDiversity::NdGeolocationprop')->get_column('nd_geolocationprop_id')->max;
	$last_projectprop_id = $schema->resultset('Project::Projectprop')->get_column('projectprop_id')->max;

	%seq  = (
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

	

	
	$excel_obj = $parser->parse($readFile[0]);
	$worksheet = ( $excel_obj->worksheets())[0];
	my ($row_min, $row_max, $col_min, $col_max );

	( $row_min, $row_max ) = $worksheet->row_range();
	( $col_min, $col_max ) = $worksheet->col_range();

	my @trial_columns = ();
	my @traits = ();
	my $tr_header;
	my $col = 0;

	while ($col <= $col_max ){
		$tr_header = $worksheet ->get_cell(0,$col)->value();
		push(@trial_columns, $tr_header);
		if ($col>9){
			push(@traits, $tr_header);
		}

		$col++;
		}
	
	my $row =1;
	my $tr_rows = 1;
	
	@trial_rows = ();
	while ($row <= $row_max){
		$tr_rows = $worksheet ->get_cell($row,1)->value();
		push(@trial_rows, $tr_rows);
		$row++;
	}

	my $i=1;
	# print("THE TRIAL is $trial_name\n");
	
	my %trial_design_hash = ();
	foreach my $plot_name (@trial_rows) {
		# print("The trial is $trial_name and plot is $plot_name\n");
		$trial_name 	= $worksheet->get_cell($i,0)->value(); 
	    $accession 		= $worksheet->get_cell($i,2)->value();
	    $plot_number 	= $worksheet->get_cell($i,3)->value();
	    my $test_block_number 	= $worksheet->get_cell($i,4);
	    my $test_control 	= $worksheet->get_cell($i,5);
	    my $test_rep_nu 	= $worksheet->get_cell($i,6);
	    my $test_range 		= $worksheet->get_cell($i,7);
	    my $test_row_nu 	= $worksheet->get_cell($i,8);
	    my $test_col_nu 	= $worksheet->get_cell($i,9);
	    my $plt = $worksheet->get_cell($i,0);
	    my $plt1;
	   
		$block_number = $test_block_number ? $test_block_number->value : undef;	   
	    $is_a_control = $test_control ? $test_control -> value : undef;
	    $rep_number = $test_rep_nu ? $test_rep_nu -> value : undef;
	    $range_number = $test_range ? $test_range -> value : undef;
	    $row_number = $test_row_nu ? $test_row_nu -> value : undef;
	    $col_number = $test_col_nu ? $test_col_nu -> value : undef;
	    $plt1 = $plt ? $plt -> value : undef;

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
	    push( @{ $multi_trial_data{$trial_name}{plots} } , $plot_name );
	    $i++;
    }
    # print Dumper(\%multi_trial_data)."\n";

    #####################################
    #Getting traits name and pheno data
    #####################################
    $col = 10;
	$row = 1;
	my $plot_name;
	my $phen_value;
	my $trait_string;
	%phen_data_by_trial = ();
	
	$timestamp='';
    foreach $trait_string (@traits) {
    	while($row <= $row_max){
    		my $test_phen 	= $worksheet->get_cell($row, $col);
    		$plot_name 	= $worksheet->get_cell($row,1)->value();
    		$phen_value	= $test_phen ? $test_phen -> value : undef;
    		$phen_data_by_trial{$trial_name}{$plot_name}{$trait_string} = [ $phen_value, $timestamp ];
			$row++;
    	}
		$col++;
    }

    my $date = localtime();

    my %phenotype_metadata = ();

	####required phenotypeprops###
	$phenotype_metadata{'archived_file'} = $metadata_file;
	$phenotype_metadata{'archived_file_type'} = "spreadsheet phenotype file";
	$phenotype_metadata{'operator'} = $username;
	$phenotype_metadata{'date'} = $date;


	my $coderef= sub  {
		    
	    $multi_trial_data{$trial_name}->{design_type} = $design_type;
	    $multi_trial_data{$trial_name}->{program} = $breeding_program->name;
	    $multi_trial_data{$trial_name}->{trial_year} = $trial_year;
	    $multi_trial_data{$trial_name}->{trial_type} = $trial_type;
	    $multi_trial_data{$trial_name}->{trial_description} = $trial_description;
	    $multi_trial_data{$trial_name}->{trial_location} = $trial_location;
	    $multi_trial_data{$trial_name}->{trial_properties} = $properties_hash;
	    $multi_trial_data{$trial_name}->{planting_date} = $planting_date;
	    $multi_trial_data{$trial_name}->{harvest_date} = $harvest_date;

	    print Dumper(\%phenotype_metadata)."\n";
	    my $trial_create;
	    my $test1 = $multi_trial_data{$trial_name}->{plot_width};
	    
	    if(!$planting_date && !$plot_width){
	    	$trial_create = CXGN::Trial::TrialCreate->new({
			    chado_schema      => $schema,
			    dbh               => $dbh,
			    design_type       => $multi_trial_data{$trial_name}->{design_type} ||  'RCBD',
			    design            => $trial_design_hash{$trial_name}, #$multi_trial_data{$trial_name}->{design},
			    program           => $breeding_program->name(),
			    trial_year        => $multi_trial_data{$trial_name}->{trial_year},
			    trial_description => $multi_trial_data{$trial_name}->{trial_description},
			    trial_location    => $multi_trial_data{$trial_name}->{trial_location},
		        # planting_date     => $multi_trial_data{$trial_name}->{planting_date},
		        # harvest_date      => $multi_trial_data{$trial_name}->{harvest_date},
		        # plot_width		  => $multi_trial_data{$trial_name}->{plot_width},
		        # plot_length		  => $multi_trial_data{$trial_name}->{plot_length},
		        # field_size		  => $field_size,
			    trial_name        => $trial_name,
			    operator		  => $username,
			    user_id			  => $sp_person_id
			});
		}elsif(!$plot_width){
			$trial_create = CXGN::Trial::TrialCreate->new({
			    chado_schema      => $schema,
			    dbh               => $dbh,
			    design_type       => $multi_trial_data{$trial_name}->{design_type} ||  'RCBD',
			    design            => $trial_design_hash{$trial_name}, #$multi_trial_data{$trial_name}->{design},
			    program           => $breeding_program->name(),
			    trial_year        => $multi_trial_data{$trial_name}->{trial_year},
			    trial_description => $multi_trial_data{$trial_name}->{trial_description},
			    trial_location    => $multi_trial_data{$trial_name}->{trial_location},
		        planting_date     => $multi_trial_data{$trial_name}->{planting_date},
		        harvest_date      => $multi_trial_data{$trial_name}->{harvest_date},
		        # plot_width		  => $multi_trial_data{$trial_name}->{plot_width},
		        # plot_length		  => $multi_trial_data{$trial_name}->{plot_length},
		        # field_size		  => $field_size,
			    trial_name        => $trial_name,
			    operator		  => $username,
			    user_id			  => $sp_person_id
			});

		}elsif(!$planting_date){
			$trial_create = CXGN::Trial::TrialCreate->new({
			    chado_schema      => $schema,
			    dbh               => $dbh,
			    design_type       => $multi_trial_data{$trial_name}->{design_type} ||  'RCBD',
			    design            => $trial_design_hash{$trial_name}, #$multi_trial_data{$trial_name}->{design},
			    program           => $breeding_program->name(),
			    trial_year        => $multi_trial_data{$trial_name}->{trial_year},
			    trial_description => $multi_trial_data{$trial_name}->{trial_description},
			    trial_location    => $multi_trial_data{$trial_name}->{trial_location},
		        # planting_date     => $multi_trial_data{$trial_name}->{planting_date},
		        # harvest_date      => $multi_trial_data{$trial_name}->{harvest_date},
		        plot_width		  => $multi_trial_data{$trial_name}->{plot_width},
		        plot_length		  => $multi_trial_data{$trial_name}->{plot_length},
		        # field_size		  => $field_size,
			    trial_name        => $trial_name,
			    operator		  => $username,
			    user_id			  => $sp_person_id
			});
		}
		

		try {
		    $trial_create->save_trial();
		} catch {
		    print STDERR "ERROR SAVING TRIAL!\n";

		};
				##########################

		my $project = $schema->resultset("Project::Project")->find_or_create( 
	    {
	        name => $trial_name,
	        description => $multi_trial_data{$trial_name}->{trial_description},
	    } ) ;

	    if ( $trial_type ) {
		    my $project_type_cvterm = $schema->resultset('Cv::Cvterm')->create_with(
			{ name   => $trial_type,
			  cv     => 'project_type' ,
			  db     => 'local',
			  dbxref => $trial_type,
			});
			    
			    $project->create_projectprops( { $trial_type => $project_type_cvterm->cvterm_id } , { cv_name => "project_type" } );
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

	; #hash of keys = plot name, values = hash of trait strings as keys
	 #    foreach my $pname (keys %parsed_data) {
	 #        print "PLOT = $pname\n";
	 #        my %trait_string_hash = %{$parsed_data{$pname}};
	      
	 #        foreach my $trait_string (keys %trait_string_hash ) { 
		#         print "trait = $trait_string = ";
		#         print %{$trait_string_hash{$trait_string}}[0] . "\n";
		        
	 #        }
	 #    }

	 #    my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new(
		# 		    basepath=>$basepath,
		# 		    dbhost=>$dbhost,
		# 		    dbname=>$dbname,
		# 		    dbuser=>$username,
		# 		    dbpass=>$dbpass,
		# 		    temp_file_nd_experiment_id=>$temp_file,
		# 		    bcs_schema=>$schema,
		# 		    metadata_schema=>$metadata_schema,
		# 		    phenome_schema=>$phenome_schema,
		# 		    user_id=>$sp_person_id,
		# 		    stock_list=>\@plots,
		# 		    trait_list=>\@traits,
		# 		    values_hash=>\%parsed_data,
		# 		    has_timestamps=>$timestamp,
		# 		    metadata_hash=>\%phenotype_metadata,
		# 		);

  #       my ($verified_warning, $verified_error) = $store_phenotypes->verify();
		# print "Verified phenotypes. warning = $verified_warning, error = $verified_error\n";
		# my $stored_phenotype_error = $store_phenotypes->store();
		# print "Stored phenotypes. Error = $stored_phenotype_error \n";
	store_phenotypes();
    $count++;

}


sub store_phenotypes {
	$timestamp = 0;
	my $timestamp_included;
	if ($timestamp eq 1){
	    $timestamp_included = 1;
	}

	# my $parser = CXGN::Phenotypes::ParseUpload->new();
	my $subdirectory = "spreadsheet_csv_phenotype_upload";
	my $validate_type = "spreadsheet phenotype file";
	my $metadata_file_type = "spreadsheet csv phenotype file";
	# my $upload = $opt_i;
	my $data_level = 'plots';

	my $time = DateTime->now();
	my $tmstamp = $time->ymd()."_".$time->hms();

	my $date = localtime();

	my %phenotype_metadata;
	$phenotype_metadata{'archived_file'} = $metadata_file;
	$phenotype_metadata{'archived_file_type'} = "spreadsheet phenotype file";
	$phenotype_metadata{'operator'} = $username;
	$phenotype_metadata{'date'} = $date;

	$multi_trial_data{$trial_name}->{design_type} = $design_type;
    $multi_trial_data{$trial_name}->{program} = $breeding_program->name;
    $multi_trial_data{$trial_name}->{trial_year} = $trial_year;
    $multi_trial_data{$trial_name}->{trial_type} = $trial_type;
    $multi_trial_data{$trial_name}->{trial_description} = $trial_description;
    $multi_trial_data{$trial_name}->{trial_location} = $trial_location;
    $multi_trial_data{$trial_name}->{trial_properties} = $properties_hash;
    $multi_trial_data{$trial_name}->{planting_date} = $planting_date;
    $multi_trial_data{$trial_name}->{harvest_date} = $harvest_date;
    $phen_data_by_trial{$trial_name};

    print Dumper(\%multi_trial_data)."\n";

    print Dumper(\%phen_data_by_trial)."\n";

	print STDERR "Trial name is $trial_name.\n";

	my %parsed_data;
	my @plots = @{ $multi_trial_data{$trial_name}->{plots} };
	%parsed_data = %{$phen_data_by_trial{$trial_name}};

	print Dumper(\%parsed_data)."\n";

	# if ($parsed_file && !$parsed_file->{'error'}) {
	#     %parsed_data = %{$parsed_file->{'data'}};
	#     @plots = @{$parsed_file->{'units'}};
	#     @traits = @{$parsed_file->{'variables'}};
	# }

	my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new(
	    basepath=>$basepath,
	    dbhost=>$dbhost,
	    dbname=>$dbname,
	    dbuser=>$username,
	    dbpass=>$dbpass,
	    temp_file_nd_experiment_id=>$temp_file,
	    bcs_schema=>$schema,
	    metadata_schema=>$metadata_schema,
	    phenome_schema=>$phenome_schema,
	    user_id=>$sp_person_id,
	    stock_list=>\@plots,
	    trait_list=>\@traits,
	    values_hash=>\%parsed_data,
	    has_timestamps=>$timestamp_included,
	    metadata_hash=>\%phenotype_metadata,
	);

	my ($verified_warning, $verified_error) = $store_phenotypes->verify();
	if ($verified_error) {
	    die $verified_error."\n";
	}
	# if ($verified_warning && !$opt_o) {
	#     die $verified_warning."\n";
	# }

	print STDERR "Done validating. Now storing\n";

	my ($stored_phenotype_error, $stored_Phenotype_success) = $store_phenotypes->store();
	if ($stored_phenotype_error) {
	    die $stored_phenotype_error."\n";
	}
	print STDERR $stored_Phenotype_success."\n";
	print STDERR "Script Complete.\n";

}





