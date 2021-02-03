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
my $trial_name;
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

# my @inputs = ($metadata_file, $infile);
# foreach my $fl (@inputs){
# 	read_excel_file($fl);
# 	parse_infile($fl);
# }

read_excel_file($metadata_file);
parse_infile($metadata_file);

foreach my $fl (@input_formated){
	print("The input is $fl\n");
	read_excel_file($fl);
	parse_infile($fl);
	
	
}




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

	print Dumper(\@files2)."\n";



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
	
	$row = 1;
	while ($row <= $row_max){
		if ($files2[0] eq $metadata_file){

			$trial_name = ();

			$trial_name			= $worksheet->get_cell($row,0)->value();
			print("The row is $row TRIAL is $trial_name\n");
			$trial_description  = $worksheet->get_cell($row,1)->value();
			$trial_type 		= $worksheet->get_cell($row,2)->value();
			$trial_location 	= $worksheet->get_cell($row,3)->value();
			$trial_year  		= $worksheet->get_cell($row,4)->value();
			$design_type		= $worksheet->get_cell($row,5)->value();
			$planting_date		= $worksheet->get_cell($row,7)->value();
			$harvest_date		= $worksheet->get_cell($row,8)->value();
			# $plot_width			= $worksheet->get_cell($row,9)->value();
			# $plot_length		= $worksheet->get_cell($row,10)->value();
			# $sown_plants		= $worksheet->get_cell($row,11)->value();
			# $field_size			= $worksheet->get_cell($row,12)->value();

		

			$design_type = 'CRD';
			
			push(@trials, $trial_name);

			#Grebing list of files to open;
			$input_files = $worksheet->get_cell($row, 13)->value();
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
		    
		    get_traits($input_files);
	        get_trial_data($input_files);
	        test_run();
		    $row++;

		}else{
			$row++;
		}
		
	} 


}




sub get_trial_data {
	my @trial_file = @_;
	$excel_obj = $parser->parse($trial_file[0]);
	$worksheet = ( $excel_obj->worksheets() )[0];
	
	( $row_min, $row_max ) = $worksheet->row_range();
	( $col_min, $col_max ) = $worksheet->col_range();

	my $row =1;
	my $tr_rows = 1;

	
	@trial_rows = ();
	while ($row <= $row_max){
		$tr_rows = $worksheet ->get_cell($row,1)->value();
		push(@trial_rows, $tr_rows);
		$row++;
	}

	
	
	
	# print("THE TRIAL IS $trn\n");
	my $trn = $trials[$count];
	my $i=1;
	print("Passing through $trn\n");
	# undef $multi_trial_data{$trn}{plots};
	foreach my $plot_name (@trial_rows) {
		print("The plot is $plot_name\n");
		$trial_name 	= $worksheet->get_cell($i,1)->value(); 
	    $accession 		= $worksheet->get_cell($i,2)->value();
	    $plot_number 	= $worksheet->get_cell($i,3)->value();
	    $block_number 	= $worksheet->get_cell($i,4)->value();
	    my $test_control 	= $worksheet->get_cell($i,5);
	    my $test_rep_nu 	= $worksheet->get_cell($i,6);
	    my $test_range 		= $worksheet->get_cell($i,7);
	    my $test_row_nu 	= $worksheet->get_cell($i,8);
	    my $test_col_nu 	= $worksheet->get_cell($i,9);
	    my $plt = $worksheet->get_cell($i,0);
	    my $plt1;

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
	    # print("The plot is $plt1\n");

    	$trial_design_hash{$trn}{$plot_number}->{plot_number} = $plot_number;
	    $trial_design_hash{$trn}{$plot_number}->{stock_name} = $accession;
	    $trial_design_hash{$trn}{$plot_number}->{plot_name} = $plot_name;
	    $trial_design_hash{$trn}{$plot_number}->{block_number} = $block_number;
	    $trial_design_hash{$trn}{$plot_number}->{rep_number} = $rep_number;
	    $trial_design_hash{$trn}{$plot_number}->{is_a_control} = $is_a_control;
	    $trial_design_hash{$trn}{$plot_number}->{range_number} = $range_number;
	    $trial_design_hash{$trn}{$plot_number}->{row_number} = $row_number;
	    $trial_design_hash{$trn}{$plot_number}->{col_number} = $col_number;
	    push( @{ $multi_trial_data{$trn}{plots} } , $plot_name );
	    $i++;
    }
    # print Dumper(\%multi_trial_data)."\n";
    $count++;

	return %trial_design_hash;

}

