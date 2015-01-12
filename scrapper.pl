#!/usr/bin/perl

# scrapper.pl

use strict;
use warnings;
use LWP::Simple;

my $VERSION = '0.0.1';

use Data::Dumper;  # testing


# get book from project gutenberg

# open it up
open (my $book_fh, "<", "pg19445.txt")
    or die "cannot open book.txt: $!";

# extract some meta things
my ($title, $author);
foreach (<$book_fh>) {
    if (/Title/) {
        chomp($title = $_);
        $title =~ s/Title: //;
        print "$title\n";
    }
    if (/Author/) {
        chomp($author = $_);
        $author =~ s/Author: //;
        print "$author\n";
    }
}
print "$title by $author\n";

# close the book
close ($book_fh);
