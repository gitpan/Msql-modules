package DBD::mSQL;
use strict;
use vars qw(@ISA $VERSION $err $errstr $drh);

use DBI ();
use DynaLoader ();
use Carp ();
@ISA = qw(DynaLoader);

$VERSION = "0.80";

bootstrap DBD::mSQL $VERSION;

$err = 0;	# holds error code   for DBI::err
$errstr = "";	# holds error string for DBI::errstr
$drh = undef;	# holds driver handle once initialised

sub driver{
    return $drh if $drh;
    my($class, $attr) = @_;

    $class .= "::dr";

    # not a 'my' since we use it above to prevent multiple drivers
    $drh = DBI::_new_drh($class, {
				  'Name' => 'mSQL',
				  'Version' => $VERSION,
				  'Err'    => \$DBD::mSQL::err,
				  'Errstr' => \$DBD::mSQL::errstr,
				  'Attribution' => 'DBD::mSQL by AK',
				 });

    $drh;
}

1;

package DBD::mSQL::dr; # ====== DRIVER ======
use strict;

sub errstr {
    DBD::mSQL::errstr(@_);
}

sub connect {
    my($drh, $data_source, $username, $password )= @_;

    if (defined $username) { # backwards compatible until October 1997 or so
	$data_source = "$username:$data_source";
	Carp::carp qq{
Please switch to the new connect method documenteded in DBI 0.84:
  \$dbh = DBI->connect(\$data_source).
We now emulate the call
  \$drh->connect("$data_source"),
but this exception will go away soon.
} unless defined $DBD::mSQL::QUIET && $DBD::mSQL::QUIET;
    }
    my($dbname,$host,$port) = split /:/, $data_source;

    $ENV{'MSQL_TCP_PORT'} = $port if defined $port;

    my $this = DBI::_new_dbh($drh, {
				    'Host' => $host,
				    'Name' => $dbname
				   });

    # Call mSQL msqlConnect func in mSQL.xs file
    # and populate internal handle data.
    $this->DBD::mSQL::db::_login($host, $dbname)
	or return undef;

    $this;
}

package DBD::mSQL::db; # ====== DATABASE ======
use strict;

### mSQL datatype to ANSI datatype mapping
%DBD::mSQL::db::db2ANSI = (
			   "INT"   =>  "INTEGER",
			   "CHAR"  =>  "CHAR",
			   "REAL"  =>  "REAL",
			   "IDENT" =>  "DECIMAL"
			  );

### ANSI datatype mapping to mSQL datatypes
%DBD::mSQL::db::ANSI2db = (
			   "CHAR"        => "CHAR",
			   "VARCHAR"     => "CHAR",
			   "LONGVARCHAR" => "CHAR",
			   "NUMERIC"     => "INTEGER",
			   "DECIMAL"     => "INTEGER",
			   "BIT"         => "INTEGER",
			   "TINYINT"     => "INTEGER",
			   "SMALLINT"    => "INTEGER",
			   "INTEGER"     => "INTEGER",
			   "BIGINT"      => "INTEGER",
			   "REAL"        => "REAL",
			   "FLOAT"       => "REAL",
			   "DOUBLE"      => "REAL",
			   "BINARY"      => "CHAR",
			   "VARBINARY"   => "CHAR",
			   "LONGVARBINARY" => "CHAR",
			   "DATE"        => "CHAR",
			   "TIME"        => "CHAR",
			   "TIMESTAMP"   => "CHAR"
			  );



sub errstr {
    DBD::mSQL::errstr(@_);
}

sub prepare {
    my($dbh, $statement)= @_;

    # create a 'blank' dbh

    my $sth = DBI::_new_sth($dbh, {
				   'Statement' => $statement,
				  });

    # Call mSQL OCI oparse func in mSQL.xs file.
    # (This will actually also call oopen for you.)
    # and populate internal handle data.

    DBD::mSQL::st::_prepare($sth, $statement)
	or return undef;

    $sth;
}

sub quote {
    my $self = shift;
    my $str = shift;
    $str =~ s/'/\\'/g;      # MSQL non-ISO compliant!
    "'$str'";
}

sub db2ANSI {
    my $self = shift;
    my $type = shift;
    return $DBD::mSQL::db::db2ANSI{"$type"};
}

