package Twitter;
use strict;
use warnings;

use Exporter qw(import);
our @EXPORT = qw(post);

# settings
use Net::Twitter::Lite::WithAPIv1_1;
my $twitter = Net::Twitter::Lite::WithAPIv1_1->new(
    consumer_key        => '***REMOVED***',
    consumer_secret     => '***REMOVED***',
    access_token        => '***REMOVED***',
    access_token_secret => '***REMOVED***',
    ssl                 => 1,
);

sub post {
    my $result = $twitter->update('Hello one last time!');
    return $result;
}

1;
