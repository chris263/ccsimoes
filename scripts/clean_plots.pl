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
use Getopt::Long;
use DBI;
use Try::Tiny;
use DBIx::Class;
use Bio::Chado::Schema;
use CXGN::DB::InsertDBH;

my ($opt_H, $opt_D, $opt_f);
GetOptions(
    'H=s'        => \$opt_H, #folder with all raw files
    'D=s'        => \$opt_D, #this is the output folder
    'i=s'        => \$opt_f #this is the input with metadata
    # 'm=s'		 => \$metadata_parse #this the output file
 );


my $dbh = CXGN::DB::InsertDBH->new({ 
	dbhost=>$opt_H,
	dbname=>$opt_D,
	dbargs => {AutoCommit => 1, RaiseError => 1}
});

my $schema= Bio::Chado::Schema->connect(  sub { $dbh->get_actual_dbh() } );
$dbh->do('SET search_path TO public,sgn');

print STDERR "Connecting to DBI schema...\n";

 
my $coderef = sub {

	my $rs = $schema->resultset('Stock::Stock')->search({'uniquename' => {ilike => $opt_f.'%'}});


	foreach my $stock ($rs->all()) {
    	my $stockid = $stock->stock_id();
    	my $uniquename = $stock->uniquename();

		my $sql2 = "delete from stock where stock_id in (select stock_id from stock left join nd_experiment_stock using (stock_id) where stock_id=? and stock.type_id = 76393);";
		my $sth2 = $dbh->prepare($sql2);

		$sth2->execute($stockid);
		print("plot $uniquename deleted! \n");
		
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

