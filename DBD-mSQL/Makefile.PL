#!/usr/local/bin/perl -sw

use ExtUtils::MakeMaker;
use Config;

$@ = '';
eval "use DBI 0.86; use DBI::DBD;";
if ($@) {
    warn q{Warning:
You haven't installed DBI version 0.86 or later. You will not be able
to build DBD::mSQL without prior installation of the DBI module.
};
    open MAKE, ">Makefile" or die "Couldn't open >Makefile: $!";
    print MAKE q{
all:

test:

};
    close MAKE;
    die "Skipping make for DBD::mSQL";
}


if ($ENV{'LOCAL_PERL'}) {
      WriteMakefile(
		    NAME => 'DBD::mSQL',
		    INC => '-I/sw/linux-i386/msql-1.0.16/include -I../DBD-mSQL -I/sw/linux-i386/perl-5.004.03/lib/site_perl/auto/DBI',
		    LIBS => '-L/sw/linux-i386/msql-1.0.16/lib -lmsql',
		    VERSION_FROM => "../lib/DBD/mSQL.pm",
		    SKIP => [qw(test)],
		    OBJECT => '$(O_FILES)',
		    DEFINE => '-DDBD_MSQL -DMyConnect=dbd_db_connect'
		  );
      exit 0;
}


sub config () {
    my $ref = &Msql::Config::initialize();
    my %hash = %$ref;
    $hash{'DEFINE'} .= " -DMyConnect=dbd_db_connect";
    $hash{'clean'} = { 'FILES' => 'mSQL.xsi' };
    \%hash;
}


WriteMakefile(
	      NAME         => 'DBD::mSQL',
	      VERSION_FROM => '../lib/DBD/mSQL.pm',
	      OBJECT       => qq[\$(O_FILES)],
	      SKIP         => ['test'],
	      CONFIGURE    => \&config
	     );


sub MY::postamble {
    return dbd_postamble();
}

