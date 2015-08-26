package HTTP::Headers::Fast::XS;
use strict;
use warnings;
use XSLoader;
use parent 'Exporter';
use Data::Dumper qw( Dumper );    # really needed, not just for debugging

our $VERSION = '0.11';

require HTTP::Headers::Fast; # make sure it's loaded

XSLoader::load( 'HTTP::Headers::Fast::XS', $VERSION );

*HTTP::Headers::Fast::isa =
    *HTTP::Headers::Fast::XS::isa;
*HTTP::Headers::Fast::new =
    *HTTP::Headers::Fast::XS::new;
*HTTP::Headers::Fast::DESTROY =
    *HTTP::Headers::Fast::XS::DESTROY;
*HTTP::Headers::Fast::header =
    *HTTP::Headers::Fast::XS::header;
*HTTP::Headers::Fast::clear =
    *HTTP::Headers::Fast::XS::clear;
*HTTP::Headers::Fast::push_header =
    *HTTP::Headers::Fast::XS::push_header;
*HTTP::Headers::Fast::init_header =
    *HTTP::Headers::Fast::XS::init_header;
*HTTP::Headers::Fast::remove_header =
    *HTTP::Headers::Fast::XS::remove_header;
*HTTP::Headers::Fast::remove_content_headers =
    *HTTP::Headers::Fast::XS::remove_content_headers;
*HTTP::Headers::Fast::_header_keys =
    *HTTP::Headers::Fast::XS::_header_keys;
*HTTP::Headers::Fast::_sorted_field_names =
    *HTTP::Headers::Fast::XS::_sorted_field_names;
*HTTP::Headers::Fast::header_field_names =
    *HTTP::Headers::Fast::XS::header_field_names;
*HTTP::Headers::Fast::scan =
    *HTTP::Headers::Fast::XS::scan;
*HTTP::Headers::Fast::_as_string =
    *HTTP::Headers::Fast::XS::_as_string;
*HTTP::Headers::Fast::as_string =
    *HTTP::Headers::Fast::XS::as_string;
*HTTP::Headers::Fast::as_string_without_sort =
    *HTTP::Headers::Fast::XS::as_string_without_sort;
*HTTP::Headers::Fast::clone =
    *HTTP::Headers::Fast::XS::clone;

*HTTP::Headers::Fast::_date_header =
    *HTTP::Headers::Fast::XS::_date_header;
*HTTP::Headers::Fast::date =
    *HTTP::Headers::Fast::XS::date;
*HTTP::Headers::Fast::expires =
    *HTTP::Headers::Fast::XS::expires;
*HTTP::Headers::Fast::if_modified_since =
    *HTTP::Headers::Fast::XS::if_modified_since;
*HTTP::Headers::Fast::if_unmodified_since =
    *HTTP::Headers::Fast::XS::if_unmodified_since;
*HTTP::Headers::Fast::last_modified =
    *HTTP::Headers::Fast::XS::last_modified;

*HTTP::Headers::Fast::content_type =
    *HTTP::Headers::Fast::XS::content_type;
*HTTP::Headers::Fast::content_type_charset =
    *HTTP::Headers::Fast::XS::content_type_charset;
*HTTP::Headers::Fast::referer =
    *HTTP::Headers::Fast::XS::referer;
*HTTP::Headers::Fast::referrer =
    *HTTP::Headers::Fast::XS::referrer;

# for my $key (qw/content-length content-language content-encoding title user-agent server from warnings www-authenticate authorization proxy-authenticate proxy-authorization/) {
#     no strict 'refs';
#     (my $meth = $key) =~ s/-/_/g;
#     *{'HTTP::Headers::Fast::' . $meth} = sub {
#         print("*** GONZO: method [%s]\n", $meth);
#         (shift->header($key, @_))[0];
#     };
# }

use 5.00800;
use Carp ();

### our $TRANSLATE_UNDERSCORE = 1;

# "Good Practice" order of HTTP message headers:
#    - General-Headers
#    - Request-Headers
#    - Response-Headers
#    - Entity-Headers

# yappo says "Readonly sucks".
my $OP_GET    = 0;
my $OP_SET    = 1;
my $OP_INIT   = 2;
my $OP_PUSH   = 3;

my @general_headers = qw(
  Cache-Control Connection Date Pragma Trailer Transfer-Encoding Upgrade
  Via Warning
);

my @request_headers = qw(
  Accept Accept-Charset Accept-Encoding Accept-Language
  Authorization Expect From Host
  If-Match If-Modified-Since If-None-Match If-Range If-Unmodified-Since
  Max-Forwards Proxy-Authorization Range Referer TE User-Agent
);

my @response_headers = qw(
  Accept-Ranges Age ETag Location Proxy-Authenticate Retry-After Server
  Vary WWW-Authenticate
);

my @entity_headers = qw(
  Allow Content-Encoding Content-Language Content-Length Content-Location
  Content-MD5 Content-Range Content-Type Expires Last-Modified
);

my %entity_header = map { $_ => 1 } @entity_headers;

my @header_order =
  ( @general_headers, @request_headers, @response_headers, @entity_headers, );

# Make alternative representations of @header_order.  This is used
# for sorting and case matching.
my %header_order;
our %standard_case;

{
    my $i = 0;
    for (@header_order) {
        my $lc = lc $_;
        $header_order{$_}  = ++$i;
        $standard_case{$lc} = $_;
    }
}

sub new {
    my ($class) = shift;
    my $self = bless {}, $class;
    $self->{hlist} = hhf_hlist_create();
    $self->header(@_) if @_;    # set up initial headers
    $self;
}

sub isa {
    my ($self, $klass) = @_;
    my $proto = ref $self || $self;
    return ($proto eq $klass || $klass eq 'HTTP::Headers') ? 1 : 0;
}

