use strict;
use warnings;
use HTTP::Headers::Fast;
use HTTP::Headers::Fast::XS;
use Test::More tests => 1;

is $INC{'Storable.pm'}, undef;
