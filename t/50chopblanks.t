#!/usr/local/bin/perl
#
#   $Id: 50chopblanks.t,v 1.1806 1997/09/03 22:38:16 joe Exp $
#
#   This driver should check whether 'ChopBlanks' works.
#


#
#   List of drivers that may execute this test; if this list is
#   empty, than any driver may execute the test.
#
#@DRIVERS_ALLOWED = ();


#
#   List of drivers that may not execute this test; this list is
#   only used if @DRIVERS_ALLOWED is empty
#
#@DRIVERS_DENIED = ();


#
#   Make -w happy
#
use vars qw($test_dsn $test_user $test_password $driver $verbose $state);
use vars qw($COL_NULLABLE $COL_KEY);
$test_dsn = '';
$test_user = '';
$test_password = '';


#
#   Include lib.pl
#
use DBI;
use strict;
$driver = "";
{
    my $file;
    foreach $file ("lib.pl", "t/lib.pl") {
	do $file; if ($@) { print STDERR "Error while executing lib.pl: $@\n";
			    exit 10;
			}
	if ($driver ne '') {
	    last;
	}
    }
}

sub ErrMsg (@_) { if ($verbose) { print (@_); } }
sub ErrMsgF (@_) { if ($verbose) { printf (@_); } }

sub ServerError() {
    print STDERR ("Cannot connect: ", $DBI::errstr, "\n",
	"\tEither your server is not up and running or you have no\n",
	"\tpermissions for acessing the DSN $test_dsn.\n",
	"\tThis test requires a running server and write permissions.\n",
	"\tPlease make sure your server is running and you have\n",
	"\tpermissions, then retry.\n");
    exit 10;
}

#
#   Main loop; leave this untouched, put tests after creating
#   the new table.
#
while (Testing()) {
    my ($dbh, $sth, $query);

    #
    #   Connect to the database
    Test($state or ($dbh = DBI->connect($test_dsn, $test_user,
					$test_password)))
	   or ServerError();

    #
    #   Find a possible new table name
    #
    my $table = '';
    Test($state or $table = FindNewTable($dbh))
	   or ErrMsgF("Cannot determine a legal table name: Error %s.\n",
		      $dbh->errstr);

    #
    #   Create a new table; EDIT THIS!
    #
    Test($state or ($query = TableDefinition($table,
				      ["id",   "INTEGER",  4, $COL_NULLABLE],
				      ["name", "CHAR",    64, $COL_NULLABLE]),
		    $dbh->do($query)))
	or ErrMsgF("Cannot create table: Error %s.\n",
		      $dbh->errstr);


    #
    #   and here's the right place for inserting new tests:
    #
    my @rows = ([1, ''],
		[2, ' '],
		[3, ' a b c ']);
    my $ref;
    foreach $ref (@rows) {
	my ($id, $name) = @$ref;
	if (!$state) {
	    $query = sprintf("INSERT INTO $table (id, name) VALUES ($id, %s)",
			     $dbh->quote($name));
	}
	Test($state or $dbh->do($query))
	    or ErrMsgF("INSERT failed: query $query, error %s.\n",
		       $dbh->errstr);
        $query = "SELECT id, name FROM $table WHERE id = $id\n";
	Test($state or ($sth = $dbh->prepare($query)))
	    or ErrMsgF("prepare failed: query $query, error %s.\n",
		       $dbh->errstr);

	# First try to retreive without chopping blanks.
	$sth->{'ChopBlanks'} = 0;
	Test($state or $sth->execute)
	    or ErrMsgF("execute failed: query $query, error %s.\n",
		       $sth->errstr);
	Test($state or defined($ref = $sth->fetchrow_arrayref))
	    or ErrMsgF("fetch failed: query $query, error %s.\n",
		       $sth->errstr);
	Test($state or ($$ref[1] eq $name)
	            or ($name =~ /^$$ref[1]\s+$/  &&
			($driver eq 'mysql'  ||  $driver eq 'pNET')))
	    or ErrMsgF("problems with ChopBlanks = 0:"
		       . " expected '%s', got '%s'.\n",
		       $name, $$ref[1]);

	# Now try to retreive with chopping blanks.
	$sth->{'ChopBlanks'} = 1;
	Test($state or $sth->execute)
	    or ErrMsg("execute failed: query $query, error %s.\n",
		      $sth->errstr);
	my $n = $name;
	$n =~ s/^\s+//;
	$n =~ s/\s+$//;
	Test($state or defined($ref = $sth->fetchrow_arrayref))
	    or ErrMsgF("fetch failed: query $query, error %s.\n",
		       $sth->errstr);
	Test($state or ($$ref[1] eq $n))
	    or ErrMsgF("problems with ChopBlanks = 1:"
		       . " expected '%s', got '%s'.\n",
		       $n, $$ref[1]);

	Test($state or $sth->finish)
	    or ErrMsgF("Cannot finish: %s.\n", $sth->errstr);
    }

    #
    #   Finally drop the test table.
    #
    Test($state or $dbh->do("DROP TABLE $table"))
	   or ErrMsgF("Cannot DROP test table $table: %s.\n",
		      $dbh->errstr);

    #   ... and disconnect
    Test($state or $dbh->disconnect)
	or ErrMsgF("Cannot disconnect: %s.\n", $dbh->errmsg);
}
