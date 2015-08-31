package HTTP::Headers::Fast::XS;
use strict;
use warnings;
use XSLoader;

our $VERSION = '0.11';

require HTTP::Headers::Fast;
XSLoader::load( 'HTTP::Headers::Fast::XS', $VERSION );

# Implemented in XS
*HTTP::Headers::Fast::new =
    *HTTP::Headers::Fast::XS::new;
*HTTP::Headers::Fast::DESTROY =
    *HTTP::Headers::Fast::XS::DESTROY;
*HTTP::Headers::Fast::clone =
    *HTTP::Headers::Fast::XS::clone;
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
*HTTP::Headers::Fast::_as_string =
    *HTTP::Headers::Fast::XS::_as_string;
*HTTP::Headers::Fast::header_field_names =
    *HTTP::Headers::Fast::XS::header_field_names;

# Implemented in Pure-Perl
# (candidates to move to XS)
*HTTP::Headers::Fast::scan =
    *HTTP::Headers::Fast::XS::scan;
*HTTP::Headers::Fast::as_string =
    *HTTP::Headers::Fast::XS::as_string;
*HTTP::Headers::Fast::as_string_without_sort =
    *HTTP::Headers::Fast::XS::as_string_without_sort;
*HTTP::Headers::Fast::_date_header =
    *HTTP::Headers::Fast::XS::_date_header;
*HTTP::Headers::Fast::content_type =
    *HTTP::Headers::Fast::XS::content_type;
*HTTP::Headers::Fast::content_type_charset =
    *HTTP::Headers::Fast::XS::content_type_charset;
*HTTP::Headers::Fast::referer =
    *HTTP::Headers::Fast::XS::referer;
*HTTP::Headers::Fast::referrer =
    *HTTP::Headers::Fast::XS::referer;

*HTTP::Headers::Fast::_basic_auth =
    *HTTP::Headers::Fast::XS::_basic_auth;

{
    no warnings qw<redefine once>;
    for my $key (qw/content-length content-language content-encoding title user-agent server from warnings www-authenticate authorization proxy-authenticate proxy-authorization/) {
      (my $meth = $key) =~ s/-/_/g;
      no strict 'refs';
      *{ "HTTP::Headers::Fast::$meth" } = sub {
          # print STDERR "*** GONZO: method [$meth]\n";
          (shift->header($key, @_))[0];
      };
    }
}

use 5.00800;
use Carp ();

# "Good Practice" order of HTTP message headers:
#    - General-Headers
#    - Request-Headers
#    - Response-Headers
#    - Entity-Headers

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

sub _sort_field_names {
    my $names = shift;

    return [ sort  { ( $header_order{$a} || 999 ) <=> ( $header_order{$b} || 999 )
                         || $a cmp $b
             } @$names ];
}

sub scan {
    my ( $self, $sub ) = @_;
    my @names = $self->_header_keys();
    for my $key (@{ _sort_field_names(\@names) }) {
        next if substr($key, 0, 1) eq '_';
        my @vals = $self->header($key);
        for my $val (@vals) {
            $sub->( $standard_case{$key} || $key, $val );
        }
    }
}

### TODO: need to move this to XS so as_string will work properly
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

sub as_string {
    my ( $self, $endl ) = @_;
    $endl = "\n" unless defined $endl;

    $self->_as_string(1, $endl);
}

sub as_string_without_sort {
    my ( $self, $endl ) = @_;
    $endl = "\n" unless defined $endl;

    $self->_as_string(0, $endl);
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

# This is copied here because it is not a method
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

sub _basic_auth {
    require MIME::Base64;
    my ( $self, $h, $user, $passwd ) = @_;
    my ($old) = $self->header($h);
    if ( defined $user ) {
        Carp::croak("Basic authorization user name can't contain ':'")
          if $user =~ /:/;
        $passwd = '' unless defined $passwd;
        $self->header(
            $h => 'Basic ' . MIME::Base64::encode( "$user:$passwd", '' ) );
    }
    if ( defined $old && $old =~ s/^\s*Basic\s+// ) {
        my $val = MIME::Base64::decode($old);
        return $val unless wantarray;
        return split( /:/, $val, 2 );
    }
    return;
}

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
