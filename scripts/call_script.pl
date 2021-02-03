use warnings;
use strict;
use CXGN::DB::InsertDBH;
use Bio::Chado::Schema;
use CXGN::Metadata::Schema;
use CXGN::Phenome::Schema;
use Data::Dumper;
use DBI;
use Text::CSV;
use Getopt::Long;


my ($username, $dbhost, $dbname, $infile );
GetOptions(
    'i=s'        => \$infile,
    'user|u=s'   => \$username,
    'dbname|D=s' => \$dbname,
    'dbhost|H=s' => \$dbhost
);


my @trial_names=();
open(my $fh, '<', $infile) or die "Could not open '$infile' $!\n";
while (my $line = <$fh>) {
  chomp $line;
  push @trial_names, $line;
  # print "The trial is $line\n";
}
close $fh;

my $dbh = CXGN::DB::InsertDBH->new( { dbhost=> $dbhost,
				      dbname=>$dbname,
              dbpass=>'postgres',
				      dbargs => {AutoCommit => 1,
						 RaiseError => 1}
				    }
    );

print STDERR "Connecting to database...\n";
my $schema= Bio::Chado::Schema->connect(  sub { $dbh->get_actual_dbh() } );
my $metadata_schema = CXGN::Metadata::Schema->connect( sub { $dbh->get_actual_dbh() });
my $phenome_schema = CXGN::Phenome::Schema->connect( sub { $dbh->get_actual_dbh() });

my @trial_ids=();
foreach my $name (@trial_names) {
    my $trial = $schema->resultset("Project::Project")->find( { name => $name });
    if (!$trial) { print STDERR "Trial $name not found. Skipping...\n"; next; }
    push @trial_ids, $trial->project_id();
    print "Trial $name found with id ". $trial->project_id()."\n";
}

foreach my $name (@trial_ids){
	my $call = `perl /home/ccs263/delete_trials.pl -H $dbhost -D $dbname -U postgres -P Eo0vair1 -i $name -b /home/production -r /home/production/temp_file_nd_experiment_id`;
	print $call;
}


 

 

 
