use strict;
use warnings;
use CXGN::Tools::File::Spreadsheet;
use CXGN::Trial::ParseUpload::Plugin::MultipleTrialDesignExcelFormat;
use CXGN::Trial::ParseUpload;

my $infile = "/home/chris/Documents/upload5.xls";


### new spreadsheet for design + phenotyping data ###
# my $spreadsheet=CXGN::Tools::File::Spreadsheet->new($infile);
# my @trial_rows = $spreadsheet->row_labels();
# my @trial_columns = $spreadsheet->column_labels();

# foreach my $data (@trial_rows){
# 	print("$data \n");
# }


my $test = CXGN::Trial::ParseUpload::Plugin::MultipleTrialDesignExcelFormat->_validate_with_plugin($infile);
my $test2 = CXGN::Trial::ParseUpload->parse($infile);