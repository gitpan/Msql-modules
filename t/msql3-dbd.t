BEGIN {
    eval {require DBI};
    if ($@) {
	$|=1;
	print STDERR "DBI not available. ";
	print STDOUT "1..0\n";
	undef $@;
	$EXIT = 1; # exit 0 here did leave exit status wstat 11 on linux (?)
    } else {
	print "1..41\n";
    }
}
exit 0 if $EXIT;
use strict;


print "ok 1\n";

my $test_hostname ||= '';

my($drh,$dbh,@databases,$rv,$sth);
if ( $drh = DBI->install_driver( 'mSQL' ) ){
    print "ok 2\n";
} else {
    print qq{not ok 2: DBI->install_driver( 'mSQL' ) failed.
DBI cannot find DBD::mSQL in the \@INC path, which currently is
  @INC
};
}

if ( @databases = $drh->func( $test_hostname, '_ListDBs' ) ) {
    print "ok 3\n";
} else {
    die qq{Not ok 3: \$drh->func( '$test_hostname', '_ListDBs' ) failed.
Please, make sure you have at least one database created
};
}

my $test_dbname ||= $databases[0];

### Test the connection routines. First, connect to a database
if ( $dbh = DBI->connect( "dbi:mSQL:$test_dbname:$test_hostname", undef, undef, {PrintError => 0} ) ){
    print "ok 4\n";
}else {
    die qq{not ok 4: DBI->connect( "dbi:mSQL:$test_dbname:$test_hostname" )
failed. Make sure host and database exist or change the textscript
accordingly. Also check you have permission
to access the database ( as defined in the mSQL ACL file ).
You may also want to check that the database hasn\'t
inadvertently crashed since the last test!
};
}

my $test_table;
# we know this trick from msql.t, but here we repeat it with DBD
{
    my $goodtable = "TABLE00";
    my(%foundtable);
    @foundtable{@databases} = (1) x @databases; # all existing tables are now keys in %foundtable
    my $limit = 0;

    while () {
	next if $foundtable{++$goodtable};
	my $query = qq{
	    create table $goodtable (
				     she char(32),
				     him char(32) not null,
				     who char (32)
				    )
	};
	unless ($dbh->do($query)){
	    die "Cannot create table: query [$query] message [$DBI::errstr]\n" if $limit++ > 1000;
	    next;
	}
	$test_table = $goodtable;
	last;
    }
}

### ...and disconnect
if ( $dbh->disconnect ){
    print "ok 5\n";
} else {
    print qq{not ok 5: \$dbh->disconnect() failed!
Make sure your server is still functioning correctly, and check to make
sure your network isn\'t malfunctioning in the case of the server running
on a remote machine
};
}


### Now, re-connect again so that we can do some more complicated stuff..
if ( $dbh = DBI->connect( "dbi:mSQL:$test_dbname:$test_hostname" ) ){
    print "ok 6\n";
} else {
    print "not ok 6\n";
}


### List all the tables in the selected database........
if ( $dbh->func( '_ListTables' ) ){
    print "ok 7\n";
} else {
    print qq{not ok 7: \$dbh->func( '_ListTables' ) failed!
This could be due to the fact you have no tables, but I hope not. You
could try running 'relshow -h $test_hostname $test_dbname' and see if
reports any information about your database, or errors
};
}

if (
    $dbh->do( "DROP TABLE $test_table" )
    &&
    $dbh->do( "CREATE TABLE $test_table ( id INTEGER, name CHAR(64) )" )
   ){
    print "ok 8\n";
} else {
    print "not ok 8: $DBI::errstr\n";
}

### Get some meta-data for the table we've just created...
print "Testing: \$dbh->func( $test_table, '_ListFields' )\n";
my $ref;
if ( $ref = $dbh->func( $test_table, '_ListFields' ) ){
    print "ok 9\n" ;
} else {
    print "not ok 9: $DBI::errstr\n";
}


### Insert a row into the test table.......
print "Testing: \$dbh->do( 'INSERT INTO $test_table VALUES ( 1, 'Alligator Descartes' )' )\n";
( $dbh->do( "INSERT INTO $test_table VALUES( 1, 'Alligator Descartes' )" ) )
    and print( "ok 10\n" )
    or die "not ok 10: $DBI::errstr\n";

### ...and delete it........
print "Testing: \$dbh->do( 'DELETE FROM $test_table WHERE id = 1' )\n";
( $dbh->do( "DELETE FROM $test_table WHERE id = 1" ) )
    and print( "ok 11\n" )
    or die "not ok 11: $DBI::errstr\n";

