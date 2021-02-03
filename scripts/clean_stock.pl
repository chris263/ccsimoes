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

our ($opt_H, $opt_D, $opt_i, $opt_t);
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

my $schema= Bio::Chado::Schema->connect(  sub { $dbh->get_actual_dbh() } );
$dbh->do('SET search_path TO public,sgn');

print STDERR "Connecting to DBI schema...\n";

# open(my $F, '<:encoding(UTF-8)', $opt_i) or die "Could not open file '$opt_i' $!";

my @stock_ids = ();

my $coderef = sub {
	my $sql = "select uniquename, stock_id from stock left join nd_experiment_stock using (stock_id) where uniquename ilike 'kasese%' and stock.type_id = 76393;";
	my $sth = $dbh->prepare($sql);
	$sth->execute();
	while (my @stock = $sth->fetchrow_array) {
		push @stock_ids, $stock[1];
	}
	foreach my $line (@stock_ids){
		print("The stock is $line \n");
	}
	
	my $number = scalar(@stock_ids);
	foreach my $stock_id (@stock_ids) { 
		my $sql2 = "delete from stock where stock_id in (select stock_id from stock left join nd_experiment_stock using (stock_id) where stock_id= (?) and stock.type_id = 76393);";
		my $sth2 = $dbh->prepare($sql2);
		print("deleting stock number $number ... \n");
		$sth2->execute($stock_id);
		$number--;
	}
};

my $transaction_error;
try {
    $schema->txn_do($coderef);
} catch {
    $transaction_error =  $_;
};

if ($transaction_error) {
    print STDERR "Transaction error sdeleting terms: $transaction_error\n";
} else {
    print STDERR "Script Complete.\n";
}

