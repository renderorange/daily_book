#!/usr/bin/perl

# scrapper.pl

use strict;
use warnings;
use Getopt::Long;
use Switch;
use LWP::Simple;

my $VERSION = '0.0.1';


### check for and run prelim control settings
# get opts
my ($control);
GetOptions (
    "control=s" => \$control,
);
usage() && exit 1 unless ($control);

# control
switch ($control) {
    case 'start'  { start() }
    case 'stop'   { stop() }
}


### subs
sub usage {
    print "usage: scrapper.pl [-c start|stop]\n" .
          "\n" .
          "options:\n" .
          "-c | --control [start|stop]\n" .
          "\n";
}

sub start {
    print "start\n";
}

sub stop {
    print "stop\n";
}
