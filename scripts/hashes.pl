#!/usr/bin/perl

#!/usr/bin/perl
use strict;
use warnings;
 
use Data::Dumper qw(Dumper);
 
my %grades;
$grades{"Foo Bar"}{chris}{Mathematics}   = 97;
$grades{"Foo Bar"}{chris}{Literature}    = 67;
$grades{"Peti Bar"}{chris}{Literature}   = 88;
$grades{"Peti Bar"}{dadi}{Mathematics}   = 82;
$grades{"Peti Bar"}{dadi}{Art}           = 99;

my %parse_data = %{$grades{"Peti Bar"}{dadi}};
 
print Dumper \%parse_data;
print "----------------\n";
 
# foreach my $name (sort keys %grades) {
#     foreach my $subject (keys %{ $grades{$name} }) {
#         print "$name, $subject: $grades{$name}{$subject}\n";
#     }
# }