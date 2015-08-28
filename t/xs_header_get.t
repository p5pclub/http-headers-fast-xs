use strict;
use warnings;
use Test::More;

BEGIN {
    use_ok('HTTP::Headers::Fast');
    use_ok('HTTP::Headers::Fast::XS');
}

package ArrayObject;
sub new {
    my $class = shift;
    bless [@_], $class;
}

package main;
can_ok( HTTP::Headers::Fast::, '_header_get' );

{
    my $obj = ArrayObject->new(1, 2, 3);
    my $h = HTTP::Headers::Fast->new( foo => $obj );
    my @val = $h->header('foo');

    is_deeply( [@val], [$obj], 'gets array-based object' );
}

{
    my $h = HTTP::Headers::Fast->new(foo => "bar", foo_multi => "baaaaz", foo_multi => "baz");
    my @val = $h->_header_get('foo');

    is_deeply( \@val, ['bar'], 'get scalar' );
}

{
    my $h = HTTP::Headers::Fast->new(foo => "bar", foo => "baaaaz", Foo => "baz");
    my @val = $h->_header_get('foo');

    is_deeply( \@val, [qw( bar baaaaz baz )], 'get array' );
}

{
    my $h = HTTP::Headers::Fast->new(foo => "bar", foo_multi => "baaaaz");
    my @val = $h->_header_get('Foo');

    is_deeply( \@val, ['bar'], 'standardizes field name' );
}

{
    my $h = HTTP::Headers::Fast->new(foo => "bar", ':FOO' => "baaaaz");
    my @val = $h->_header_get(':FOO');

    is_deeply( \@val, ['baaaaz'], 'escape field standardization' );
}

done_testing;