sub remove_content_headers {
    my $self = shift;
    my $c = ref($self)->new;
    for my $field (grep $entity_header{$_} || /^Content-/, $self->_header_keys()) {
        my @values = $self->remove_header($field);
        $c->header($field, \@values);
    }
    $c;
}

sub _sorted_field_names {
    my ($self) = @_;

    my @sorted = sort  {
        ( $header_order{$a} || 999 ) <=> ( $header_order{$b} || 999 )
            || $a cmp $b
    } $self->_header_keys();

    return \@sorted;
}

sub header_field_names {
    my $self = shift;
    return map $standard_case{$_} || $_, @{ $self->_sorted_field_names() }
      if wantarray;
    my @names = $self->_header_keys();
    return @names // 0;
}

sub scan {
    my ( $self, $sub ) = @_;
    for my $key (@{ $self->_sorted_field_names() }) {
        next if substr($key, 0, 1) eq '_';
        my @vals = $self->header($key);
        for my $val (@vals) {
            $sub->( $standard_case{$key} || $key, $val );
        }
    }
}

### Unchanged but called from this module
sub _process_newline {
    local $_ = shift;
    my $endl = shift;
    # must handle header values with embedded newlines with care
    s/\s+$//;        # trailing newlines and space must go
    s/\n(\x0d?\n)+/\n/g;     # no empty lines
    s/\n([^\040\t])/\n $1/g; # intial space for continuation
    s/\n/$endl/g;    # substitute with requested line ending
    $_;
}

sub _as_string {
    my ($self, $endl, $fieldnames) = @_;

    my @result;
    for my $key ( @$fieldnames ) {
        next if index($key, '_') == 0;
        my @vals = $self->header($key);
        for my $val (@vals) {
            my $field = $standard_case{$key} || $key;
            $field =~ s/^://;
            if ( index($val, "\n") >= 0 ) {
                $val = _process_newline($val, $endl);
            }
            push @result, $field . ': ' . $val;
        }
    }

    join( $endl, @result, '' );
}

sub as_string {
    my ( $self, $endl ) = @_;
    $endl = "\n" unless defined $endl;
    $self->_as_string($endl, $self->_sorted_field_names);
}

sub as_string_without_sort {
    my ( $self, $endl ) = @_;
    $endl = "\n" unless defined $endl;
    $self->_as_string($endl, $self->_header_keys());
}

sub clone {
    my $self = shift;
    my $class = ref($self);

    my $obj = bless {}, $class;
    $obj->{hlist} = hhf_hlist_clone($self->{hlist});
    $obj;
}

sub _date_header {
    require HTTP::Date;
    my ( $self, $header, $time ) = @_;
    my $old;
    if ( defined $time ) {
        ($old) = $self->header($header, HTTP::Date::time2str($time));
    } else {
        ($old) = $self->header($header);
    }
    $old =~ s/;.*// if defined($old);
    HTTP::Date::str2time($old);
}

sub date                { shift->_date_header( 'date',                @_ ); }
sub expires             { shift->_date_header( 'expires',             @_ ); }
sub if_modified_since   { shift->_date_header( 'if-modified-since',   @_ ); }
sub if_unmodified_since { shift->_date_header( 'if-unmodified-since', @_ ); }
sub last_modified       { shift->_date_header( 'last-modified',       @_ ); }

# This is used as a private LWP extension.  The Client-Date header is
# added as a timestamp to a response when it has been received.
sub client_date         { shift->_date_header( 'client-date', @_ ); }

# The retry_after field is dual format (can also be a expressed as
# number of seconds from now), so we don't provide an easy way to
# access it until we have know how both these interfaces can be
# addressed.  One possibility is to return a negative value for
# relative seconds and a positive value for epoch based time values.
sub retry_after         { shift->_date_header('Retry-After',       @_); }

sub content_type {
    my $self = shift;
    my $ct   = $self->header('content-type');
    $self->header('content-type', shift) if @_;
    $ct = $ct->[0] if ref($ct) eq 'ARRAY';
    return '' unless defined($ct) && length($ct);
    my @ct = split( /;\s*/, $ct, 2 );
    for ( $ct[0] ) {
        s/\s+//g;
        $_ = lc($_);
    }
    wantarray ? @ct : $ct[0];
}

sub content_type_charset {
    my $self = shift;
    my $h = $self->header('content-type');
    $h = $h->[0] if ref($h);
    $h = "" unless defined $h;
    my @v = _split_header_words($h);
    if (@v) {
        my($ct, undef, %ct_param) = @{$v[0]};
        my $charset = $ct_param{charset};
        if ($ct) {
            $ct = lc($ct);
            $ct =~ s/\s+//;
        }
        if ($charset) {
            $charset = uc($charset);
            $charset =~ s/^\s+//;  $charset =~ s/\s+\z//;
            undef($charset) if $charset eq "";
        }
        return $ct, $charset if wantarray;
        return $charset;
    }
    return undef, undef if wantarray;
    return undef;
}

sub referer {
    my $self = shift;
    if ( @_ && $_[0] =~ /#/ ) {

        # Strip fragment per RFC 2616, section 14.36.
        my $uri = shift;
        if ( ref($uri) ) {
            require URI;
            $uri = $uri->clone;
            $uri->fragment(undef);
        }
        else {
            $uri =~ s/\#.*//;
        }
        unshift @_, $uri;
    }
    ( $self->header( 'Referer', @_ ) )[0];
}
*referrer = \&referer;    # on tchrist's request

1;

__END__

=pod

=head1 NAME

HTTP::Headers::Fast::XS - HTTP::Headers::Fast with XS and a C data structure

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
