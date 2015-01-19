#!/usr/bin/perl

# twitter_post.pl

use strict;
use warnings;

# additionally requires
# Net::OAuth and Mozilla::CA

use Net::Twitter::Lite::WithAPIv1_1;
my $twitter = Net::Twitter::Lite::WithAPIv1_1->new(
    consumer_key        => '***REMOVED***',
    consumer_secret     => '***REMOVED***',
    access_token        => '***REMOVED***',
    access_token_secret => '***REMOVED***',
    ssl                 => 1,
);

use Data::Dumper;

my $result = $twitter->update('Hello one last time!');
print Dumper $result;
