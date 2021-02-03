use strict;
use warnings;
use Getopt::Long;
use CXGN::DB::InsertDBH;
use Bio::Chado::Schema;
use DBI;

my ($dbhost, $dbname);
GetOptions(
    'H=s'        => \$dbhost,
    'D=s'        => \$dbname #this is the output folder
 );

if(!$dbhost || !$dbname){ die "no dbname nor dbhost \n"};

my $dbh = CXGN::DB::InsertDBH->new( { 
	dbhost=> $dbhost,
	dbname=>$dbname,
	dbargs => {AutoCommit => 1, RaiseError => 1}
});

print STDERR "Connecting to database...\n";
my $schema= Bio::Chado::Schema->connect(  sub { $dbh->get_actual_dbh() } );
