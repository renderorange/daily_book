#!/usr/bin/perl

# quote.pl

use strict;
use warnings;

use Getopt::Long;
use LWP::Simple;
use IO::Uncompress::Bunzip2 qw(bunzip2 $Bunzip2Error);
use Net::Twitter::Lite::WithAPIv1_1;

my $VERSION = '0.0.6';


### variables and settings
# twitter oauth
my $consumer_key = '***REMOVED***';
my $consumer_secret = '***REMOVED***';
my $access_token = '***REMOVED***';
my $access_token_secret = '***REMOVED***';


### pre-processing
# get commandline options
my ($twitter, $verbose);
GetOptions ("twitter"  => \$twitter,
            "verbose"  => \$verbose)
    or print_help() and exit;
if ($twitter || $verbose || ($verbose and ! $twitter)) {
    ;
} else {
    print_help() and exit;
}

# check if catalog exists
my $catalog = 'catalog.rdf';
if (-e "$catalog") {
    # check date
    my $mtime = (stat $catalog)[9];
    my $current_time = time;
    my $diff = $current_time - $mtime;
    # if older than one day
    if ($diff > 86400) {
        # delete the old catalog
        unlink("$catalog") or warn "unable to delete old catalog: $!";
        get_catalog();
    }
} else {
    get_catalog();
}

# open the catalog
open (my $catalog_fh, "<", "$catalog") or die "cannot open catalog: $!";

# read and parse for book text links
my @files;
while (<$catalog_fh>) {
    if ($_ =~ m/(pg[\d]+\.txt\.utf8)/) {  # match the pg naming convention
        push (@files, $1);
    }
}

# close the catalog
close ("$catalog_fh");


### begin processing
# loop here, since a book isn't guaranteed to find a quote each time
while (1) {  # main while loop 
# grab random book number and build the link
my $file = @files[rand @files];
my $number = $file;
$number =~ s/\.txt\.utf8//;
$number =~ s/pg//;
my $page_link = "gutenberg.org/ebooks/$number";
my $book_link = "gutenberg.org/cache/epub/$number/$file";

# download the ebook
my $rc = getstore("http://$book_link", "$file");
if (is_error($rc)) {
    warn "there was an error downloading the book: $rc";
    next;
}


### open the book, cleanup, and store
open (my $raw_fh, "<", "$file") or die "unable to open book txt: $!";

# read, format, and store
my ($title, $author);
my ($_head, $_body, $_footer) = (0, 0, 0);
my (@header, @body, @footer);

while (<$raw_fh>) {
    # check location within book
    if ($_body != 1 && $_footer != 1) {
        $_head = 1;
    }
    if (/The New McGuffey/) {
        warn "ebook is The New McGuffey Reader\n";
        last;
    }
    if (/Language: /) {
        if ($_ !~ /English/) {
            warn "ebook isn't in English\n";
            last;
        }
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

# close the book and delete it
close ($raw_fh);
unlink("$file") or warn "unable to delete book txt: $!";


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

# process through paragraphs, filtering out undesired strings, finding proper length
my $quote;
foreach (@paragraphs) {
    if (! defined $_) {  # shouldn't have to do this, change it later
        next;
    } elsif ($_ =~ /Page [\d]/) {
        next;
    } elsif ($_ =~ /©/) {
        next; 
    } elsif (/\[ILLUSTRATION\:/) {
        next;
    } elsif ($_ =~ /End of the Project Gutenberg EBook/) {
        next;
    } elsif ($_ =~ /^[\[]/) {  # paragraph starts with [, example being 6388
        next;
    } elsif ($_ =~ /[:\;] $/) {  # paragraph ends with semicolon (due to formatting issue from earlier in the script)
        next;
    } elsif ($_ !~ /^["]/) {  # only take lines that start with a quote (this has yielded the best results against false positive)
        next;
    } elsif (length $_ > 90 && length $_ < 119) {
        $quote = $_;
    }
}

# verify a quote was found
if (! $quote) {
    warn "no quote matching the length was found\n";
    next;
}


### print out final stuff
print "title: $title\n" .
      "author: $author\n" .
      "\n" .
      "$quote$page_link\n" .
      "\n";


### twitter
# instantiate object
my $twitter = Net::Twitter::Lite::WithAPIv1_1->new(
    consumer_key        => "$consumer_key",
    consumer_secret     => "$consumer_secret",
    access_token        => "$access_token",
    access_token_secret => "$access_token_secret",
    ssl                 => 1,
);

# post
if ($twitter == 1) {
    print "posting to Twitter\n";
    my $result = $twitter->update("$quote$page_link");
    print "\n";
    last;
} else {
    last;
}  # main while loop 

### subs
sub print_help {
    print "usage: ./quote.pl\n" .
          "-m|--manual 1234\t downloads and searches book with specified book number\n" .
          "-t|--twitter\t\t post to twitter\n" .
          "-v|--verbose\t\t display verbose output\n" .
          "\n";
}

sub get_catalog {
    # download and store the new catalog archive
    my $rc = getstore('http://www.gutenberg.org/feeds/catalog.rdf.bz2', 'catalog.rdf.bz2');
    if (is_error($rc)) {
        die "there was an error downloading the book catalog: $rc";
    }
    undef($rc);
    # unpack the catalog file
    bunzip2 'catalog.rdf.bz2' => "$catalog" or die "bunzip2 failed: $Bunzip2Error\n";
    # delete the archived version
    unlink('catalog.rdf.bz2') or warn "unable to delete catalog archive: $!";
}

