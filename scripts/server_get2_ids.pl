use strict;
use warnings;
use CXGN::DB::InsertDBH;
use Bio::Chado::Schema;
use CXGN::Metadata::Schema;
use CXGN::Phenome::Schema;
use Data::Dumper;
use DBI;

use Text::CSV;
my $csv = Text::CSV->new({ sep_char => ',' });
 
my $file = "trials_delete_prod_cip.csv";

my @trial_names=();
open(my $fh, '<', $file) or die "Could not open '$file' $!\n";
while (my $line = <$fh>) {
  chomp $line;
  push @trial_names, $line;
}
close $fh;

my $dbh = CXGN::DB::InsertDBH->new( { dbhost=>'db5.sgn.cornell.edu',
				      dbname=>'cxgn_batatabase',
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
    print "it is working!\n";
}


open my $fh3, '>', "ids_prod.txt" or die $!;
foreach my $row3 (@trial_ids) {
    print $fh3 join("\t", $row3) . "\n";
}
close $fh3;
