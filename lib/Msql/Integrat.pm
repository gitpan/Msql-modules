package Msql::Integrat;
use strict;
$VERSION = $VERSION = "0.90";

__END__

=head1 NAME

Msql::Integrat - Holds common code to MsqlPerl and DBD::mSQL

=head1 SYNOPSIS

use Msql::Integrat;
unshift @ISA, 'Msql::Integrat';

=head1 DESCRIPTION

Msql::Integrat stands for B<The MsqlPerl/DBD::mSQL Integration
Project>.

The Msql::Integrat module contains code that is shared by Msql and
DBD::mSQL. It is not intended to be used by the enduser directly. The
developer most probably finds code here that has been broken out of
either Msql.pm or DBD/mSQL.pm or their XS counterparts.

=head1 AUTHORS

Parts derived from DBD::mSQL are most probably originally written by
Alligator Descartes, parts from Msql are mostly by Andreas König.

=head1 HISTORY

The history of this project starts in fall 1995, when Tim Bunce asked
me (Andreas König) if I'd be willing to write the mSQL binding for the
DBI. By that time MsqlPerl was one year old, had its first 16 happy
users and approached stability.

I gave Tim an Okay, but after a while I realized that Schwartzian
transforms are nothing compared to Tim's code. Whereas Randal's
oneliners usually consist of one line perl, Tim populates dozens of
files, heaps of packages and stacks of stacks of macros and all that
in C! In other words, I didn't quite get on the track.

A few months later Alligator Descartes volunteered to do the job
instead. That was a great relief for me and I encouraged him to use
the slogan he had suggested: DBD::mSQL be the MsqlPerl killer.

It didn't work out. After two years maintaining the DBD::mSQL
Alligator still had not killed MsqlPerl. Instead MsqlPerl became much
more popular. What's up, we asked ourselves. I for one do not like the
overall waste of energy that results from two modules doing the same
thing. Moreover C<mysql> was born in about 1996, a clone of C<mSQL>,
and as it should be for a clone, the inventor of C<mysql> ported both
C<MsqlPerl> and C<DBD::mSQL> to C<mysql>. So we had 4 modules all
about the same thing. Rats.

Well, to cut a long story short: this project has been started in the
hope that we can unify the 4 into one. We'll see how well it works out
this time.

=cut
