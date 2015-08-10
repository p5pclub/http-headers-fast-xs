package HTTP::Headers::Fast::XS;

use parent 'HTTP::Headers::Fast';
use strict;
use warnings;
use XSLoader;

our $VERSION = '0.001';

XSLoader::load( 'HTTP::Headers::Fast::XS', $VERSION );

sub isa {
    my ($self, $klass) = @_;
    return 1 if $klass eq 'HTTP::Headers::Fast';
    return $self->SUPER::isa($klass);
}

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

=head1 BACKEND MODULE DECISION

You may set environment variable C<PERL_HTTP_HEADERS_FAST_XS> to specify
whether or not the XS implementation should be used. For example,

    BEGIN { $ENV{PERL_HTTP_HEADERS_FAST_XS} = 0 }
    use HTTP::Headers::Fast;
    use HTTP::Headers::Fast::XS; # still using the default Perl implementation

=cut
