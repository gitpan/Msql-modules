/**
 * $Id: mSQL.xs,v 1.1 1997/07/09 18:59:55 k Exp $
 *
 * (c)1994-1997 Alligator Descartes, based in part on work by Tim Bunce
 *
 * You may distribute under the terms of either the GNU General Public
 * License or the Artistic License, as specified in the Perl README file.
 *
 */

#include "mSQL.h"


DBISTATE_DECLARE;

/* see dbd_init for initialisation */
SV *dbd_errnum = NULL;
SV *dbd_errstr = NULL;


MODULE = DBD::mSQL	PACKAGE = DBD::mSQL

REQUIRE:	1.929
PROTOTYPES:	DISABLE

BOOT:
    items = 0;	/* avoid 'unused variable' warning */
    DBISTATE_INIT;
    /* XXX tis interface will change: */
    DBI_IMP_SIZE("DBD::mSQL::dr::imp_data_size", sizeof(imp_drh_t));
    DBI_IMP_SIZE("DBD::mSQL::db::imp_data_size", sizeof(imp_dbh_t));
    DBI_IMP_SIZE("DBD::mSQL::st::imp_data_size", sizeof(imp_sth_t));
    dbd_init(DBIS);

void
errstr(h)
    SV *	h
    CODE:
    /* called from DBI::var TIESCALAR code for $DBI::errstr     */
    D_imp_xxh(h);
    ST(0) = sv_mortalcopy(DBIc_ERRSTR(imp_xxh));


MODULE = DBD::mSQL	PACKAGE = DBD::mSQL::dr

void
disconnect_all(drh)
    SV *        drh
    CODE:
    if (!dirty && !SvTRUE(perl_get_sv("DBI::PERL_ENDING",0))) {
        D_imp_drh(drh);
        sv_setiv(DBIc_ERR(imp_drh), (IV)1);
        sv_setpv(DBIc_ERRSTR(imp_drh),
                (char*)"disconnect_all not implemented");
        DBIh_EVENT2(drh, ERROR_event,
                DBIc_ERR(imp_drh), DBIc_ERRSTR(imp_drh));
        XSRETURN(0);
    }
    /* perl_destruct with perl_destruct_level and $SIG{__WARN__} set    */
    /* to a code ref core dumps when sv_2cv triggers warn loop.         */
    if (perl_destruct_level)
        perl_destruct_level = 0;
    XST_mIV(0, 1);


void
_ListDBs(drh, host)
    SV *        drh
    char *	host
    PPCODE:
    m_result *res;
    m_row cur;
    int sock;
    sock = msqlConnect( host );
    if ( sock != -1 ) {
        res = msqlListDBs( sock );
        if ( !res ) {
            do_mSQL_error( (sb2)-1, msqlErrMsg );
          } else {
            while ( ( cur = msqlFetchRow( res ) ) ) {
                EXTEND( sp, 1);
                PUSHs( sv_2mortal((SV*)newSVpv( cur[0], strlen(cur[0]))));
              }
            msqlFreeResult( res );
          }
        msqlClose( sock );
      }


void
_CreateDB(drh, host, dbname)
    SV *        drh
    char *      host
    char *      dbname
    PPCODE:
    int sock;
    sock = msqlConnect( host );
    if ( sock != -1 ) {
        if ( msqlCreateDB(sock,dbname) != -1 ) {
            EXTEND( sp, 1 );
            PUSHs( sv_2mortal((SV*)newSVpv( "OK", 2 )));
          } else {
            do_mSQL_error( -1, msqlErrMsg );
          }
      } else {
        do_mSQL_error( -1, msqlErrMsg );
      }


void
_DropDB(drh, host, dbname)
    SV *        drh
    char *      host
    char *      dbname
    PPCODE:
    int sock;
    sock = msqlConnect( host );
    if ( sock != -1 ) {
        if ( msqlDropDB(sock,dbname) != -1 ) {
            EXTEND( sp, 1 );
            PUSHs( sv_2mortal((SV*)newSVpv( "OK", 2 )));
          } else {
            do_mSQL_error( -1, msqlErrMsg );
          }
      } else {
        do_mSQL_error( -1, msqlErrMsg );
      }


