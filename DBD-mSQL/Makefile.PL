#!/usr/local/bin/perl -sw

use ExtUtils::MakeMaker;
use Config;

eval {require DBI}; # The DBI must be installed before we can build a DBD

if ($@) {
    warn q{Warning:
    DBI.pm not found in @INC
You will not be able to build DBD::mSQL without prior installation
of the DBI module.
};
    open MAKE, ">Makefile" or die "Couldn't open >Makefile: $!";
    print MAKE q{
all:

test:

};
    close MAKE;
    die "Skipping make for DBD::mSQL";
} elsif ($DBI::VERSION < 0.84) {
    warn q{WARNING from evaluation of DBD-mSQL/Makefile.PL:
    DBI.pm version $DBI::VERSION too old
You will not be able to build DBD::mSQL without prior installation
of the DBI module version 0.84 or higher.
};
    open MAKE, ">Makefile" or die "Couldn't open >Makefile: $!";
    print MAKE q{
all:

test:

};
    close MAKE;
    die "Skipping make for DBD::mSQL";
}

WriteMakefile(
	      NAME         => 'DBD::mSQL',
	      VERSION_FROM => '../lib/DBD/mSQL.pm',
	      OBJECT       => qq[\$(O_FILES)],
	      SKIP         => ['test'],
	      CONFIGURE    => \&Msql::Config::initialize,
	     );

