#!/usr/bin/perl

=head1 NAME

clean_plot.pl - delete plots not linked to a project

=head1 DESCRIPTION

perl clean_plots.pl -H [host] -D [dbname] -t (for testing)


=head1 AUTHOR

chris simoes <ccs263@cornell.edu>

=cut

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

# print "Password for $opt_H / $opt_D: \n";
# my $pw = <>;
# chomp($pw);


my $dbh = CXGN::DB::InsertDBH->new({ 
	dbhost=>$opt_H,
	dbname=>$opt_D,
	dbargs => {AutoCommit => 1, RaiseError => 1}
});


print "Type the query term: ";
my $query = <STDIN>;
chomp $query;

my $final_query = $query.'%';

my $schema= Bio::Chado::Schema->connect(  sub { $dbh->get_actual_dbh() } );
$dbh->do('SET search_path TO public,sgn');

print STDERR "Connecting to DBI schema...\n";


my @plot_ids = ();

my $coderef = sub {
	# my $sql = "BEGIN; select uniquename, stock_id from stock left join nd_experiment_stock using (stock_id) where nd_experiment_id = 76182 and stock.type_id = 76393;";
	my $sql = "BEGIN; select uniquename, stock_id from stock where uniquename ilike ? and stock.type_id = 76393;";
	my $sth = $dbh->prepare($sql);
	$sth->execute($final_query);
	while (my @row = $sth->fetchrow_array) {
		push @plot_ids, $row[1];
	}

	foreach my $plot_id (@plot_ids) { 
		my $sql2 = "delete from stock where stock_id=? and stock.type_id = 76393;";
		my $sth2 = $dbh->prepare($sql2);
		print("deleting plot id $plot_id ... ");
		$sth2->execute($plot_id);
		print("plot deleted! \n");
		
	}
};

my $transaction_error;
try {
    $schema->txn_do($coderef);
} catch {
    $transaction_error =  $_;
};

if ($transaction_error) {
    print STDERR "Transaction error storing terms: $transaction_error\n";
} else {
    print STDERR "Script Complete.\n";
}