MODULE = DBD::mSQL    PACKAGE = DBD::mSQL::db

void
_ListDBs(dbh)
    SV *	dbh
    PPCODE:
    D_imp_dbh(dbh);
    m_result *res;
    m_row cur;
    int sock = imp_dbh->lda.svsock;
    if ( sock != -1 ) {
        res = msqlListDBs( sock );
        if ( !res ) {
            do_mSQL_error( (sb2)-1, msqlErrMsg );
          } else {
            while ( ( cur = msqlFetchRow( res ) ) ) {
                EXTEND( sp, 1);
                PUSHs( sv_2mortal((SV*)newSVpv( cur[0], strlen(cur[0]))));
              }
            msqlFreeResult( res );
          }
      }

void
_SelectDB(dbh, dbname)
    SV *	dbh
    char *	dbname
    PPCODE:
    D_imp_dbh(dbh);
    if ( imp_dbh->lda.svsock != -1 ) {
        if ( msqlSelectDB( imp_dbh->lda.svsock, dbname ) == -1 ) {
            do_mSQL_error( (sb2)( imp_dbh->lda.rc ), msqlErrMsg );
          }
      }


void
_ListTables(dbh)
    SV *	dbh
    PPCODE:
    D_imp_dbh(dbh);
    m_result *res;
    m_row cur;
    res = msqlListTables( imp_dbh->lda.svsock );
    if ( !res ) {
        do_mSQL_error( -1, "Error in msqlListTables!" );
      } else {
        while ( ( cur = msqlFetchRow( res ) ) ) {
            EXTEND( sp, 1 );
            PUSHs( sv_2mortal((SV*)newSVpv( cur[0], strlen( cur[0] )))); 
          }
        msqlFreeResult( res );
      }
 

void
_ListFields(dbh, tabname)
    SV * 	dbh
    char *	tabname
    PPCODE:
    D_imp_dbh(dbh);
    m_result *res;
    if ( strlen( tabname ) == 0 ) {
        do_mSQL_error( -1, "Error in msqlListFields! Table name was NULL!\n" );
        return;
      }
    res = msqlListFields( imp_dbh->lda.svsock, tabname );
    if ( !res ) {
        do_mSQL_error( -1, "Error in msqlListFields!" );
      } else {
        SV * rv;
        rv = dbd_db_fieldlist( res );
        if ( !rv ) {
	        do_mSQL_error( -1, "fieldlist() error in msqlListFields!" );
          } else {
            XPUSHs( (SV*)rv );
            msqlFreeResult( res );
          }
      }


SV *
_login(dbh, host, dbname, junk = "")
    SV *	dbh
    char *	host
    char *	dbname
    char *	junk
    CODE:
    ST(0) = dbd_db_login(dbh, host, dbname, junk) ? &sv_yes : &sv_no;


void
commit(dbh)
    SV *        dbh
    CODE:
    ST(0) = dbd_db_commit(dbh) ? &sv_yes : &sv_no;

void
rollback(dbh)
    SV *        dbh
    CODE:
    ST(0) = dbd_db_rollback(dbh) ? &sv_yes : &sv_no;

void
STORE(dbh, keysv, valuesv)
    SV *        dbh
    SV *        keysv
    SV *        valuesv
    CODE:
    if (!dbd_db_STORE(dbh, keysv, valuesv))
        if (!DBIS->set_attr(dbh, keysv, valuesv))
            ST(0) = &sv_no;


void
FETCH(dbh, keysv)
    SV *        dbh
    SV *        keysv
    CODE:
    SV *valuesv = dbd_db_FETCH(dbh, keysv);
    if (!valuesv)
        valuesv = DBIS->get_attr(dbh, keysv);
    ST(0) = valuesv;    /* dbd_db_FETCH did sv_2mortal  */


