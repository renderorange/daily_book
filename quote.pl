#!/usr/bin/perl

# quote.pl

use strict;
use warnings;

use LWP::Simple;
use IO::Uncompress::Bunzip2 qw(bunzip2 $Bunzip2Error);

my $VERSION = '0.0.2';

use Data::Dumper;  # testing
my $testing = 0;   # testing, 1 for verbose output


### gather pre-processing information
# [todo] create log and append
# [todo] download new catalog everyday
# check if catalog file exists in dir already
# check date
# if date older than a day, redownload

# download and store the book index
#my $rc = getstore('http://www.gutenberg.org/feeds/catalog.rdf.bz2', 'catalog.rdf.bz2');
#if (is_error($rc)) {
#    die "there was an error downloading the book catalog: $rc";
#}

# unpack the catalog file
#bunzip2 'catalog.rdf.bz2' => 'catalog.rdf'
#    or die "bunzip2 failed: $Bunzip2Error\n";

# delete the archived version
#unlink('catalog.rdf.bz2') or warn "unable to delete catalog archive: $!";

# open the catalog
open (my $catalog_fh, "<", "catalog.rdf") or die "cannot open catalog: $!";

# read and parse for book text links
my @files;
foreach (<$catalog_fh>) {
    if ($_ =~ m/(pg[\d]+\.txt\.utf8)/) {  # match the pg naming convention
        push (@files, $1);
    }
}

# close the catalog
close ("$catalog_fh");

# grab random book number and build the link
my $file = @files[rand @files];
my $number = $file;
$number =~ s/\.txt\.utf8//;
$number =~ s/pg//;
my $page_link = "gutenberg.org/ebooks/$number";
my $book_link = "gutenberg.org/cache/epub/$number/$file";


### open the book, cleanup, and store
open (my $raw_fh, "<", "pg19445.txt") or die "cannot open book txt: $!";

# read, format, and store
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
    if (/Title/) {
        $title = $_;
        $title =~ s/Title: //;
    }
    if (/Author/) {
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


### [testing]
if ($testing) {
    print "###\n" .
          "# $title\n" .
          "# by $author\n" .
          "\n";
    print "### header ###\n";
    print Dumper @header;
    print "\n\n";
    print "### body ###\n";
    print Dumper @body;
    print "\n\n";
    print "### footer ###\n";
    print Dumper @footer;
    print "\n\n";
    print "### paragraphs ###\n";
    print Dumper @paragraphs;
    print "\n\n";
    print "### quote ###";
    print Dumper $quote;
    print "\n\n";
}