### Now, try SELECT'ing the row out. This should fail.
print "Testing: \$sth = \$dbh->prepare( 'SELECT * FROM $test_table WHERE id = 1' )\n";
if ( $sth = $dbh->prepare( "SELECT * FROM $test_table WHERE id = 1" ) ){
    print( "ok 12\n" );
} else {
    print( "not ok 12: $DBI::errstr\n" );
}

# ADESC says, this should fail, but he pleasantly prints "not ok"?
# I don't even see, why it should fail.
print "Testing: \$sth->execute\n";
if ( $sth->execute ){
    print( "ok 13\n" );
} else {
    print( "not ok 13: $DBI::errstr\n" );
}


print "*** Expect this test to fail with NO error message!\n";
print "Testing: \$sth->fetchrow\n";
my(@row);
{
    local($^W) = 0;
    if ( @row = $sth->fetchrow ) {
	print( "not ok 14: $DBI::errstr\n" );
    } else {
	print( "ok 14: $DBI::errstr\n" );
    }
}

print "Testing: \$sth->finish\n";
if ( $sth->finish ){
    print( "ok 15\n" )
} else {
    print( "not ok 15: $DBI::errstr\n" );
}

# Temporary bug-plug
undef $sth;

### This section should exercise the sth->func( '_NumRows' ) private method
### by preparing a statement, then finding the number of rows within it.
### Prior to execution, this should fail. After execution, the number of
### rows affected by the statement will be returned.
print "Re-testing: \$dbh->do( 'INSERT INTO $test_table VALUES ( 1, 'Alligator Descartes' )' )\n";
if ( $dbh->do( "INSERT INTO $test_table VALUES( 1, 'Alligator Descartes' )" ) ){
    print "ok 16\n";
}else {
    print "not ok 16: $DBI::errstr\n";
}

print "Re-testing: \$sth = \$dbh->prepare( 'SELECT * FROM $test_table WHERE id = 1' )\n";
if ( $sth = $dbh->prepare( "SELECT * FROM $test_table WHERE id = 1" ) ){
    print "ok 17\n";
} else {
    print "not ok 17: $DBI::errstr\n";
}

print "Testing: \$sth->func( '_NumRows' ) before execute. Expect a failure\n";
my $numrows;
if ( $numrows = $sth->func( '_NumRows' ) ){
    print( "not ok 18: $DBI::errstr\n" );
} else {
    print "ok 18:\n";
}

print "Re-testing: \$sth->execute\n";
if ( $sth->execute ){
    print "ok 19\n";
} else {
    print( "not ok 19: $DBI::errstr\n" );   
}

print "Re-testing: \$sth->func( '_NumRows' ) after execute.\n";
if ( $numrows = $sth->func( '_NumRows' ) ){
    print "ok 20\n";
} else {
    print "not ok 20: $DBI::errstr\n";
}

print "Re-testing: \$sth->finish\n";
if ( $sth->finish ){
    print "ok 21\n";
} else {
    print "not ok 21: $DBI::errstr\n";   
}

# Temporary bug-plug
undef $sth;

### Test whether or not a field containing a NULL is returned correctly
### as undef, or something much more bizarre
print "Testing: \$sth->do( 'INSERT INTO $test_table VALUES ( NULL, 'NULL-valued ID' )' )\n";
if ( $dbh->do( "INSERT INTO $test_table VALUES ( NULL, 'NULL-valued id' )" ) ){
    print "ok 22\n";
} else {
    print "not ok 22: $DBI::errstr\n";
}

print "Testing: \$sth = \$dbh->prepare( 'SELECT id FROM $test_table WHERE id = NULL' )\n";
if ( $sth = $dbh->prepare( "SELECT id FROM $test_table WHERE id = NULL" ) ){
    print "ok 23\n";
} else {
    die "not ok 23: $DBI::errstr\n";   
}

$sth->execute;

print "Testing: \$sth->fetchrow\n";
if ( ( $rv ) = $sth->fetchrow ){
  print "ok 24\n"
} else {
  print "not ok 24: $DBI::errstr\n";
}

if ( !defined $rv ) {
    print "ok 25\n";
} else {
    print "not ok 25\n";
}

print "Testing: \$sth->finish\n";
if ( $sth->finish ){
    print "ok 26\n"
} else {
    print "not ok 26\n";
}
# Temporary bug-plug
undef $sth;

### Delete the test row from the table
$rv = $dbh->do(
	       "DELETE FROM $test_table " .
	       "WHERE id = NULL AND name = 'NULL-valued id'"
	      );

### Test whether or not a char field containing a blank is returned correctly
### as blank, or something much more bizarre