sub ANSI2db {
    my $self = shift;
    my $type = shift;
    return $DBD::mSQL::db::ANSI2db{"$type"};
}


package DBD::mSQL::st; # ====== STATEMENT ======
use strict;

sub errstr {
    DBD::mSQL::errstr(@_);
}


1;

__END__

=head1 NAME

DBD::mSQL - mSQL-1.I<x> / 2.I<x> driver for the Perl5 Database Interface (DBI)

=head1 SYNOPSIS

    $dbh = DBI->connect( "$database:$hostname:$port" );

    @databases = $drh->func( $hostname, '_ListDBs' );
    @tables = $dbh->func( '_ListTables' );
    $ref = $dbh->func( $table, '_ListFields' );
    $ref = $sth->func( '_ListSelectedFields' );

    $numRows = $sth->func( '_NumRows' );

    $rc = $drh->func( $database, '_CreateDB' );
    $rc = $drh->func( $database, '_DropDB' );

=head1 DESCRIPTION

B<DBD::mSQL> is the Perl5 Database Interface driver for mSQL 1.I<x> and
2.I<x> databases.

=head2 Compatibility Alert

As of version 0.70 DBD::mSQL has a new maintainer


=head2 DBD::mSQL Class Methods

=over 4

=item B<connect>

    $dbh = DBI->connect( "$database" );
    $dbh = DBI->connect( "$database:$hostname" );
    $dbh = DBI->connect( "$database:$hostname:$port" );

A C<database> must always be specified.

The hostname, if not specified or specified as '', will default to an
mSQL daemon running on the local machine on the default port for the
UNIX socket.

Should the mSQL daemon be running on a non-standard port number, you
may explicitly state the port number to connect to in the C<hostname>
argument, by concatenating the I<hostname> and I<port number> together
separated by a colon ( C<:> ) character.

=back

=head2 DBD::mSQL Private MetaData Methods

=over 4

=item B<ListDBs>

    @databases = $drh->func( $hostname, '_ListDBs' );

This private method returns an array containing the names of all
databases present on the mSQL daemon running on C<hostname>. If there
are no databases, an empty list will be returned. A sample usage of
this method is:

    @databases = $drh->func( 'localhost', '_ListDBs' );
    foreach $db ( @databases ) {
        print "Database: $db\n";
      }

=item B<ListTables>

    @tables = $dbh->func( '_ListTables' );

Once connected to the desired database on the desired mSQL daemon with
the C<DBI->connect()> method, we may extract a list of the tables that
have been created within that database.

C<ListTables> returns an array containing the names of all the tables
present within the selected database. If no tables have been created,
an empty list is returned.

    @tables = $dbh->func( '_ListTables' );
    foreach $table ( @tables ) {
        print "Table: $table\n";
      }

=item B<ListFields>

    $ref = $dbh->func( $table, '_ListFields' );

C<ListFields> returns a reference to a hashtable containing metadata
information on the fields within the given table. If the table
specified in C<table> does not exist, C<undef> will be returned and an
error flagged.

The valid keys within the hashtable that may be referenced are:

    NAME           The name of the field
    TYPE           The datatype of the field: CHAR, REAL, INTEGER, NULL
    IS_NOT_NULL    Indicates whether the field is NULLable or not
    IS_PRI_KEY     Indicates whether the field is a Primary Key ( this is
                     only valid in mSQL 1.x databases. mSQL 2.x uses indices )
    LENGTH         The size of the field
    NUMFIELDS      The number of fields within the table

Since a reference is returned, it requires slightly more work to
extract the pertinent information from it. Here's an example of how to
do it:

    $ref = $dbh->func( 'someTable', '_ListFields' );
    @fieldNames = @{ $ref->{NAME} };
    @fieldTypes = @{ $ref->{TYPE} };
    @fieldNulls = @{ $ref->{IS_NOT_NULL} };
    @fieldKeys  = @{ $ref->{IS_PRI_KEY} };
    @fieldLength = @{ $ref->{LENGTH} };
    for ( $i = 0 ; $i < $ref->{NUMFIELDS} ; $i++ ) {
        print "Field: $fieldNames[$i]\n";
        print "\tType: $fieldTypes[$i]\n";
        print "\tNullable: $fieldNulls[$i]\n";
        print "\tKey?: $fieldKeys[$i]\n";
        print "\tLength: $fieldLength[$i]\n";
      }

