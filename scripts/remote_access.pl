use strict;
use warnings;
use Net::OpenSSH;

my $ssh = Net::OpenSSH->new('production@sweetpotatobase.org');
$ssh->error and die "Couldn't establish SSH connection: ". $ssh->error;

$ssh->system("ls /home/ccs263") or die "remote command failed: " . $ssh->error;