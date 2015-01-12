#!/usr/bin/perl

# scrapper.pl

use strict;
use warnings;
use LWP::Simple;

my $VERSION = '0.0.1';

use Data::Dumper;  # testing


# get book from project gutenberg

# open it up
open (my $raw_fh, "<", "pg19445.txt")
    or die "cannot open book.txt: $!";

# extract and format
my ($newline, $title, $author);
foreach (<$raw_fh>) {

    # remove newline
    #$_ = s/\r\n//;

    # extract title and author
    if (/Title/) {
        $title = $_;
        $title =~ s/Title: //;
    }
    if (/Author/) {
        $author = $_;
        $author =~ s/Author: //;
    }

    print $_;
}

# close the book
close ($raw_fh);
