#!/usr/bin/perl -w
use strict;

use DBI;

# Replace datasource_name with the name of your data source.
# Replace database_username and database_password
# with the SQL Server database username and password.
# my $data_source = q/dbi:ODBC:db4.sgn.cornell.edu/;
# my $user = q/postgres/;
# my $password = q/Eo0vair1/;

# Connect to the data source and get a handle for that connection.
my $dbh = DBI->connect("DBI:Pg:dbname=sandbox_batatabase;host=db4.sgn.cornell.edu", "postgres", "Eo0vair1");
# my $dbh = DBI->connect($data_source, $user, $password)
    # or die "Can't connect to database";

# This query generates a result set with one record in it.
my $sql = "SELECT 1 AS test_col";

# Prepare the statement.
my $sth = $dbh->prepare($sql)
    or die "Can't prepare statement: $DBI::errstr";

# Execute the statement.
$sth->execute();

# Print the column name.
print "$sth->{NAME}->[0]\n";

# Fetch and display the result set value.
while ( my @row = $sth->fetchrow_array ) {
   print "@row\n";
}

# Disconnect the database from the database handle.
$dbh->disconnect;