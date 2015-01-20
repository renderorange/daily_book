package Twitter;

use strict;
use warnings;

use Exporter qw(import);
our @EXPORT = qw(post);

# requires Net::OAuth

# settings
use Net::Twitter::Lite::WithAPIv1_1;
my $twitter = Net::Twitter::Lite::WithAPIv1_1->new(
    consumer_key        => '***REMOVED***',
    consumer_secret     => '***REMOVED***',
    access_token        => '***REMOVED***',
    access_token_secret => '***REMOVED***',
    ssl                 => 1,
);

# subs
sub post {
    my $text = shift;
    my $result = $twitter->update("$text");
    return $result;
}

1;
