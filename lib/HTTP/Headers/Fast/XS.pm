package HTTP::Headers::Fast::XS;

use strict;
use warnings;
use XSLoader;

our $VERSION = '0.001';

require HTTP::Headers::Fast; # make sure it's loaded
XSLoader::load( 'HTTP::Headers::Fast::XS', $VERSION );

*HTTP::Headers::Fast::_standardize_field_name =
    *HTTP::Headers::Fast::XS::_standardize_field_name;

*HTTP::Headers::Fast::push_header =
    *HTTP::Headers::Fast::XS::push_header;

*HTTP::Headers::Fast::_header_get =
    *HTTP::Headers::Fast::XS::_header_get;

*HTTP::Headers::Fast::_header_set =
    *HTTP::Headers::Fast::XS::_header_set;

#*HTTP::Headers::Fast::_header_push =
#    *HTTP::Headers::Fast::XS::_header_push;

1;

__END__

=pod

=head1 NAME

HTTP::Headers::Fast::XS - XS implementation of HTTP::Headers::Fast

=head1 SYNOPSIS

    # load once
    use HTTP::Headers::Fast::XS;

    # keep using HTTP::Headers::Fast as you wish

=head1 DESCRIPTION

By loading L<HTTP::Headers::Fast::XS> anywhere, you replace any usage
of L<HTTP::Headers::Fast> with the XS implementation.

You can continue to use L<HTTP::Headers::Fast> and any other module that
depends on it just like you did before. It's just faster now.

=head1 METHODS

Implemented methods in XS:

=head2 _standardize_field_name

This is an internal function used often.
