sub config () {
    my $ref = Msql::Config::initialize();
    my %hash = %$ref;
    $hash{'INC'} .= " -I../DBD-mSQL";
    \%hash;
}

WriteMakefile(
	      NAME => 'Msql',
	      VERSION_FROM => "../lib/Msql.pm",
	      SKIP => [qw(test)],
	      OBJECT => '$(O_FILES)',
	      CONFIGURE  => \&config,
);
