use Getopt::Std;
use Data::Dumper;
use Carp qw /croak/ ;
use Pod::Usage;
use Spreadsheet::ParseExcel;
use Bio::Chado::Schema;
use CXGN::DB::InsertDBH;
use Try::Tiny;

our ($opt_H, $opt_D, $opt_i, $opt_t);

getopts('H:D:i:t');

if (!$opt_H || !$opt_D || !$opt_i) {
    pod2usage(-verbose => 2, -message => "Must provide options -H (hostname), -D (database name), -i (input file)\n");
}

my $dbhost = $opt_H;
my $dbname = $opt_D;
my $parser   = Spreadsheet::ParseExcel->new();
my $excel_obj = $parser->parse($opt_i);

my $dbh = CXGN::DB::InsertDBH->new({ 
	dbhost=>$dbhost,
	dbname=>$dbname,
	dbargs => {AutoCommit => 1, RaiseError => 1}
});

my $schema= Bio::Chado::Schema->connect(  sub { $dbh->get_actual_dbh() } );
$dbh->do('SET search_path TO public,sgn');

my $worksheet = ( $excel_obj->worksheets() )[0]; #support only one worksheet
my ( $row_min, $row_max ) = $worksheet->row_range();
my ( $col_min, $col_max ) = $worksheet->col_range();

my $coderef = sub {

	print("old_name\t|Plot Id\t|New Name\n");

	for my $row ( 0 .. $row_max ) {
		my $old_name = $worksheet->get_cell($row, 0)->value();
		my $new_plotname = $worksheet->get_cell($row, 1)->value();
		
        my $old_stock = $schema->resultset('Stock::Stock')->find({ uniquename => $old_name });
        my $old_id = $old_stock->stock_id();
        
		print("$old_name\t|$old_id\t|$new_plotname\n");
		
		my $pq = "UPDATE stock SET uniquename= ?, name= ? WHERE stock_id= ? ";
	    my $ph = $dbh->prepare($pq);
	    $ph->execute($new_plotname, $new_plotname, $old_id);    
		
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



