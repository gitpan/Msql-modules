BEGIN {require 5.002;}
use ExtUtils::MakeMaker;
use Config;
# use strict; # we're possibly still 5.002 compliant ?

$Verbose++ if $ENV{USER} eq "k";

WriteMakefile(
	      NAME       => "Msql::Integrat",
	      "DISTNAME" => "Msql-modules",
	      "dist"     => { SUFFIX   => ".gz", DIST_DEFAULT => 'all tardist',
			      COMPRESS => "gzip -9f" },
	      VERSION_FROM => "lib/Msql/Integrat.pm",
	      EXE_FILES => [qw(pmsql)],
	      CONFIGURE  => \&Msql::Config::initialize,
);

package MY;	# so that "SUPER" works right
sub test {
    my $inherited = shift->SUPER::test(@_);
    # warn "pre inherited[$inherited]";
    my $matched = $inherited =~ s/(test\s*::[^\n]*\n)(\t[^\n]+\n)*\n/$1\n/s;
    # warn "inherited matched[$matched]";
    $inherited;
}

package Msql::Config;
use ExtUtils::MakeMaker qw(prompt);
use Config;
use vars qw(%X);
%X = ();

sub initialize {
    return \%X if %X;
    %X=();
    my @msqldir = ($ENV{MSQL_HOME}, qw{/usr/local/Hughes /usr/local/Minerva /usr/local /usr/mSQL /opt/mSQL});
    my($msqldir,$gooddir);

    for $msqldir (@msqldir) {
	if (-f "$msqldir/include/msql.h") {
	    $gooddir = $msqldir;
	    last;
	}
    }
    $gooddir ||= $msqldir[0];
    $gooddir = prompt("
Where is your msql installed? Please tell me the directory that contains
the subdirs lib/ and include/.",$gooddir) || $gooddir # || for 5.002
    unless exists $ENV{MSQL_HOME} && $gooddir eq $ENV{MSQL_HOME};

    my $headerdir="$gooddir/include";
    die "No msql.h file found\n" unless -f "$headerdir/msql.h";

    # the necessity to determine the version at this stage is legacy ADESC
    my $version = "MSQL1";
    open MSQL, "$headerdir/msql.h" 
	or die "Couldn't open $headerdir/msql.h: $!";
    local $/ = "\n";
    while (<MSQL>) {
	if (/IDX_TYPE/) {
	    $version = "MSQL2";
	    last;
	}
    }

    my $libdir="$gooddir/lib";
    
    my $extralibs = "";
    my $linkwith = "";
    if ( $Config{osname} eq 'sco_sv' ) { # Some extra libraries need added for SCO
	print q{Yuk! I see that you are a SCO Unix system. We\'ll add -lc to the list of
libraries to link with...
};
	$extralibs = "-lc";
    } elsif ( $Config{osname} eq 'solaris' ) {
	# We need to link with -R if we're on Solaris.......Brain-damaged....
	print q{Oh dear. Solaris? Let\'s add some more flags into the linker stage...
};
	$linkwith = "-L$libdir -R$libdir";
    } elsif ( $Config{osname} eq 'hpux' ) {
	# We need to add +z to the list of CFLAGS if we're on HP-SUX, or -fPIC 
	# if we're on HP-SUX and using 'gcc'
	if ( $Config{cccdlflags} eq '+z' ) {
	    print q{You\'re building on HP-UX with the HP compiler.
You might get a warning at the link stage of:

    ld: DP-Relative Code in file .../libmsql.a(libmsql.o)
    >  - Shared Library must be Position-Independent

You\'ll have to recompile libmsql.a from the mSQL distribution with the
    '+z' flag of your C compiler.
};
	  } elsif( $Config{cccdlflags} eq '-fPIC' ) {
	    print q{You\'re building on HP-UX with the GNU C Compiler.
You might get a warning at the link stage like:

    ld: DP-Relative Code in file .../libmsql.a(libmsql.o)
    >  - Shared Library must be Position-Independent

You\'ll have to recompile libmsql.a from the mSQL distribution specifying
the '-fPIC' flag to produce Position-Independent code.
};
	  }
    }

    # List the libraries we're linking with (ADESC)
    my $sysliblist = "-L$libdir -lmsql -lm $extralibs";

    my(@headerfiles) = ("$headerdir/msql.h");
    $X{macro} = {MSQL_HOME => $gooddir};
    $X{dynamic_lib} = { OTHERLDFLAGS => '-L$(MSQL_HOME)/lib ' . $linkwith } if $linkwith;
    $X{DEFINE}   = "-D$version";
    $X{LIBS}     = $sysliblist;
    $X{INC}      = "-I$headerdir -I\$(INSTALLSITEARCH)/auto/DBI -I\$(INSTALLARCHLIB)";
    $X{H}        = \@headerfiles;
    \%X;
}

