package Catalog;

use strict;
use warnings;

use LWP::Simple;
use IO::Uncompress::Bunzip2 qw(bunzip2 $Bunzip2Error);

use Exporter qw(import);
our @EXPORT = qw(get_catalog);

my $catalog = 'catalog.rdf';

# subs
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
    return;
}

1;
