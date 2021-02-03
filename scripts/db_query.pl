use strict;
use warnings;
use Getopt::Std;
use DBI;
use Try::Tiny;
use DBIx::Class;
use Bio::Chado::Schema;
use CXGN::DB::InsertDBH;

our ($opt_H, $opt_D, $opt_t);
getopts('H:D:t');

# my $file = shift;

print "Password for $opt_H / $opt_D: \n";
my $pw = <>;
chomp($pw);

my $dbh = CXGN::DB::InsertDBH->new({ 
	dbhost=>$opt_H,
	dbname=>$opt_D,
	dbargs => {AutoCommit => 1, RaiseError => 1}
});

my $schema= Bio::Chado::Schema->connect(  sub { $dbh->get_actual_dbh() } );
$dbh->do('SET search_path TO public,sgn');

print STDERR "Connecting to database...\n";

my @query = {'2016%','2015%','2014%'};

foreach my $q (@query){
	my @plot_ids = ();
	my $sql = "BEGIN; select uniquename, stock_id from stock left join nd_experiment_stock using (stock_id) where uniquename ilike ? and nd_experiment_id  is null and stock.type_id = 76393;";
	my $sth = $dbh->prepare($sql);
	$sth->execute($q);
	while (my @row = $sth->fetchrow_array) {
		push @plot_ids, $row[1];
		print "Plot id is: $row[1]\n";
	}
}