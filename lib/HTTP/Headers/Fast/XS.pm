package HTTP::Headers::Fast::XS;
use strict;
use warnings;
use XSLoader;
use parent 'Exporter';
use Data::Dumper qw( Dumper );    # really needed, not just for debugging

our $VERSION = '0.11';

require HTTP::Headers::Fast; # make sure it's loaded

XSLoader::load( 'HTTP::Headers::Fast::XS', $VERSION );
our @EXPORT  = qw{
                   hhf_hlist_create
                   hhf_hlist_destroy
                   hhf_hlist_clear
                   hhf_hlist_header_get
                   hhf_hlist_header_set
                   hhf_hlist_header_remove
                   hhf_hlist_header_names
                   hhf_hlist_clone
                 };

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
*HTTP::Headers::Fast::_header =
    *HTTP::Headers::Fast::XS::_header;
*HTTP::Headers::Fast::header_field_names =
    *HTTP::Headers::Fast::XS::header_field_names;
*HTTP::Headers::Fast::_sorted_field_names =
    *HTTP::Headers::Fast::XS::_sorted_field_names;
*HTTP::Headers::Fast::scan =
    *HTTP::Headers::Fast::XS::scan;
*HTTP::Headers::Fast::_as_string =
    *HTTP::Headers::Fast::XS::_as_string;
*HTTP::Headers::Fast::as_string_without_sort =
    *HTTP::Headers::Fast::XS::as_string_without_sort;
*HTTP::Headers::Fast::clone =
    *HTTP::Headers::Fast::XS::clone;
*HTTP::Headers::Fast::_date_header =
    *HTTP::Headers::Fast::XS::_date_header;
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
#         (shift->_header($key, @_))[0];
#     };
# }

# *HTTP::Headers::Fast::title =
#     *HTTP::Headers::Fast::XS::title;
# *HTTP::Headers::Fast::content_encoding =
#     *HTTP::Headers::Fast::XS::content_encoding;
# *HTTP::Headers::Fast::content_language =
#     *HTTP::Headers::Fast::XS::content_language;
# *HTTP::Headers::Fast::content_length =
#     *HTTP::Headers::Fast::XS::content_length;
# *HTTP::Headers::Fast::user_agent =
#     *HTTP::Headers::Fast::XS::user_agent;
# *HTTP::Headers::Fast::server =
#     *HTTP::Headers::Fast::XS::server;
# *HTTP::Headers::Fast::from =
#     *HTTP::Headers::Fast::XS::from;
# *HTTP::Headers::Fast::warnings =
#     *HTTP::Headers::Fast::XS::warnings;
# *HTTP::Headers::Fast::www_authenticate =
#     *HTTP::Headers::Fast::XS::www_authenticate;
# *HTTP::Headers::Fast::authorization =
#     *HTTP::Headers::Fast::XS::authorization;
# *HTTP::Headers::Fast::proxy_authenticate =
#     *HTTP::Headers::Fast::XS::proxy_authenticate;
# *HTTP::Headers::Fast::proxy_authorization =
#     *HTTP::Headers::Fast::XS::proxy_authorization;
#

# *HTTP::Headers::Fast::_standardize_field_name =
#     *HTTP::Headers::Fast::XS::_standardize_field_name;
#
# *HTTP::Headers::Fast::push_header =
#     *HTTP::Headers::Fast::XS::push_header;
#
# *HTTP::Headers::Fast::_header_get =
#     *HTTP::Headers::Fast::XS::_header_get;
#
# *HTTP::Headers::Fast::_header_set =
#     *HTTP::Headers::Fast::XS::_header_set;
#
# #*HTTP::Headers::Fast::_header_push =
# #    *HTTP::Headers::Fast::XS::_header_push;
#
# 1;
#

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

sub DESTROY {
    my ($self) = shift;
    hhf_hlist_destroy($self->{hlist});
    1;
}

sub isa {
    my ($self, $klass) = @_;
    my $proto = ref $self || $self;
    return ($proto eq $klass || $klass eq 'HTTP::Headers') ? 1 : 0;
}