=item B<ListSelectedFields>

    $ref = $sth->func( '_ListSelectedFields' );

C<ListSelectedFields> is a similar function to C<ListFields>, except,
where C<ListFields> lists the fields for a given table within the
current database, C<ListSelectedFields> lists the field information
for the fields present in a B<SELECT> statement handle. This is
primarily used for extracting meta-data about the current C<sth>.

The usage of C<ListSelectedFields> is identical to C<ListFields>.

=item C<NumRows>

    $numRows = $sth->func( '_NumRows' );

The C<NumRows> private method returns the number of rows affected by a
B<SELECT> statement. This functionality was introduced prior to it
becoming a standard within the DBI interface itself, where the number
of rows affected by a B<SELECT> may be obtained by checking the return
value of the C<$sth->execute> method.

=back

=head2 DBD::mSQL Database Manipulation

=over 4

=item B<CreateDB>

    $rc = $drh->func( $database, '_CreateDB' );
    $rc = $drh->func( $database, '_DropDB' );

These two methods allow programmers to create and drop databases from
DBI scripts. Since mSQL disallows the creation and deletion of
databases over the network, these methods explicitly connect to the
mSQL daemon running on the machine C<localhost> and execute these
operations there.

It should be noted that database deletion is I<not prompted for> in
any way.  Nor is it undo-able from DBI.

    Once you issue the dropDB() method, the database will be gone!

These methods should be used at your own risk.

=back

=head1 BUGS

The I<port> part of the first argument to the connect call is
implemented in an unsafe way. It in fact it never did more than set
the environment variable MSQL_TCP_PORT during the connect call. If
another connect call uses another port and the handles are used
simultaneously, they will interfere. In a future version this
behaviour will change.

The I<host> part of the first argument to the connect call is
currently documented as defaulting to 'localhost'. If I read this
right, it implicates that there are no provisions to connect to the
UNIX socket. This is a major speed disadvantage for application that
run on the server host. This will have to be revisited in the next
release.

The func method call on a driver handle seems to be undocumented in
the DBI manpage. DBD::mSQL has func methods on driverhandles, database
handles, and statement handles. What gives?

Despite all these func methods, AFAIK it is currently not possible to
connect to a different host and query the available databases. If
true, this is a minor nit, but needs to be resolved somehow.

I haven't yet found out how the constants CHAR_TYPE, INT_TYPE,
etc. are accessed in DBD::mSQL. Can anybody help me on the tracks
here?

Please speak up now (June 1997) if you encounter additional bugs. I'm
still learning about the DBI API and can neither judge the quality of
the code presented here nor the DBI compliancy. But I'm intending to
resolve things quickly as I'd really like to get rid of the multitude
of implementations ASAP.

=head1 AUTHOR

B<DBD::mSQL> has been primarily written by Alligator Descartes
<I<descarte@hermetica.com>>, who has been aided and abetted by Gary
Shea, Andreas Koenig and Tim Bunce amongst others. Apologies if your
name isn't listed, it probably is in the file called
'Acknowledgments'. As of version 0.80 the maintainer is Andreas König.

=head1 COPYRIGHT

This module is Copyright (c)1994-1997 Alligator Descartes, with code
portions Copyright (c)1994-1997 their original authors. This module is
released under the 'Artistic' license which you can find in the perl
distribution.

This document is Copyright (c)1997 Alligator Descartes. All rights
reserved.  Permission to distribute this document, in full or in part,
via email, Usenet, ftp archives or http is granted providing that no
charges are involved, reasonable attempt is made to use the most
current version and all credits and copyright notices are retained (
the I<AUTHOR> and I<COPYRIGHT> sections ).  Requests for other
distribution rights, including incorporation into commercial products,
such as books, magazine articles or CD-ROMs should be made to
Alligator Descartes <I<descarte@hermetica.com>>.

=head1 Additional DBI Information

Additional information on the DBI project can be found on the World
Wide Web at the following URL:

    http://www.hermetica.com/technologia/perl/DBI

where documentation, pointers to the mailing lists and mailing list
archives and pointers to the most current versions of the modules can
be used.

Information on the DBI interface itself can be gained by typing:

    perldoc DBI

right now!

=cut
