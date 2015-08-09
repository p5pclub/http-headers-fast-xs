use strict;
use warnings;
use Benchmark qw/cmpthese/;
use HTTP::Headers;
use HTTP::Headers::Fast;
use HTTP::Headers::Fast::XS;

my %source = (
    'Connection'     => 'close',
    'Date'           => 'Tue, 11 Nov 2008 01:16:37 GMT',
    'Content-Length' => 3744,
    'Content-Type'   => 'text/html',
    'Status'         => 200,
);

my @cases = (
    push_header => sub {
        local %ENV;
        my $h = HTTP::Headers->new;
        $ENV{PERL_HTTP_HEADERS_FAST_XS} = 0;
        my $f = HTTP::Headers::Fast->new;
        $ENV{PERL_HTTP_HEADERS_FAST_XS} = 1;
        my $x = HTTP::Headers::Fast->new;

        cmpthese(
            100000 => {
                orig => sub { $h->push_header('X-Foo' => 1) },
                fast => sub { $f->push_header('X-Foo' => 1) },
                xs   => sub { $x->push_header('X-Foo' => 1) },
            },
        );
    },
    push_header_many => sub {
        local %ENV;
        my $h = HTTP::Headers->new;
        $ENV{PERL_HTTP_HEADERS_FAST_XS} = 0;
        my $f = HTTP::Headers::Fast->new;
        $ENV{PERL_HTTP_HEADERS_FAST_XS} = 1;
        my $x = HTTP::Headers::Fast->new;

        cmpthese(
            300000 => {
                orig => sub { $h->push_header('X-Foo' => 1, 'X-Bar' => 2) },
                fast => sub { $f->push_header('X-Foo' => 1, 'X-Bar' => 2) },
                xs   => sub { $x->push_header('X-Foo' => 1, 'X-Bar' => 2) },
            },
        );
    },
    get_date => sub {
        local %ENV;
        my $h = HTTP::Headers->new;
        $h->date(1226370757);

        $ENV{PERL_HTTP_HEADERS_FAST_XS} = 0;
        my $f = HTTP::Headers::Fast->new;
        $f->date(1226370757);

        $ENV{PERL_HTTP_HEADERS_FAST_XS} = 1;
        my $x = HTTP::Headers::Fast->new;
        $x->date(1226370757);

        cmpthese(
            30000 => {
                orig => sub { $h->date },
                fast => sub { $f->date },
                xs   => sub { $x->date },
            },
        );
    },
    set_date => sub {
        local %ENV;
        my $h = HTTP::Headers->new;
        $ENV{PERL_HTTP_HEADERS_FAST_XS} = 0;
        my $f = HTTP::Headers::Fast->new;
        $ENV{PERL_HTTP_HEADERS_FAST_XS} = 1;
        my $x = HTTP::Headers::Fast->new;

        cmpthese(
            100000 => {
                orig => sub { $h->date(1226370757) },
                fast => sub { $f->date(1226370757) },
                xs   => sub { $x->date(1226370757) },
            },
        );
    },
    scan => sub {
        local %ENV;
        my $h = HTTP::Headers->new(%source);
        $ENV{PERL_HTTP_HEADERS_FAST_XS} = 0;
        my $f = HTTP::Headers::Fast->new(%source);
        $ENV{PERL_HTTP_HEADERS_FAST_XS} = 1;
        my $x = HTTP::Headers::Fast->new(%source);

        cmpthese(
            100000 => {
                orig => sub { $h->scan(sub { }) },
                fast => sub { $f->scan(sub { }) },
                xs   => sub { $x->scan(sub { }) },
            },
        );
    },
    get_header => sub {
        local %ENV;
        my $h = HTTP::Headers->new;
        $ENV{PERL_HTTP_HEADERS_FAST_XS} = 0;
        my $f = HTTP::Headers::Fast->new;
        $ENV{PERL_HTTP_HEADERS_FAST_XS} = 1;
        my $x = HTTP::Headers::Fast->new;

        cmpthese(
            1000000 => {
                orig => sub { $h->header('Content-Length') },
                fast => sub { $f->header('Content-Length') },
                xs   => sub { $x->header('Content-Length') },
            },
        );
    },
    set_header => sub {
        local %ENV;
        my $h = HTTP::Headers->new;
        $ENV{PERL_HTTP_HEADERS_FAST_XS} = 0;
        my $f = HTTP::Headers::Fast->new;
        $ENV{PERL_HTTP_HEADERS_FAST_XS} = 1;
        my $x = HTTP::Headers::Fast->new;

        cmpthese(
            1000000 => {
                orig => sub { $h->header('Content-Length' => 100) },
                fast => sub { $f->header('Content-Length' => 100) },
                xs   => sub { $x->header('Content-Length' => 100) },
            },
        );
    },
    get_content_length => sub {
        local %ENV;
        my $h = HTTP::Headers->new;
        $ENV{PERL_HTTP_HEADERS_FAST_XS} = 0;
        my $f = HTTP::Headers::Fast->new;
        $ENV{PERL_HTTP_HEADERS_FAST_XS} = 1;
        my $x = HTTP::Headers::Fast->new;

        cmpthese(
            1000000 => {
                orig => sub { $h->content_length },
                fast => sub { $f->content_length },
                xs   => sub { $x->content_length },
            },
        );
    },
    as_string_without_sort => sub {
        local %ENV;
        my $h = HTTP::Headers->new(%source);
        $ENV{PERL_HTTP_HEADERS_FAST_XS} = 0;
        my $f = HTTP::Headers::Fast->new(%source);
        $ENV{PERL_HTTP_HEADERS_FAST_XS} = 1;
        my $x = HTTP::Headers::Fast->new(%source);

        cmpthese(
            100000 => {
                orig           => sub { $h->as_string },
                fast_as_str    => sub { $f->as_string },
                fast_as_str_wo => sub { $f->as_string_without_sort },
                xs_as_str      => sub { $x->as_string },
                xs_as_str_wo   => sub { $x->as_string_without_sort },
            },
        );
    },
    as_string => sub {
        local %ENV;
        my $h = HTTP::Headers->new(%source);
        $ENV{PERL_HTTP_HEADERS_FAST_XS} = 0;
        my $f = HTTP::Headers::Fast->new(%source);
        $ENV{PERL_HTTP_HEADERS_FAST_XS} = 1;
        my $x = HTTP::Headers::Fast->new(%source);

        cmpthese(
            100000 => {
                orig => sub { $h->as_string },
                fast => sub { $f->as_string },
                xs   => sub { $x->as_string },
            },
        );
    },
);

my $only = shift @ARGV;
print "HTTP::Headers $HTTP::Headers::VERSION, HTTP::Headers::Fast $HTTP::Headers::Fast::VERSION\n";
while (my ($name, $code) = splice(@cases, 0, 2)) {
    next if $only && $only ne $name;
    print "-- $name\n";
    $code->();
    print "\n";
}

