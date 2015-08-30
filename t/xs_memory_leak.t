use strict;
use warnings;

use Test::More;
use Data::Dumper;
use Devel::Peek;

BEGIN {
    use_ok 'HTTP::Headers::Fast';
    use_ok 'HTTP::Headers::Fast::XS';
}

package RefCounter;
my $ref_count = 0;
sub ref_count { $ref_count }
sub new {
    $ref_count++;
    bless {}, shift;
}
sub DESTROY { $ref_count-- }

package main;

{
    my $h = HTTP::Headers::Fast->new( foo => RefCounter->new );
    my $val = $h->header('foo');
    isa_ok $val, 'RefCounter';
}
is( RefCounter->ref_count, 0, 'no leak' );

{
    my $h = HTTP::Headers::Fast->new( foo => [RefCounter->new] );
    my $val = $h->header('foo');
    isa_ok $val, 'RefCounter';
}
is( RefCounter->ref_count, 0, 'no leak' );

{
    my @obj = ( RefCounter->new, RefCounter->new );
    my $h   = HTTP::Headers::Fast->new( foo => \@obj );
    my @val = $h->header('foo');
    is_deeply( \@val, \@obj, 'objects returned' );
}
is( RefCounter->ref_count, 0, 'no leak' );

{
    my @obj = ( RefCounter->new, RefCounter->new );
    my $h   = HTTP::Headers::Fast->new( map +(foo => $_), @obj );
    my @val = $h->header('foo');
    is_deeply( \@val, \@obj, 'objects returned' );
}
is( RefCounter->ref_count, 0, 'no leak' );

{
    my @obj = ( RefCounter->new, RefCounter->new );
    my $h   = HTTP::Headers::Fast->new( map +(foo => $_), @obj );
    my $val = $h->header('foo');
    is( $val, join(', ', @obj), 'objects returned' );
}
is( RefCounter->ref_count, 0, 'no leak' );

{
    my $obj = RefCounter->new;
    my $h   = HTTP::Headers::Fast->new( +(foo => $obj) x 2 );
    my $val = $h->header('foo');
    is( $val, join(', ', $obj, $obj), 'objects returned' );
}
is( RefCounter->ref_count, 0, 'no leak' );

{
    my $obj = RefCounter->new;
    my $h   = HTTP::Headers::Fast->new;
    $h->push_header( foo => $obj );
}
is( RefCounter->ref_count, 0, 'no leak' );

done_testing;
