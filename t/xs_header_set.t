use strict;
use warnings;
use Test::More;

BEGIN {
    use_ok('HTTP::Headers::Fast');
    use_ok('HTTP::Headers::Fast::XS');
}

can_ok( HTTP::Headers::Fast::, '_header_set' );

# get

{
    my $h = HTTP::Headers::Fast->new;
    my @old = $h->_header_set( foo => 'bar' );

    is_deeply( \@old, [], 'returns empty list for unset value' );
    is( $h->as_string, "Foo: bar\n", 'and new value is set' );
}

{
    my $h = HTTP::Headers::Fast->new( foo => 'bar' );
    my @old = $h->_header_set( foo => 'baz' );

    is_deeply( \@old, ['bar'], 'returns single-element list for scalar value' );
    is( $h->as_string, "Foo: baz\n", 'and new value overwrites old' );
}

{
    my $h = HTTP::Headers::Fast->new( foo => [qw( bar baz )] );
    my @old = $h->_header_set( foo => 'qux' );

    is_deeply( \@old, [qw( bar baz )], 'returns list for array ref value' );
    is( $h->as_string, "Foo: qux\n", 'and new value overwrites old' );
}

# set

{
    my $h = HTTP::Headers::Fast->new;
    my @old = $h->_header_set( foo => 'bar' );

    is( $h->as_string, "Foo: bar\n", 'sets scalar value' );
}

{
    my $h = HTTP::Headers::Fast->new;
    $h->_header_set( foo => [qw( bar baz )] );

    is( $h->as_string, "Foo: bar\nFoo: baz\n", 'sets array value' );
}

{
    my $h = HTTP::Headers::Fast->new;
    $h->_header_set( foo => ['bar'] );

    is( $h->as_string, "Foo: bar\n", 'sets single-element array value as scalar' );
}

# delete

{
    my $h = HTTP::Headers::Fast->new( foo => 'bar' );
    $h->_header_set( foo => undef );

    is( $h->as_string, '', 'deletes value' );
}

# field standardization

{
    my $h = HTTP::Headers::Fast->new( foo => 'bar' );
    my @old = $h->_header_set( FOO => 'baz' );

    is_deeply( \@old, ['bar'], 'field is standardized' );
    is( $h->as_string, "Foo: baz\n" );
}

{
    my $h = HTTP::Headers::Fast->new( ':FOO' => 'bar', ':foo' => 'baz' );
    my @old = $h->_header_set( ':FOO' => 'qux' );

    is_deeply( \@old, ['bar'], 'field standardization is skipped' );
    is( $h->as_string, "FOO: qux\nfoo: baz\n" );
}

done_testing;
