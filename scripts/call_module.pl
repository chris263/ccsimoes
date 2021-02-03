#!/usr/bin/perl

use strict;
use warnings;

use CXGN::Trial::TrialCreate;
use CXGN::DB::InsertDBH;
use Moose;
use Bio::Chado::Schema;
use CXGN::DB::InsertDBH;


my $dbhost = "localhost";
my $dbname = "fixture";


my $dbh = CXGN::DB::InsertDBH->new( { dbhost=>$dbhost,
				      dbname=>$dbname,
				      dbargs => {AutoCommit => 1,
						 RaiseError => 1}
				  }
				    );


my $schema= Bio::Chado::Schema->connect(  sub { $dbh->get_actual_dbh() } ,  { on_connect_do => ['SET search_path TO  public;'] } );

my $file_name = '/home/chris/Documents/upload5.xls';

# my $store_phenotypes = CXGN::Trial::TrialCreate->save_trial(
# 		    file_name=>$file_name
# 		    );




try {
	my $test_name = CXGN::Trial::TrialCreate->trial_name_already_exists({
		trial_name => "chris_2021_01"
	}
	);
	
		} catch {
		    print STDERR "ERROR SAVING TRIAL!\n";
	};

# my $project = 
# my $trial_id = 206;
# my $trial_name = "chris_2021_01";
# my $geolocation = "Ejura";
# my $trial_id

# my $trial_design_store = CXGN::Trial::TrialDesignStore->new({
#         bcs_schema => $chado_schema,
#         trial_id => $trial_id, # $project->project_id(),
#         trial_name => $trial_name,
#         nd_geolocation_id => $location_id, #$geolocation->nd_geolocation_id(),
#         nd_experiment_id => $breeding_program_id, #$nd_experiment->nd_experiment_id(),
#         design_type => $design_type,
#         design => \%design,
#         is_genotyping => $self->get_is_genotyping(),
#         is_analysis => $self->get_is_analysis(),
#         is_sampling_trial => $self->get_is_sampling_trial(),
#         new_treatment_has_plant_entries => $self->get_trial_has_plant_entries,
#         new_treatment_has_subplot_entries => $self->get_trial_has_subplot_entries,
#         operator => $self->get_operator,
#         trial_stock_type => $self->get_trial_stock_type(),
#     });