sub header {
    my $self = shift;
    Carp::croak('Usage: $h->header($field, ...)') unless @_;
    my (@old);

    if (@_ == 1) {
        @old = hhf_hlist_header_get($self->{hlist},
                                    $HTTP::Headers::Fast::TRANSLATE_UNDERSCORE // 0,
                                    @_);
    } elsif( @_ == 2 ) {
        @old = hhf_hlist_header_set($self->{hlist},
                                    $HTTP::Headers::Fast::TRANSLATE_UNDERSCORE // 0,
                                    0, 0, 1, @_);
    } else {
        my %seen;
        while (@_) {
            my $field = shift;
            if ( $seen{ lc $field }++ ) {
                @old = hhf_hlist_header_set($self->{hlist},
                                            $HTTP::Headers::Fast::TRANSLATE_UNDERSCORE // 0,
                                            0, 1, 1, $field, shift);
            } else {
                @old = hhf_hlist_header_set($self->{hlist},
                                            $HTTP::Headers::Fast::TRANSLATE_UNDERSCORE // 0,
                                            0, 0, 1, $field, shift);
            }
        }
    }

    return @old    if wantarray;
    return $old[0] if @old <= 1;
    return join( ", ", @old );
}

sub clear {
    my $self = shift;
    hhf_hlist_clear($self->{hlist});
}

# sub push_header {
#     my $self = shift;
#
#     if (@_ == 2) {
#         my ($field, $val) = @_;
#         hhf_hlist_header_set($self->{hlist},
#                              $HTTP::Headers::Fast::TRANSLATE_UNDERSCORE // 0,
#                              0, 1, 0, $field, $val);
#     } else {
#         while ( my ($field, $val) = splice( @_, 0, 2 ) ) {
#             hhf_hlist_header_set($self->{hlist},
#                                  $HTTP::Headers::Fast::TRANSLATE_UNDERSCORE // 0,
#                                  0, 1, 0, $field, $val);
#         }
#     }
#     return ();
# }

sub init_header {
    Carp::croak('Usage: $h->init_header($field, $val)') if @_ != 3;
    my ($self, $field, $val) = @_;
    hhf_hlist_header_set($self->{hlist},
                         $HTTP::Headers::Fast::TRANSLATE_UNDERSCORE // 0,
                         1, 0, 1, $field, $val);
}

sub remove_header {
    my ( $self, @fields ) = @_;
    my @values;
    for my $field (@fields) {
        my @ret = hhf_hlist_header_remove($self->{hlist},
                                          $HTTP::Headers::Fast::TRANSLATE_UNDERSCORE // 0,
                                          $field);
        push(@values, @ret);
    }
    return @values;
}

sub remove_content_headers {
    my $self = shift;
    my $c = ref($self)->new;
    for my $field (grep $entity_header{$_} || /^Content-/, hhf_hlist_header_names($self->{hlist}, 1)) {
        my @values = hhf_hlist_header_remove($self->{hlist},
                                             $HTTP::Headers::Fast::TRANSLATE_UNDERSCORE // 0,
                                             $field);
        $c->header($field, \@values);
    }
    $c;
}

### my %field_name;
### sub _standardize_field_name {
###     my $field = shift;
###
###     $field =~ tr/_/-/ if $TRANSLATE_UNDERSCORE;
###     if (my $cache = $field_name{$field}) {
###         return $cache;
###     }
###
###     my $old = $field;
###     $field = lc $field;
###     unless ( defined $standard_case{$field} ) {
###         # generate a %standard_case entry for this field
###         $old =~ s/\b(\w)/\u$1/g;
###         $standard_case{$field} = $old;
###     }
###     $field_name{$old} = $field;
###     return $field;
### }
###
### sub _header_get {
###     my ($self, $field, $skip_standardize) = @_;
###
###     $field = _standardize_field_name($field) unless $skip_standardize || $field =~ /^:/;
###
###     my $h = $self->{$field};
###     return (ref($h) eq 'ARRAY') ? @$h : ( defined($h) ? ($h) : () );
### }
###
### sub _header_set {
###     my ($self, $field, $val) = @_;
###
###     $field = _standardize_field_name($field) unless $field =~ /^:/;
###
###     my $h = $self->{$field};
###     my @old = ref($h) eq 'ARRAY' ? @$h : ( defined($h) ? ($h) : () );
###     if ( defined($val) ) {
###         if (ref $val eq 'ARRAY' && scalar(@$val) == 1) {
###             $val = $val->[0];
###         }
###         $self->{$field} = $val;
###     } else {
###         delete $self->{$field};
###     }
###     return @old;
### }
###
### sub _header_push {
###     my ($self, $field, $val) = @_;
###
###     $field = _standardize_field_name($field) unless $field =~ /^:/;
###
###     my $h = $self->{$field};
###     my @old = ref($h) eq 'ARRAY') ? @$h : (defined($h) ? ($h) : ());
###     my $n = ref $val ne 'ARRAY' ? $val : @$val;
###     if (ref($h) eq 'ARRAY') {
###         push @$h, $x;
###     } elsif (defined $h) {
###         $self->{$field} = [$h, $x];
###     } else {
###         $self->{$field} = $x;
###     }
###     return @old;
### }