print "Testing: \$sth->do( 'INSERT INTO $test_table VALUES ( 2, '' )' )\n";
if ( $rv = $dbh->do( "INSERT INTO $test_table VALUES ( 2, '' )" ) ){
    print( "ok 27\n" )
} else {
    print "not ok 27: $DBI::errstr\n";
}
print "Testing: \$sth = \$dbh->prepare( 'SELECT name FROM $test_table WHERE id = 2 AND name = '')\n";
if ( $sth = $dbh->prepare( "SELECT name FROM $test_table WHERE id = 2 AND name = ''" ) ){
    print "ok 28\n"
}  else {
    print "not ok 28: $DBI::errstr\n";
}

$sth->execute;

$rv = undef;
print "Testing: \$sth->fetchrow\n";
if ( ( $rv ) = $sth->fetchrow ){
    print "ok 29\n"
} else {
    print "not ok 29: $DBI::errstr\n";
}

if ( defined ($rv) && $rv eq '' ) {
    print "ok 30 test passes. blank value returned as blank\n";
} else {
    print "not ok 30: test failed. blank value returned as ",
	defined ($rv) ? $rv : 'undef', "\n";
}

print "Testing: \$sth->finish\n";
if ( $sth->finish ){
    print "ok 31\n"
} else {
    print "not ok 31\n";
}

# Temporary bug-plug
undef $sth;

### Delete the test row from the table
$rv = $dbh->do( 
	       "DELETE FROM $test_table WHERE id = 2 AND name = ''"
	      );

### Test the new funky routines to list the fields applicable to a SELECT
### statement, and not necessarily just those in a table...
print "Re-testing: \$sth = \$dbh->prepare( 'SELECT * FROM $test_table' )\n";
if ( $sth = $dbh->prepare( "SELECT * FROM $test_table" ) ){
    print "ok 32\n"
} else {
    die "not ok 32: $DBI::errstr\n";
}

$sth->execute;

print "Testing: \$sth->func( '_ListSelectedFields' )\n";
if ( $ref = $sth->func( '_ListSelectedFields' ) ){
    print "ok 33\n";
} else {
    die "not ok 33: $DBI::errstr\n";
}
print "Re-testing: \$sth->execute\n";
if ( $sth->execute ){
    print "ok 34\n";
} else {
    die "not ok 34: $DBI::errstr\n";
}
print "Re-testing: \$sth->fetchrow\n";
if ( @row = $sth->fetchrow ){
    print "ok 35\n";
} else {
    die "not ok 35: $DBI::errstr\n";
}
print "Re-testing: \$sth->finish\n";
if ( $sth->finish ){
    print "ok 36\n";
} else {
    die "not ok 36: $DBI::errstr\n";
}
# Temporary bug-plug
undef $sth;

### Insert some more data into the test table.........
print "Testing: \$dbh->do( 'INSERT INTO $test_table VALUES ( 2, 'Gary Shea' )' )\n";
if ( $dbh->do( "INSERT INTO $test_table VALUES( 2, 'Gary Shea' )" ) ){
    print "ok 37\n";
} else {
    die "not ok 37: $DBI::errstr\n";
}

print "Testing: \$sth = \$dbh->prepare( \"UPDATE $test_table SET id = 3 WHERE name = 'Gary Shea'\" )\n";
if ( $sth = $dbh->prepare( "UPDATE $test_table SET id = 3 WHERE name = 'Gary Shea'" ) ){
    print "ok 38\n";
} else {
    print( "not ok 38: $DBI::errstr\n" );
}
print "Testing: \$sth->func( '_ListSelectedFields' ). This will fail.\n";
if ( $ref = $sth->func( '_ListSelectedFields' ) ){
    die "not ok 39: $DBI::errstr\n";
} else {
    print "ok 39\n";
}
# Temporary bug-plug
undef $sth;

### Drop the test table out of our database to clean up.........
print "Re-testing: \$dbh->do( 'DROP TABLE $test_table' )\n";
if ( $dbh->do( "DROP TABLE $test_table" ) ){
    print "ok 40\n";
} else {
    die "not ok 40: $DBI::errstr\n";
}

$dbh->disconnect;

# Are we backwards compatible with the DBD::mSQL testscript connect
# method that was valid up to version 0.66 or so?

$DBD::mSQL::QUIET = $DBD::mSQL::QUIET = 1; # undocumented, will go away, transition variable
if ( $dbh = $drh->connect( $test_hostname, $test_dbname, '' ) ) {
    # We filled in the username. Bad thing.
    print "ok 41\n";
} else {
    print "not ok 41\n";
}

$dbh->disconnect;