void
disconnect(dbh)
    SV *        dbh
    CODE:
    D_imp_dbh(dbh);
    if ( !DBIc_ACTIVE(imp_dbh) ) {
        XSRETURN_YES;
    }
    /* Check for disconnect() being called whilst refs to cursors       */
    /* still exists. This needs some more thought.                      */
    if (DBIc_ACTIVE_KIDS(imp_dbh) && DBIc_WARN(imp_dbh) && !dirty) {
        warn("disconnect(%s) invalidates %d active cursor(s)",
            SvPV(dbh,na), (int)DBIc_ACTIVE_KIDS(imp_dbh));
    }
    ST(0) = dbd_db_disconnect(dbh) ? &sv_yes : &sv_no;


void
DESTROY(dbh)
    SV *        dbh
    CODE:
    D_imp_dbh(dbh);
    ST(0) = &sv_yes;
    if (!DBIc_IMPSET(imp_dbh)) {        /* was never fully set up       */
        if (DBIc_WARN(imp_dbh) && !dirty && dbis->debug >= 2)
             warn("Database handle %s DESTROY ignored - never set up",
                SvPV(dbh,na));
    }
    else {
        if (DBIc_ACTIVE(imp_dbh)) {
            if (DBIc_WARN(imp_dbh) && !dirty)
                 warn("Database handle destroyed without explicit disconnect");
            dbd_db_disconnect(dbh);
        }
        dbd_db_destroy(dbh);
    }


MODULE = DBD::mSQL    PACKAGE = DBD::mSQL::st

void
_NumRows(sth)
    SV *	sth
    PPCODE:
    D_imp_sth(sth);
    EXTEND( sp, 1 );
    PUSHs( sv_2mortal((SV*)newSViv(imp_sth->row_num)));


void
_ListSelectedFields(sth)
    SV *	sth
    PPCODE:
    D_imp_sth(sth);
    m_result *res;
    SV * rv;
    /**
     *  Set up an empty reference in case of error...
     *  I really have no idea how to do this.
     */
    if ( !imp_sth->is_select ) {
	    do_mSQL_error( -1, "not a SELECT in msqlListSelectedFields!" );
      } else {
        if ( !( res = imp_sth->cda ) ) {
            do_mSQL_error( -1, "missing m_result in msqlListSelectedFields!" );
          } else {
            if ( !( rv = dbd_db_fieldlist( res ) ) ) {
	            do_mSQL_error( -1, "fieldlist() error in msqlListSelectedFields!" );
              } else {
	            XPUSHs((SV*)rv);
	          }
	      }
	  }


void
_prepare(sth, statement, attribs=Nullsv)
    SV *        sth
    char *      statement
    SV *	attribs
    CODE:
    DBD_ATTRIBS_CHECK("_prepare", sth, attribs);
    ST(0) = dbd_st_prepare(sth, statement, attribs) ? &sv_yes : &sv_no;


void
rows(sth)
    SV *        sth
    CODE:
    XST_mIV(0, dbd_st_rows(sth));


void
bind_param( sth, param, value, attribs=Nullsv)
    SV *	sth
    SV *	param
    SV *	value
    SV *	attribs
    CODE:
    ST(0) = &sv_undef;


void
bind_param_inout(sth, param, value_ref, maxlen, attribs=Nullsv)
    SV *        sth
    SV *        param
    SV *        value_ref
    IV          maxlen
    SV *        attribs
    CODE:
    ST(0) = &sv_undef;


void
execute(sth, ...)
    SV *        sth
    CODE:
    D_imp_sth(sth);
    int retval;
    /* describe and allocate storage for results */
    retval = dbd_st_execute(sth, imp_sth);
    if ( retval < -1 ) {
        XST_mUNDEF( 0 );
      } else { 
        if ( retval == 0 ) {
            XST_mPV( 0, "0E0" );
          } else {
            XST_mIV( 0, retval );
          }
      }


void
fetchrow(sth)
    SV *	sth
    PPCODE:
    D_imp_sth(sth);
    int i;
    SV *sv;
