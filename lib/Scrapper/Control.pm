package Scrapper::Control;

use strict;
use warnings;

use Exporter qw(import);
our @EXPORT = qw(start stop);

use Data::Dumper;  # testing

sub start {
    print "start\n";
}

sub stop {
    print "stop\n";
}

1;