sub _header {
    my ($self, $field, $val, $op) = @_;

    $op ||= defined($val) ? $OP_SET : $OP_GET;

    my @old = hhf_hlist_header_get($self->{hlist},
                                   $HTTP::Headers::Fast::TRANSLATE_UNDERSCORE // 0,
                                   $field);

    unless ( $op == $OP_GET || ( $op == $OP_INIT && @old ) ) {
        if ( defined($val) ) {
            my @new = ( $op == $OP_PUSH ) ? @old : ();
            if ( ref($val) ne 'ARRAY' ) {
                push( @new, $val );
            }
            else {
                push( @new, @$val );
            }
            hhf_hlist_header_set($self->{hlist},
                                 $HTTP::Headers::Fast::TRANSLATE_UNDERSCORE // 0,
                                 0, 0, 0, $field, \@new);
        }
        elsif ( $op != $OP_PUSH ) {
            hhf_hlist_header_remove($self->{hlist},
                                    $HTTP::Headers::Fast::TRANSLATE_UNDERSCORE // 0,
                                    $field);
        }
    }
    @old;
}

sub _sorted_field_names {
    my ($self, $canonical) = @_;

    my @sorted = sort  {
        ( $header_order{$a} || 999 ) <=> ( $header_order{$b} || 999 )
            || $a cmp $b
    } hhf_hlist_header_names($self->{hlist}, $canonical // 1);

    return \@sorted;
}

sub header_field_names {
    my $self = shift;
    return map $standard_case{$_} || $_, @{ $self->_sorted_field_names(0) }
      if wantarray;
    my @names = hhf_hlist_header_names($self->{hlist}, 0);
    return @names // 0;
}

sub scan {
    my ( $self, $sub ) = @_;
    for my $key (@{ $self->_sorted_field_names(0) }) {
        next if substr($key, 0, 1) eq '_';
        my @vals = hhf_hlist_header_get($self->{hlist},
                                        $HTTP::Headers::Fast::TRANSLATE_UNDERSCORE // 0,
                                        $key);
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
        my @vals = hhf_hlist_header_get($self->{hlist},
                                        $HTTP::Headers::Fast::TRANSLATE_UNDERSCORE // 0,
                                        $key);
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

# sub as_string {
#     my ( $self, $endl ) = @_;
#     $endl = "\n" unless defined $endl;
#     $self->_as_string($endl, $self->_sorted_field_names);
# }

sub as_string_without_sort {
    my ( $self, $endl ) = @_;
    $endl = "\n" unless defined $endl;
    $self->_as_string($endl, [ hhf_hlist_header_names($self->{hlist}, 0) ]);
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
        ($old) = hhf_hlist_header_set($self->{hlist},
                                      $HTTP::Headers::Fast::TRANSLATE_UNDERSCORE // 0,
                                      0, 0, 1, $header, HTTP::Date::time2str($time) );
    } else {
        ($old) = hhf_hlist_header_get($self->{hlist},
                                      $HTTP::Headers::Fast::TRANSLATE_UNDERSCORE // 0,
                                      $header);
    }
    $old =~ s/;.*// if defined($old);
    HTTP::Date::str2time($old);
}

# sub date                { shift->_date_header( 'date',                @_ ); }
# sub expires             { shift->_date_header( 'expires',             @_ ); }
# sub if_modified_since   { shift->_date_header( 'if-modified-since',   @_ ); }
# sub if_unmodified_since { shift->_date_header( 'if-unmodified-since', @_ ); }
# sub last_modified       { shift->_date_header( 'last-modified',       @_ ); }

### # This is used as a private LWP extension.  The Client-Date header is
### # added as a timestamp to a response when it has been received.
### sub client_date { shift->_date_header( 'client-date', @_ ); }
###
### # The retry_after field is dual format (can also be a expressed as
### # number of seconds from now), so we don't provide an easy way to
### # access it until we have know how both these interfaces can be
### # addressed.  One possibility is to return a negative value for
### # relative seconds and a positive value for epoch based time values.
### #sub retry_after       { shift->_date_header('Retry-After',       @_); }

sub content_type {
    my $self = shift;
    my $ct   = hhf_hlist_header_get($self->{hlist},
                                    $HTTP::Headers::Fast::TRANSLATE_UNDERSCORE // 0,
                                    'content-type');
    hhf_hlist_header_set($self->{hlist},
                         $HTTP::Headers::Fast::TRANSLATE_UNDERSCORE // 0,
                         0, 0, 0, 'content-type', shift) if @_;
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
    my $h = hhf_hlist_header_get($self->{hlist},
                                 $HTTP::Headers::Fast::TRANSLATE_UNDERSCORE // 0,
                                 'content-type');
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

### Unchanged but called from this module
sub _split_header_words
{
    my(@val) = @_;
    my @res;
    for (@val) {
        my @cur;
        while (length) {
            if (s/^\s*(=*[^\s=;,]+)//) {  # 'token' or parameter 'attribute'
                push(@cur, $1);
                # a quoted value
                if (s/^\s*=\s*\"([^\"\\]*(?:\\.[^\"\\]*)*)\"//) {
                    my $val = $1;
                    $val =~ s/\\(.)/$1/g;
                    push(@cur, $val);
                    # some unquoted value
                }
                elsif (s/^\s*=\s*([^;,\s]*)//) {
                    my $val = $1;
                    $val =~ s/\s+$//;
                    push(@cur, $val);
                    # no value, a lone token
                }
                else {
                    push(@cur, undef);
                }
            }
            elsif (s/^\s*,//) {
                push(@res, [@cur]) if @cur;
                @cur = ();
            }
            elsif (s/^\s*;// || s/^\s+//) {
                # continue
            }
            else {
                die "This should not happen: '$_'";
            }
        }
        push(@res, \@cur) if @cur;
    }

    for my $arr (@res) {
        for (my $i = @$arr - 2; $i >= 0; $i -= 2) {
            $arr->[$i] = lc($arr->[$i]);
        }
    }
    return @res;
}

# sub content_is_html {
#     my $self = shift;
#     return $self->content_type eq 'text/html' || $self->content_is_xhtml;
# }

# sub content_is_xhtml {
#     my $ct = shift->content_type;
#     return $ct eq "application/xhtml+xml"
#       || $ct   eq "application/vnd.wap.xhtml+xml";
# }

# sub content_is_xml {
#     my $ct = shift->content_type;
#     return 1 if $ct eq "text/xml";
#     return 1 if $ct eq "application/xml";
#     return 1 if $ct =~ /\+xml$/;
#     return 0;
# }

# sub title             { (shift->_header('Title',            @_))[0] }
# sub content_encoding  { (shift->_header('Content-Encoding', @_))[0] }
# sub content_language  { (shift->_header('Content-Language', @_))[0] }
# sub content_length    { (shift->_header('Content-Length',   @_))[0] }
#
# sub user_agent        { (shift->_header('User-Agent',       @_))[0] }
# sub server            { (shift->_header('Server',           @_))[0] }
#
# sub from              { (shift->_header('From',             @_))[0] }
# sub warnings          { (shift->_header('Warnings',         @_))[0] }
#
# sub www_authenticate  { (shift->_header('WWW-Authenticate', @_))[0] }
# sub authorization     { (shift->_header('Authorization',    @_))[0] }
#
# sub proxy_authenticate  { (shift->_header('Proxy-Authenticate',  @_))[0] }
# sub proxy_authorization { (shift->_header('Proxy-Authorization', @_))[0] }
#
# sub authorization_basic       { shift->_basic_auth("Authorization",       @_) }
# sub proxy_authorization_basic { shift->_basic_auth("Proxy-Authorization", @_) }

# sub _basic_auth {
#     require MIME::Base64;
#     my($self, $h, $user, $passwd) = @_;
#     my($old) = $self->_header($h);
#     if (defined $user) {
#         Carp::croak("Basic authorization user name can't contain ':'")
#             if $user =~ /:/;
#         $passwd = '' unless defined $passwd;
#         $self->_header($h => 'Basic ' .
#                        MIME::Base64::encode("$user:$passwd", ''));
#     }
#     if (defined $old && $old =~ s/^\s*Basic\s+//) {
#         my $val = MIME::Base64::decode($old);
#         return $val unless wantarray;
#         return split(/:/, $val, 2);
#     }
#     return;
# }

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
    ( $self->_header( 'Referer', @_ ) )[0];
}
*referrer = \&referer;    # on tchrist's request

### for my $key (qw/content-length content-language content-encoding title user-agent server from warnings www-authenticate authorization proxy-authenticate proxy-authorization/) {
###     no strict 'refs';
###     (my $meth = $key) =~ s/-/_/g;
###     *{$meth} = sub {
###         my $self = shift;
###         if (@_) {
###             ( $self->_header_set( $key, @_ ) )[0]
###         } else {
###             my $h = $self->{$key};
###             (ref($h) eq 'ARRAY') ? $h->[0] : $h;
###         }
###     };
### }
###

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
