#!/usr/bin/perl

use warnings;
use strict;

use Dumbbench;
use Getopt::Long;

use HTTP::Headers::Fast;

my %cases = (
    _standardize_field_name => sub {
        my ($instance, $iterations) =  @_;
        for (1..$iterations) {
            HTTP::Headers::Fast::_standardize_field_name('X-Foo');
        };
    },
    push_header => sub {
        my ($instance, $iterations) = @_;
        my $headers = HTTP::Headers::Fast->new();
        for (1..$iterations) {
            $headers->push_header("X-Foo" => "Bar");
        }
    },
    push_header_many => sub {
        my ($instance, $iterations) = @_;
        my $headers = HTTP::Headers::Fast->new();
        for (1..$iterations) {
            $headers->push_header("X-Foo" => "Bar", "X-Bar" => 2, "X-Baz" => 3);
        }
    },
    get_date => sub {
        my ($instance, $iterations) = @_;
        my $headers = HTTP::Headers::Fast->new();
        $headers->date(1226370757);
        for (1..$iterations) {
            $headers->date;
        }
    },
    set_date => sub {
        my ($instance, $iterations) = @_;
        my $headers = HTTP::Headers::Fast->new();
        for (1..$iterations) {
            $headers->date(1226370757);
        }
    },
    scan => sub {
        my ($instance, $iterations) = @_;
        my $headers = HTTP::Headers::Fast->new();
        for (1..$iterations) {
            $headers->scan();
        }
    },
    get_header => sub {
        my ($instance, $iterations) = @_;
        my $headers = HTTP::Headers::Fast->new();
        $headers->header("X-Foo", 1);
        for (1..$iterations) {
            $headers->header("X-Foo");
        }
    },
    set_header => sub {
        my ($instance, $iterations) = @_;
        my $headers = HTTP::Headers::Fast->new();
        for (1..$iterations) {
            $headers->header("Content-Length", 10);
        }
    },
    get_content_length => sub {
        my ($instance, $iterations) = @_;
        my $headers = HTTP::Headers::Fast->new();
        for (1..$iterations) {
            $headers->content_length;
        }
    },
    as_string_without_sort => sub {
        my ($instance, $iterations) = @_;
        my $headers = HTTP::Headers::Fast->new();
        for (1..$iterations) {
            $headers->as_string_without_sort;
        }
    },
    as_string => sub {
        my ($instance, $iterations) = @_;
        my $headers = HTTP::Headers::Fast->new();
        for (1..$iterations) {
            $headers->as_string;
        }
    },
);

my $iterations   = 1e4;
my $initial_runs = 25;
my $verbose      = 0;
my $cases;

GetOptions ("iterations=i"   => \$iterations,
            "initial_runs=i" => \$initial_runs,
            "verbose"        => \$verbose,
            "cases=s"        => \$cases,
    ) or die("Error in command line arguments\n");

my @run_cases = sort keys %cases;
if ($cases){
    @run_cases = split ',', $cases;
}

my $bench   = execute_benchmark(\@run_cases);

# enable the XS functions
require HTTP::Headers::Fast::XS;

my $xs_bench = execute_benchmark(\@run_cases);

my @instances    = $bench->instances;
my @xs_instances = $xs_bench->instances;
$bench->report if $verbose;
$xs_bench->report if $verbose;

foreach my $case_index (0..$#run_cases){
    my $case      = $run_cases[$case_index];
    my $original  = $instances[$case_index]->{result}{num};
    my $xs        = $xs_instances[$case_index]->{result}{num};

    # speedup
    printf("%-30s -- %.2f\n", $case, $original / $xs);
}

sub execute_benchmark {
    my $run_cases = shift;

    my $bench = Dumbbench->new(
        target_rel_precision => 0.005, # seek ~0.5%
        verbosity            => $verbose,
        initial_runs         => $initial_runs,
    );

    foreach my $case (@$run_cases){
        $bench->add_instances(
            Dumbbench::Instance::PerlSub->new(code => sub {
                my $original = HTTP::Headers::Fast->new();
                $cases{$case}->($original, $iterations);
            })
        );
    }
    $bench->run();
    return $bench;
}
