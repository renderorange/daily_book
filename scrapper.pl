#!/usr/bin/perl

# scrapper.pl

use strict;
use warnings;

my $VERSION = '0.0.1';

use Data::Dumper;  # testing


# get book from project gutenberg

# open it up
open (my $raw_fh, "<", "pg19445.txt")
    or die "cannot open book.txt: $!";

# extract, format, and store
my ($title, $author);
my ($_head, $_body, $_footer) = (0, 0, 0);
my (@header, @body, @footer);
foreach (<$raw_fh>) {

    # check location within book
    if ($_body != 1 && $_footer != 1) {
        $_head = 1;
    }
    if (/\*\*\* START OF THIS PROJECT/) {
        $_head = 0;
        $_body = 1;
        next;  # we don't want to store this line
    }
    if (/\*\*\* END OF THIS PROJECT/) {
        $_body = 0;
        $_footer = 1;
        next;  # we don't want to store this line either
    }

    # clean up the text
    $_ =~ s/^\s+//;   # remove whitespace at the start of lines
    $_ =~ s/\\//;     # remove backslash
    $_ =~ s/  / /;    # correct double spacing
    $_ =~ s/\s+$/ /;  # correct spacing at the end of lines

    # process head
    if ($_head == 1) {
        # grap title and author
        if (/Title/) {
            $title = $_;
            $title =~ s/Title: //;
        }
        if (/Author/) {
            $author = $_;
            $author =~ s/Author: //;
        }
        # store head
        push (@header, $_);
    }

    # process body
    if ($_body == 1) {
        # store body
        push (@body, $_);
    }

    # process footer
    if ($_footer == 1) {
        # store footer
        push (@footer, $_);
    }

}

# [testing]
print "### header ###\n";
print Dumper @header;
print "\n\n";
print "### body ###\n";
print Dumper @body;
print "\n\n";
print "### footer ###\n";
print Dumper @footer;
print "\n\n";

# close the book
close ($raw_fh);