/*    imp_sth->done_desc = 0; */
    if ( dbis->debug >= 2 ) {
        printf( "In: DBD::mSQL::fetchrow\n" );
        printf( "In: DBD::mSQL::fetchrow'imp_sth->currow: %d\n", 
                imp_sth->currow );
        printf( "In: DBD::mSQL::fetchrow'imp_sth->row_num: %d\n", 
                imp_sth->row_num );
      }
    dbd_describe( sth, imp_sth );
    /* Check that execute() was executed sucessfuly. This also implies	*/
    /* that dbd_describe() executed sucessfuly so the memory buffers	*/
    /* are allocated and bound.						*/
#    pif ( !(imp_sth->flags & IMP_STH_EXECUTING) ) {
#	do_mSQL_error( 1, "no statement executing");
#	XSRETURN(0);
#      }
    /* Advance through the buffer until we get to the row we want */

    if ( dbis->debug >= 2 ) {
        warn( "Number of fields: %d\n", imp_sth->fbh_num );
        warn( "Current ROWID: %d\n", imp_sth->currow );
      }

    EXTEND(sp,imp_sth->fbh_num);
    for ( i = 0 ; i < imp_sth->fbh_num ; i++ ) {
        imp_fbh_t *fbh = &imp_sth->fbh[i];
        if ( dbis->debug >=2 ) {
            printf( "In: DBD::mSQL::execute'FieldBufferDump: %d\n", i );
            printf( "In: DBD::mSQL::execute'FieldBufferDump->cbuf: %s\n", 
                    fbh->cbuf );
            printf( "In: DBD::mSQL::execute'FieldBufferDump->rlen: %i\n", 
                    fbh->rlen );
          }
        SvCUR( fbh->sv ) = fbh->rlen;
        if ( fbh->indp ) {   /** Assume NULL */
            sv = &sv_undef;
          } else {
            sv = sv_2mortal( newSVpv( (char *)fbh->cbuf, fbh->rlen ) );
          }
        PUSHs(sv);
      }
    imp_sth->currow++;
 

void
blob_read(sth, field, offset, len, destrv=Nullsv, destoffset=0)
    SV *        sth
    int field
    long        offset
    long        len
    SV *        destrv
    long	destoffset
    CODE:
    ST(0) = &sv_undef;


void
STORE(sth, keysv, valuesv)
    SV *        sth
    SV *        keysv
    SV *        valuesv
    CODE:
    ST(0) = &sv_yes;
    if (!dbd_st_STORE(sth, keysv, valuesv))
        if (!DBIS->set_attr(sth, keysv, valuesv))
            ST(0) = &sv_no;


void
FETCH(sth, keysv)
    SV *        sth
    SV *        keysv
    CODE:
    SV *valuesv = dbd_st_FETCH(sth, keysv);
    if (!valuesv)
        valuesv = DBIS->get_attr(sth, keysv);
    ST(0) = valuesv;    /* dbd_st_FETCH did sv_2mortal  */

void
finish(sth)
    SV *        sth
    CODE:
    D_imp_sth(sth);
    D_imp_dbh_from_sth;
    if (!DBIc_ACTIVE(imp_dbh)) {
        /* Either an explicit disconnect() or global destruction        */
        /* has disconnected us from the database. Finish is meaningless */
        /* XXX warn */
        XSRETURN_YES;
    }
    if (!DBIc_ACTIVE(imp_sth)) {
        /* No active statement to finish        */
        XSRETURN_YES;
    }
    ST(0) = dbd_st_finish(sth) ? &sv_yes : &sv_no;


void
DESTROY(sth)
    SV *        sth
    CODE:
    D_imp_sth(sth);
    ST(0) = &sv_yes;
    if (!DBIc_IMPSET(imp_sth)) {        /* was never fully set up       */
        if (DBIc_WARN(imp_sth) && !dirty)
             warn("Statement handle %s DESTROY ignored - never set up",
                SvPV(sth,na));
        return;
    }
    if (DBIc_ACTIVE(imp_sth)) {
        dbd_st_finish(sth);
    }
    dbd_st_destroy(sth);

# end of mSQL.xs
