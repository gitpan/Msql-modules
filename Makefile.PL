#   Hej, Emacs, don't you see this is -*- perl -*- mode? :-)
#
#   Copyright (c) 1997  Andreas König, Jochen Wiedmann
#
#  You may distribute this under the terms of either the GNU General Public
#  License or the Artistic License, as specified in the Perl README file,
#  with the exception that it cannot be placed on a CD-ROM or similar media
#  for commercial distribution without the prior approval of the author.
#
#  $Id: Makefile.PL,v 1.1809 1997/09/12 18:29:15 joe Exp $
#
BEGIN {require 5.002;}
use ExtUtils::MakeMaker;
use Config;
# use strict; # we're possibly still 5.002 compliant ?

$| = 1;
print "Checking for Data::ShowTable ... ";
eval { use Data::ShowTable (); };
if ($@) {
    print STDERR "\n\n";
    print STDERR "You don't have installed the 'Data::ShowTable' module.\n";
    print STDERR "You won't be able to use 'dbimon', the DBI monitor until.\n";
    print STDERR "'Data::ShowTable' is installed. You get it at the CPAN.\n";
    print STDERR "See 'man CPAN' or 'perldoc CPAN' for more info.\n";
    print STDERR "I will install 'dbimon' anyways.\n\n";
} else {
    print "ok\n";
}

$Verbose++ if $ENV{USER} eq "k";

WriteMakefile(
	      'NAME'         => "Msql",
	      'DISTNAME'     => "Msql-modules",
	      'dist'         => { 'SUFFIX'       => ".gz",
				  'DIST_DEFAULT' => 'all tardist',
				  'COMPRESS'     => "gzip -9f" },
	      'VERSION_FROM' => "lib/Msql.pm",
	      'EXE_FILES'    => [qw(pmsql dbimon)],
	      'PREREQ_PM'    => { 'DBI' => 0.88 },
	      'CONFIGURE'    => \&Msql::Config::initialize,
	      'clean'        => { 'FILES' => "*.bak */*.bak */*/*.bak"
				             . " dbimon pmsql" }
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

sub Modify ($$$) {
    my($source, $dest, $mref) = @_;

    $Msql::Config::EndSeen = 0;
    if (!open(INFILE, "<$source")) {
	print STDERR "Cannot read $source: $!\n";
	exit 10;
    }
    if (!open(OUTFILE, ">$dest.new")) {
	print STDERR "Cannot create $dest.new: $!\n";
	exit 10;
    }
    while (defined($line = <INFILE>)) {
	$line = &$mref($line);
	if (!(print OUTFILE $line)) {
	    print STDERR "Cannot write $dest.new: $!\n";
	}
    }
    close(INFILE);
    close(OUTFILE);
    if (-f "$dest.bak"  &&  !unlink "$dest.bak") {
	print STDERR "Cannot remove $dest.bak: $!\n";
	exit 10;
    }
    if (!rename("$dest", "$dest.bak")) {
	print STDERR "Cannot rename $file to $dest.bak\n";
	exit 10;
    }
    if (!rename("$dest.new", "$dest")) {
	print STDERR "Cannot rename $dest.new to $dest: $!\n";
	exit 10;
    }
    unlink "$dest.bak";
}


sub initialize {
    return \%X if %X;
    %X=();
    my @msqldir =
	qw{
	   /usr/local/Hughes
	   /usr/local/Minerva
	   /usr/local
	   /usr/mSQL
	   /opt/mSQL
	  };
    unshift @msqldir, $ENV{MSQL_HOME} if exists $ENV{MSQL_HOME};

    my $mref = sub {
	$line = shift;
	if ($line =~ /__END__/) {
	    $Msql::Config::EndSeen = 1;
	} elsif (!$Msql::Config::EndSeen) {
	    $line =~ s/DBD\:\:mysql/DBD\:\:mSQL/g;
	    $line =~ s/DBI\:mysql/DBI\:mSQL/g;
	    $line =~ s/mysql\.xsi/mSQL\.xsi/g;
	    if ($line =~ /DBI\:\:_new_drh/) {
		$line =~ s/mysql/mSQL/g;
	    }
	}
	$line;
    };
    my $mref2 = sub {
	$line = shift;
	if ($line =~ /__END__/) {
	    $Msql::Config::EndSeen = 1;
	} elsif (!$Msql::Config::EndSeen) {
	    if ($line =~ /^\s*(use|require|bootstrap|package)\s+.*\;\s+$/) {
	    	$line =~ s/Mysql/Msql/g;
	    }
	}
	$line;
    };
    Modify("DBD-mSQL/mSQL.xs", "DBD-mSQL/mSQL.xs", $mref);
    Modify("lib/DBD/mSQL.pm", "lib/DBD/mSQL.pm", $mref);
    Modify("lib/Msql.pm", "lib/Msql.pm", $mref2);
    Modify("lib/Msql/Statement.pm", "lib/Msql/Statement.pm", $mref2);

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
    # the necessity to determine how many arguments are needed for
    # msqlget*conf is due to random changes in the API
    my $version = "MSQL1";
    my $getconf = "";
    open MSQL, "$headerdir/msql.h" 
	or die "Couldn't open $headerdir/msql.h: $!";
    local $/ = "\n";
    while (<MSQL>) {
	if (/IDX_TYPE/) {
	    $version = "MSQL2";
	}
	if (
	    m{
	      ^
	      (int|char)
	      \s+
	      \*?
	      msqlGet
	      (Int|Char)
	      Conf
	      \s+
	      __ANSI_PROTO
	      \(\(
	      char
	      \s*
	      \*\)\)
	     }x
	   ) {
	    $getconf = " -DMSQLGETXCONF1";
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
	print q{Oh dear. Solaris? Let's add some more flags into the linker stage...
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
    $X{DEFINE}   = "-DDBD_MSQL -D$version$getconf";
    $X{LIBS}     = $sysliblist;
    $X{INC}      = "-I$headerdir -I\$(INSTALLSITEARCH)/auto/DBI -I\$(INSTALLARCHLIB)";
    $X{H}        = \@headerfiles;
    \%X;
}

