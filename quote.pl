#!/usr/bin/perl

# quote.pl

use utf8;
use strict;
use warnings;

use local::lib;
use Getopt::Long;
use LWP::Simple;
use Net::Twitter::Lite::WithAPIv1_1;


### pre-processing
# get commandline options
my ($twitter, $silent, $manual, $help);
GetOptions ("twitter"   => \$twitter,
            "silent"    => \$silent,
            "manual=i"  => \$manual, 
            "help"      => \$help)
    or print_help() and exit;
if ($silent && !$twitter || $manual && $silent || $help) {  # these options don't particularly make much sense run together, also, if help
    print_help() and exit;
}

# variables and settings
my $rc = '.quote.rc';
my %config;
my $twitter_object;

# testing mode                                 # with testing mode set to 1, quote.pl will load a different rc file
my $testing_mode = 1;                          # this is meant to test post to a twitter account without followers
if ($testing_mode) { $rc = '.quote.rc.dev'; }  # hard coding it here is a failsafe for me, as opposed to running from commandline

# if we're using twitter
if ($twitter) {
    # verify the rc is there
    if (! -e "$rc") {  # if rc is not present
        print "$rc is not present\n" .
              "please see github.com/renderorange/daily_book for setup details\n\n";
        exit 1;
    }
    # load and verify config from rc file
    open (my $config_fh, "<", "$rc") or print "unable to open $rc: $!\n\n" and exit 1;
        while (<$config_fh>) {   # [TODO] the verification below could stand to be more specific, verifying values as well
            if (/^#/) { next; }  # filter out comments
            my ($key, $value) = split (/:/);  # [TODO] add trim of whitespace, run through map on $_, through the split list, also add chomp to it too
            chomp ($value);
            # verify config contains what's expected
            if ($key !~ /^account$|^consumer_key$|^consumer_secret$|^access_token$|^access_token_secret$/) {
                print "$rc doesn't appear to contain what's needed\n" .
                      "please see github.com/renderorange/daily_book for setup details\n\n";
                exit 1;
            }
            $config{$key} = $value;  # $config{'account'} = values can be accessed like so
        }
    # close the config
    close ($config_fh);

    # instantiate twitter object for API access
    $twitter_object = Net::Twitter::Lite::WithAPIv1_1->new(
        consumer_key        => "$config{consumer_key}",
        consumer_secret     => "$config{consumer_secret}",
        access_token        => "$config{access_token}",
        access_token_secret => "$config{access_token_secret}",
        ssl                 => 1,
    );
}

# print header
if (!$silent) {
    print "quote.pl\n\n";
    if ($twitter && $testing_mode) {
        print "testing mode is on\n" .
              "account: $config{'account'}\n\n";
        sleep 5;
    }
    if (!$manual) {
        print "finding a quote, just a moment\n" .
              "for more information, please see quote.log\n\n";
    }
}

# check if index exists
my $index = 'index.txt';
if (! -e "$index") {
    print "$index doesn't exist\n" .
          "please see github.com/renderorange/daily_book for setup details\n\n";
    exit 1;
}

# get the info from the catalog
# [TODO] the usage of chained ands may be creating too much dependency on loggers success, before print and exit. it could be an issue. should be redone
open (my $index_fh, "<", "$index") or logger('fatal', "cannot open catalog: $!") and print "cannot open catalog: $!\n\n" and exit 1;
    # read and parse for book text links
    my @files;
    while (<$index_fh>) {
        if ($_ =~ m/(pg[\d]+\.txt\.utf8)/) {  # match the pg naming convention
            push (@files, $1);
        }
    }
# close the catalog
close ("$index_fh");


### begin processing
# loop here, since a book isn't guaranteed to find a quote each time
my ($number, $file);
MAIN: while (1) {

    if (!$manual) {  # [TODO] should flip this logic around, if ($manual)
        # grab random book number and build the link
        $file = @files[rand @files];
        $number = $file;
    } else {
        # build the links manually
        $file = "pg$manual.txt.utf8";
        $number = $manual;
    }

    $number =~ s/\.txt\.utf8//;
    $number =~ s/pg//;
    my $page_link = "www.gutenberg.org/ebooks/$number";

    # build the book link
    my $book_link = "gutenberg.pglaf.org";  # downloading from the mirror
    for (0..(length($number)-2)) {  # because 0 is the first member of substring
        $book_link .= "/" . substr($number, $_, 1);
    }
    $book_link .= "/$number/$number.txt";

    # download the ebook
    my $rc = getstore("http://$book_link", "$file");
    if ($manual && is_error($rc)) {
        logger('warn', "error: $rc while downloading - $file");
        print "error: $rc while downloading - $file\n\n";
        exit 1;
    } elsif (is_error($rc)) {
        logger('warn', "error: $rc while downloading - $file");
        next;
    }

    # open the book, cleanup, and store
    open (my $raw_fh, "<:encoding(UTF-8)", "$file") or logger('fatal', "unable to open book txt: $!") and print "unable to open book txt: $!\n\n" and exit 1;

    # read, format, and store
    my ($title, $author);
    my ($_head, $_body, $_foot) = (0, 0, 0);
    my (@header, @body, @footer);

    while (<$raw_fh>) {
        # gutenberg formats their ebooks with section markers
        # and since each section contains different kinds of information which we want
        # as we read the book by line, we track the markers based on the section of the book we're at
        if ($_body == 0 && $_foot == 0) {  # we'll only match this inside the head
            $_head = 1;                    # or at the very start of the book
        }
        # [TODO] create logic here for skipping these checks, unless in head
        if (/The New McGuffey/) {
            logger('info', "ebook is The New McGuffey Reader - $file");
            close ($raw_fh);
            unlink("$file");
            if ($manual) {
                print "ebook is The New McGuffey Reader\n\n";
                exit 1;
            }
            next MAIN;  # The New McGuffey Reader failed the most in testing, so I just skip it altogether.
        }
        if (/Language: /) {
            if ($_ !~ /English/) {
                logger('info', "ebook isn't in English - $file");
                close ($raw_fh);
                unlink("$file");
                if ($manual) {
                    print "ebook isn't in English\n\n";
                    exit 1;
                }
                next MAIN;  # [DID YOU KNOW] sometimes ebooks are labeled English, but read creole ¯\_(ツ)_/¯
            }
        }
        if (/\*\*\* START OF THIS PROJECT/) {
            $_head = 0;
            $_body = 1;  # set the new marker
            next;        # but don't store this line
        }
        if (/\*\*\* END OF THIS PROJECT/) {
            $_body = 0;
            $_foot = 1;  # set the new marker again
            next;        # don't store this line either
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
        if ($_foot == 1) {
            push (@footer, $_);
        }
    }  # end of read loop

    # we're all done reading this book
    # close and delete it
    close ($raw_fh);
    unlink("$file");
    if ($@) {
        logger('warn', "unable to delete ebook: $!");
    }

    # process the data
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

    # gutenberg formats their lines and paragraphs with just a block of whitespace
    # so we need to correct that here.
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
        if (! defined $_) {  # [TODO] shouldn't have to do this, rework to be less workaround'y
            next;
        } elsif ($_ =~ /[:\;] $/) {  # paragraph ends with semicolon, due to formatting issue from earlier in the script
            next;
        } elsif ($_ !~ /^["]/) {  # only take lines that start with a quote, this has yielded the best results against bad results, at the expense of less available quotes.
            next;
        } elsif ($_ !~ /["] $/) {  # if doesn't end with a quote
            next;
        } elsif (length $_ > 90 && length $_ < 119) {  # make sure the length is good for twitter
            $quote = $_;
        }
    }

    # verify a quote was found
    if (!$quote) {
        logger('info', "no quote found - $file");
        if ($manual) {
            print "no quote found\n\n";
            exit 1;  # exit here, since manual mode wont go through the catalog to find book numbers
        }
        next;        # back to the top of the loop to try another ebook
    }

    # print out verbose output, since a book was found
    if (!$silent) {
        print "title: $title\n" .
              "author: $author\n" .
              "\n" .
              "$quote$page_link\n" .
              "\n";
    }

    # post it to twitter
    if ($twitter) {
        logger('info', "posting to twitter");
        if (!$silent) {
            print "posting to twitter\n\n";
        }
        eval { $twitter_object->update("$quote$page_link") };
        if ( $@ ) {
            logger('warn', "post failed: $@");
            if (!$silent) {
                warn "post failed: $@\n\n";
            }
        }
        last;
    } else {
        last;
    }

}  # end main while loop 


### subs
sub print_help {
    print "usage: ./quote.pl -s -t\n\n" .
          "options:\n" .
          "\t-t|--twitter\t\tpost the quote to twitter\n\n" .
          "\t-s|--silent\t\tdont display any output (requires -t)\n\n" .
          "\t-m|--manual 1234\tmanually specify the book number\n\n" .
          "\t-h|--help\t\tdisplays this dialogue\n\n" .
          "\n";
}

sub logger {
    my ($level, $msg) = @_;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
    # format the times
    my $month_formatted = $mon + 1;
    if ($month_formatted <= 9) { $month_formatted = '0' . $month_formatted; }
    if ($mday <= 9) { $mday = '0' . $mday; }
    if ($sec <= 9) { $sec = '0' . $sec; }
    if ($min <= 9) { $min = '0' . $min; }
    if ($hour <= 9) { $hour = '0' . $hour; }
    my $year_formatted = $year + 1900;
    if (open my $out, '>>', "quote.log") {
        chomp $msg;
        print $out "[$month_formatted$mday$year_formatted.$hour$min$sec] [$level] $msg\n";
    }
}
