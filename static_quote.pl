#!/usr/bin/perl

# static_quote.pl

use strict;
use warnings;

use Data::Dumper;


### config settings
my $number = '12345';
my $file = "pg$number.txt.utf8";
my $page_link = "gutenberg.org/ebooks/$number";
my $book_link = "gutenberg.org/cache/epub/$number/$file";


### open the book, cleanup, and store
open (my $raw_fh, "<", "$file") or die "cannot open book txt: $!";

# read, format, and store
my ($title, $author);
my ($_head, $_body, $_footer) = (0, 0, 0);
my (@header, @body, @footer);

foreach (<$raw_fh>) {

    # check location within book
    if ($_body != 1 && $_footer != 1) {
        $_head = 1;
    }
    # check for 'The New McGuffey'
    if (/The New McGuffey/) {
        die "The New McGuffey Reader found; I don't know how to read those yet\n";
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
    $_ =~ s/  / /g;   # correct double spacing
    $_ =~ s/\s+$/ /;  # correct spacing at the end of lines

    # store head
    if ($_head == 1) {
        push (@header, $_);
    }

    # store body
    if ($_body == 1) {
        push (@body, $_);
    }

    # store footer
    if ($_footer == 1) {
        push (@footer, $_);
    }

}

# close the book
close ($raw_fh);


### process the data
foreach (@header) {
    # grab title and author
    if (/Title:/) {
        $title = $_;
        $title =~ s/Title: //;
    }
    if (/Author:/) {
        $author = $_;
        $author =~ s/Author: //;
    }
}

my ($build_variable, @paragraphs);
foreach (@body) {
    # assemble paragraphs
    if ($_ ne '') {  # blank indicates end of paragraph
        $build_variable .= $_;
    } else {
        push (@paragraphs, $build_variable);
        $build_variable = ();  # clear out the $build_variable
    }
}

# grab out matching length quote
my $quote;
foreach (@paragraphs) {
    if (! defined $_) {  # shouldn't have to do this, change it later
        next;
    } elsif (length $_ == 118) {
        $quote = $_;
    }
}


### print out final stuff
print "title: $title\n" .
      "author: $author\n" .
      "\n" .
      "$quote$page_link\n" .
      "\n";