my $timestamp;

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
	my $c1 = $worksheet->get_cell($row,1);
	$trial_name = $c1 ? $c1->value:undef;

	my $plot_name;
	my $phen_value;
	my $trait_string;
	
    foreach $trait_string (@traits) {
    	while($row <= $row_max){
    		my $test_phen 	= $worksheet->get_cell($row, $col);
    		$plot_name 	= $worksheet->get_cell($row,0)->value();
    		$phen_value	= $test_phen ? $test_phen -> value : undef;
    		$phen_data_by_trial{$trial_name}{$plot_name}{$trait_string} = [ $phen_value, $timestamp ];
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

sub test_run {
	my $coderef= sub  {
	    foreach my $trial_name (keys %multi_trial_data ) {
	        $multi_trial_data{$trial_name}->{design_type} = $design_type;
	        $multi_trial_data{$trial_name}->{program} = $breeding_program->name;
	        $multi_trial_data{$trial_name}->{trial_year} = $trial_year;
	        $multi_trial_data{$trial_name}->{trial_type} = $trial_type;
	        $multi_trial_data{$trial_name}->{trial_description} = $trial_description;
	        $multi_trial_data{$trial_name}->{trial_location} = $trial_location;
	        $multi_trial_data{$trial_name}->{trial_properties} = $properties_hash;
	        $multi_trial_data{$trial_name}->{planting_date} = $planting_date;
	        $multi_trial_data{$trial_name}->{harvest_date} = $harvest_date;
	      
	        print Dumper(\%multi_trial_data)."\n";
	    	my $trial_create = CXGN::Trial::TrialCreate->new({
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

			# print Dumper(\%multi_trial_data)."\n";
			my @plots = @{ $multi_trial_data{$trial_name}->{plots} };
		    print "TRIAL NAME = $trial_name\n";
		  #   my %parsed_data = %{$phen_data_by_trial{$trial_name}} ; #hash of keys = plot name, values = hash of trait strings as keys
		  #   foreach my $pname (keys %parsed_data) {
		  #       print "PLOT = $pname\n";
		  #       my %trait_string_hash = %{$parsed_data{$pname}};
		      
		  #       foreach my $trait_string (keys %trait_string_hash ) { 
		  #       print "trait = $trait_string = ";
		  #       print %{$trait_string_hash{$trait_string}}[0] . "\n";
		  #       }
		  #   }
			
				# my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new(
				#     bcs_schema=>$schema,
				#     dbuser=>$username,
				#     dbhost=>$dbhost,
				#     dbpass=>$dbpass,
				#     dbname=>$dbname,
				#     basepath=> $basepath,
				#     temp_file_nd_experiment_id=>$temp_file,
				#     metadata_schema=>$metadata_schema,
				#     phenome_schema=>$phenome_schema,
				#     user_id=>$sp_person_id,
				#     stock_list=>\@plots,
				#     trait_list=>\@traits,
				#     values_hash=>\%parsed_data,
				#     has_timestamps=>$timestamp,
				#     overwrite_values=>0,
				#     metadata_hash=>\%phenotype_metadata,
				#     # nd_geolocation_id => $location_id,
				#     );
				
				
				# #validate, store, add project_properties from %properties_hash
				
				# #store the phenotypes
				# my ($verified_warning, $verified_error) = $store_phenotypes->verify();
				# print "Verified phenotypes. warning = $verified_warning, error = $verified_error\n";
				# my $stored_phenotype_error = $store_phenotypes->store();
				# print "Stored phenotypes. Error = $stored_phenotype_error \n";
				
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

}






