#!/usr/bin/perl

# quote.pl

use utf8;
use strict;
use warnings;

use local::lib;
use Getopt::Long;
use File::Slurper 'read_lines';
use LWP::Simple;
use Net::Twitter::Lite::WithAPIv1_1;

my $VERSION = '0.1.5';


### pre-processing
# get commandline options
my ($twitter, $silent, $manual);
GetOptions ("twitter" => \$twitter,
            "silent"  => \$silent,
            "manual=i"  => \$manual )  # manual mode is intended to be run for debugging purposes only
    or print_help() and exit;
if ($silent && !$twitter || $manual && $silent) {  # these options don't particularly make much sense run together
    print_help() and exit;
}

# variables and settings
my $sleep = 61;
my $rc = '.quote.rc';
my %config;
my $twitter_object;

# testing mode                                 # with testing mode set to 1, quote.pl will load a different rc file
my $testing_mode = 1;                          # this is meant to test post to a twitter account without followers
if ($testing_mode) { $rc = '.quote.rc.dev'; }  # hard coding it here is a failsafe for me, as opposed to running from commandline

# make sure the rc file is there
if ($twitter) {
    if (! -e "$rc") {  # if rc is not present
        print "$rc is not present\n" .
              "please see github.com/renderorange/daily_book for setup details\n\n";
        exit 1;
    }
    # load and verify config from rc file
    foreach (read_lines("$rc")) {  # [TODO] the verification below could stand to be more specific, verifying values as well
        if (/^#/) { next; }  # filter out comments
        my ($key, $value) = split (/:/);  # [TODO] add trim of whitespace, run through map on $_, through the split list
        # verify config contains what's expected
        if ($key !~ /^account$|^consumer_key$|^consumer_secret$|^access_token$|^access_token_secret$/) {
            print "$rc doesn't appear to contain what's needed\n" .
                  "please see github.com/renderorange/daily_book for setup details\n\n";
            exit 1;
        }
        $config{$key} = $value;  # $config{'account'} = values can be accessed like so
    }
    # instantiate twitter object for API access
    $twitter_object = Net::Twitter::Lite::WithAPIv1_1->new(
        consumer_key        => $config{consumer_key},
        consumer_secret     => $config{consumer_secret},
        access_token        => $config{access_token},
        access_token_secret => $config{access_token_secret},
        ssl                 => 1,
    );
}

# print header
if (!$silent) {
    print "quote.pl\n" .
          "v$VERSION\n\n";
    if ($twitter && $testing_mode == 1) {  # if testing_mode is not on
        print "testing mode is on\n" .
              "account: $config{'account'}\n\n";
        sleep 5;
    }
}

# check if catalog exists
my $catalog = 'catalog.rdf';
if (! -e "$catalog") {
    print "$catalog doesn't exist\n" .
          "please see github.com/renderorange/daily_book for setup details\n\n";
    exit 1;
}

# get the info from the catalog
open (my $catalog_fh, "<", "$catalog") or logger('fatal', "cannot open catalog: $!") and print "cannot open catalog: $!\n\n" and exit 1;
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
my ($number, $file);
MAIN: while (1) {

    if (!$manual) {
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
    my $page_link = "gutenberg.org/ebooks/$number";
    my $book_link = "gutenberg.org/cache/epub/$number/$file";

    # download the ebook
    my $rc = getstore("http://$book_link", "$file");
    if (is_error($rc)) {
        logger('fatal', "there was an error downloading the book: $rc");
        print "there was an error downloading the book: $rc\n\n";
        exit 1;
    }

    # open the book, cleanup, and store
    open (my $raw_fh, "<:encoding(UTF-8)", "$file") or logger('fatal', "unable to open book txt: $!") and print "unable to open book txt: $!\n\n" and exit 1;

    # read, format, and store
    my ($title, $author);
    my ($_head, $_body, $_footer) = (0, 0, 0);
    my (@header, @body, @footer);

    while (<$raw_fh>) {
        # check location within book
        if ($_body != 1 && $_footer != 1) {
            $_head = 1;
        }
        # check for ratelimiting
        if (/You have used Project Gutenberg quite a lot today or clicked through it really fast/) {
            logger('warn', "we've been ratelimited; they're on to us!");
            close ($raw_fh);
            unlink("$file");
            if ($manual) {
                print "we've been ratelimited, they're on to us!\n\n";
                exit 1;
            }
            $sleep = 900;  # set the rest of the sleeps to 900
            sleep $sleep;
            next MAIN;
        }
        if (/The New McGuffey/) {
            logger('info', "ebook is The New McGuffey Reader - $file");
            close ($raw_fh);
            unlink("$file");
            if ($manual) {
                print "ebook is The New McGuffey Reader\n\n";
                exit 1;
            }
            sleep $sleep;
            next MAIN;
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
                sleep $sleep;
                next MAIN;
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
    #    } elsif ($_ =~ /INDEX/) {
    #        next;
    #    } elsif ($_ =~ /Page [\d]/) {
    #        next;
    #    } elsif ($_ =~ /©/) {
    #        next; 
    #    } elsif (/\[ILLUSTRATION\:/) {
    #        next;
    #    } elsif ($_ =~ /End of the Project Gutenberg EBook/) {
    #        next;
    #    } elsif ($_ =~ /^[\[]/) {  # paragraph starts with [, example being 6388
    #        next;
        } elsif ($_ =~ /[:\;] $/) {  # paragraph ends with semicolon (due to formatting issue from earlier in the script)
            next;
        } elsif ($_ !~ /^["]/) {  # only take lines that start with a quote (this has yielded the best results against false positive, knowlingly missing a lot of good quotes)
            next;
        } elsif ($_ !~ /["] $/) {  # if doesn't end with a quote
            next;
        } elsif (length $_ > 90 && length $_ < 119) {
            $quote = $_;
        }
    }

    # verify a quote was found
    if (!$quote) {
        logger('info', "no quote found - $file");
        if ($manual) {
            print "no quote found\n\n";
            exit 1;
        }
        sleep $sleep;
        next;
    }

    # print out verbose output
    if (!$silent) {
        print "title: $title\n" .
              "author: $author\n" .
              "\n" .
              "$quote$page_link\n" .
              "\n";
    }

    # twitter
    if ($twitter) {
        logger('info', "posting to twitter");
        if (!$silent) {
            print "posting to twitter\n\n";
        }
        eval { $twitter->update("$quote$page_link") };
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

}  # main while loop 


### subs
sub print_help {
    print "usage: ./quote.pl\n" .
          "-s|--silent\t\t dont display any output (requires -t)\n" .
          "-t|--twitter\t\t post to twitter\n" .
          "-m|--manual\t\t manually specify the book number\n" . 
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
