use 5.008005;
use ExtUtils::MakeMaker;
WriteMakefile(
    NAME           => 'HTTP::Headers::Fast::XS',
    VERSION_FROM   => 'lib/HTTP/Headers/Fast/XS.pm',
    ABSTRACT_FROM  => 'lib/HTTP/Headers/Fast/XS.pm',
    PREREQ_PM      => {
        'Test::More'          => 0,
        'Exporter'            => '5.57',
        'XSLoader'            => 0,
        'HTTP::Headers::Fast' => '0.18',
    },
    AUTHOR         => 'Sawyer X (xsawyerx@cpan.org)',
    LIBS           => [''],
    DEFINE         => '',
    CCFLAGS        => '-Wall',
    INC            => '-I.',
    #OBJECT         => '$(O_FILES)',
);
