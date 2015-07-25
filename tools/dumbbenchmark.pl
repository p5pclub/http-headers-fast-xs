use strict;
use warnings;
use Dumbbench;
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
    _standardize_field_name => [
        sub {
            HTTP::Headers::Fast::_standardize_field_name('Foo-Bar')
                for 1 .. 1e6
        },
    ],
    push_header => [
        sub {
            my $f = HTTP::Headers::Fast->new;
            $f->push_header('X-Foo' => 1) for 1 .. 1e5;
        },
    ],

    push_header_many => [
        sub {
            my $f = HTTP::Headers::Fast->new;
            $f->push_header('X-Foo' => 1, 'X-Bar' => 2) for 1 .. 3e5;
        },
    ],

    get_date => [
        sub {
            my $f = HTTP::Headers::Fast->new;
            $f->date(1226370757);
            $f->date for 1 .. 3e5;
        },
    ],

    set_date => [
        sub {
            my $f = HTTP::Headers::Fast->new;
            $f->date(1226370757) for 1 .. 1e5;
        },
    ],

    scan => [
        sub {
            my $f = HTTP::Headers::Fast->new(%source);
            $f->scan(sub { }) for 1 .. 1e5;
        },
    ],

    get_header => [
        sub {
            my $f = HTTP::Headers::Fast->new;
            $f->header('Content-Length') for 1 .. 1e6;
        },
    ],

    set_header => [
        sub {
            my $f = HTTP::Headers::Fast->new;
            $f->header('Content-Length' => 100) for 1 .. 1e6;
        },
    ],

    get_content_length => [
        sub {
            my $f = HTTP::Headers::Fast->new;
            $f->content_length for 1 .. 1e6;
        },
    ],

    as_string_without_sort => [
        # fast_as_str
        sub {
            my $f = HTTP::Headers::Fast->new(%source);
            $f->as_string for 1 .. 1e5;
        },

        # fast_as_str_wo
        sub {
            my $f = HTTP::Headers::Fast->new(%source);
            $f->as_string_without_sort for 1 .. 1e5;
        },
    ],

    as_string => [
        sub {
            my $f = HTTP::Headers::Fast->new(%source);
            $f->as_string for 1 .. 1e5;
        },
    ],
);

my $only = shift @ARGV;
print "HTTP::Headers::Fast $HTTP::Headers::Fast::VERSION\n";
while (my ($name, $code) = splice(@cases, 0, 2)) {
    my $bench = Dumbbench->new(
        target_rel_precision => 0.005,
        initial_runs         => 20,
    );

    $bench->add_instances(
        map Dumbbench::Instance::PerlSub->new(
            name => $name,
            code => $_,
        ), @{$code}
    );

    next if $only && $only ne $name;
    print "-- $name\n";
    $bench->run;
    $bench->report;
    print "\n";
}

