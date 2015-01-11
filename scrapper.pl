#!/usr/bin/perl

# scrapper.pl

# any bugs, suggestions, or questions
# hello@blainem.com

use strict;
use warnings;
use Getopt::Long;
use Switch;

# load Minecraft modules
use File::Basename qw(dirname);
use Cwd qw(abs_path);
use lib dirname(dirname abs_path $0) . '/quote_scrapper/lib';
use Scrapper::Control;

my $VERSION = '0.0.1';


### get opts
my ($control, $help);
GetOptions (
    "control=s" => \$control,
);
usage() && exit 1 unless ($control);


### control
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
