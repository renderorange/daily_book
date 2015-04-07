#!/usr/bin/perl

# quote.pl

use utf8;
use strict;
use warnings;

use Getopt::Long;
use LWP::Simple;
use IO::Uncompress::Bunzip2 qw(bunzip2 $Bunzip2Error);
use Net::Twitter::Lite::WithAPIv1_1;

my $VERSION = '0.1.1';

use Data::Dumper;


### variables and settings
my $sleep = 61;

# twitter oauth
my ($consumer_key, $consumer_secret, $access_token, $access_token_secret);
my $development = 1;  # set development mode to post to testing account
if ($development == 1) {
    # _renderorange
    $consumer_key = '***REMOVED***';
    $consumer_secret = '***REMOVED***';
    $access_token = '***REMOVED***';
    $access_token_secret = '***REMOVED***';
} else {
    print "development mode is off\n";
    sleep 5;
    # _daily_book
    $consumer_key = '***REMOVED***';
    $consumer_secret = '***REMOVED***';
    $access_token = '***REMOVED***';
    $access_token_secret = '***REMOVED***';
}


### pre-processing
# get commandline options
my ($twitter, $silent, $manual);
GetOptions ("twitter" => sub { $twitter = 1 },
            "silent"  => sub { $silent = 1 },
            "manual=i"  => \$manual )  # manual mode was only meant to be run in the event of debugging logic issues
    or print_help() and exit;
if ($silent && !$twitter || $manual && $silent) {
    print_help() and exit;
}


# print header
if (!$silent) {
    print "quote.pl\n" .
          "v$VERSION\n\n";
}

# check if catalog exists
my $catalog = 'catalog.rdf';
if (-e "$catalog") {
    # check date
    my $mtime = (stat $catalog)[9];
    my $current_time = time;
    my $diff = $current_time - $mtime;
    # if older than one week
    if ($diff > 604800) {
        # delete the old catalog
        unlink("$catalog");
        if ($@) {
            logger('warn', "unable to delete old catalog: $!");
        }  
        get_catalog();
    }
} else {
    get_catalog();
}

# open the catalog
open (my $catalog_fh, "<", "$catalog") or logger('fatal', "cannot open catalog: $!") and die "cannot open catalog: $!";

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
while (1) {  # main while loop 

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
        die "there was an error downloading the book: $rc";
    }


    # open the book, cleanup, and store
    open (my $raw_fh, "<:encoding(UTF-8)", "$file") or logger('fatal', "unable to open book txt: $!") and die "unable to open book txt: $!";

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
            $sleep = 900;  # set the rest of the sleeps to 900
            sleep $sleep;
            last;
        }
        if (/The New McGuffey/) {
            logger('info', "ebook is The New McGuffey Reader - $file");
            sleep $sleep;
            last;
        }
        if (/Language: /) {
            if ($_ !~ /English/) {
                logger('info', "ebook isn't in English - $file");
                sleep $sleep;
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
    unlink("$file");
    if ($@) {
        logger('warn', "unable to delete old catalog: $!");
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
        } elsif (length $_ > 90 && length $_ < 119) {
            $quote = $_;
        }
    }

    # verify a quote was found
    if (!$quote) {
        logger('info', "no quote found - $file");
        if ($manual) {
            die "no quote found\n\n";
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
        # check for twitter settings
        if ($consumer_key eq '' || $consumer_secret eq '' || $access_token eq '' || $access_token_secret eq '') {
            logger('fatal', "twitter oauth credentials are not complete") and die "twitter oauth credentials are not complete\n";
        }
        # instantiate object
        my $twitter = Net::Twitter::Lite::WithAPIv1_1->new(
            consumer_key        => "$consumer_key",
            consumer_secret     => "$consumer_secret",
            access_token        => "$access_token",
            access_token_secret => "$access_token_secret",
            ssl                 => 1,
        );
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

sub get_catalog {
    # download and store the new catalog archive
    logger('info', 'downloading catalog');
    my $rc = getstore('http://www.gutenberg.org/feeds/catalog.rdf.bz2', 'catalog.rdf.bz2');
    if (is_error($rc)) {
        logger('fatal', "there was an error downloading the book catalog: $rc");
        die "there was an error downloading the book catalog: $rc";
    }
    undef($rc);
    # unpack the catalog file
    bunzip2 'catalog.rdf.bz2' => "$catalog" or logger('fatal', "bunzip2 on catalog failed: $Bunzip2Error") and die "bunzip2 on catalog failed: $Bunzip2Error\n";
    # delete the archived version
    unlink('catalog.rdf.bz2');
    if ($@) {
        logger('warn', "unable to delete catalog archive: $!");
    }
}

