

use strict;
use warnings;
use Spreadsheet::WriteExcel;

print("everything is good so far\n");

my $file_save = 'teste_31.xls';

open my $fh, '>', $file_save or die "Failed to open filehandle: $!";
 
my $workbook  = Spreadsheet::WriteExcel->new($fh);
my $worksheet = $workbook->add_worksheet();

my $item = "chris";

my $n=0;
while ($n <= 9) {
	$worksheet->write(1,$n, "$item $n");
	$n++;
	print("working $n ...\n");
}

$workbook->close();
binmode STDOUT;
print $file_save;


# for (my $r=0;$r<@$colums;$r++) {
#     for (my $c=0;$c<@{$colums->[$r]}) {
#         $worksheet->write($r,$c,$colums->[$r]->[$c]);
#     } 