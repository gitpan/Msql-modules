WriteMakefile(
	      NAME => 'Msql',
	      VERSION_FROM => "../lib/Msql.pm",
	      SKIP => [qw(test)],
	      CONFIGURE  => \&Msql::Config::initialize,
);
