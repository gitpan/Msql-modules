/**
 * $Id: dbdimp.c,v 1.1 1997/07/09 18:59:55 k Exp $
 * 
 * (c)1994-1997 Alligator Descartes, based on work by Tim Bunce
 *
 * You may distribute under the terms of either the GNU General Public
 * License or the Artistic License, as specified in the Perl README file.
 *
 */

#include "mSQL.h"

DBISTATE_DECLARE;

void
dbd_init(dbistate)
    dbistate_t *dbistate;
{
    DBIS = dbistate;
    dbd_errnum = GvSV(gv_fetchpv("DBD::mSQL::err",    1, SVt_IV));
    dbd_errstr = GvSV(gv_fetchpv("DBD::mSQL::errstr", 1, SVt_PV));
}

void do_mSQL_error( sb2 rc, char *what ) {
    sv_setiv(dbd_errnum, (IV)rc);
    sv_setpv(dbd_errstr, (char*)what);
}

void
fbh_dump(fbh, i)
    imp_fbh_t *fbh;
    int i;
{
    FILE *fp = DBILOGFP;
    fprintf(fp, "fbh %d: '%s' %s, ",
        i, fbh->cbuf, (fbh->nullok) ? "NULLable" : "");
    fprintf(fp, "type %d,  dbsize %ld, dsize %ld, p%d s%d\n",
        fbh->dbtype, (long)fbh->dbsize, (long)fbh->dsize, fbh->prec, fbh->scale);
    fprintf(fp, "   out: ftype %d, indp %d, bufl %d, rlen %d, rcode %d\n",
        fbh->ftype, fbh->indp, fbh->bufl, fbh->rlen, fbh->rcode);
}


/* ================================================================== */

int
dbd_db_login( dbh, host, dbname, junk )
    SV *dbh;
    char *host;
    char *dbname;
    char *junk;
{
    D_imp_dbh(dbh);

/*    printf( "%s:%d: dbd_db_login: %s, %s\n", 
            __FILE__, __LINE__, 
            host, dbname ); */

    if (host && !*host) host = 0;    /* Patch by Sven Verdoolaege */
    imp_dbh->lda.svsock = msqlConnect( host ); 

    if ( imp_dbh->lda.svsock == -1 ) {
        do_mSQL_error( (sb2)( imp_dbh->lda.rc ), msqlErrMsg );
        return 0;
      } 

    if ( strlen( dbname ) != 0 ) {
        if ( msqlSelectDB( imp_dbh->lda.svsock, dbname ) == -1 ) {
            do_mSQL_error( (sb2)(imp_dbh->lda.rc ), msqlErrMsg );
            return 0;
          } 
      }
    /** Dump the information we have into the Lda_Def */
    imp_dbh->lda.svdb = dbname;
    imp_dbh->lda.svhost = host;

    /** Return after setting various doo-dads */
    DBIc_IMPSET_on(imp_dbh);    /* imp_dbh set up now                   */
    DBIc_ACTIVE_on(imp_dbh);    /* call disconnect before freeing       */
    return 1;
  }

/* Commit and Rollback don't exist in mSQL but we'll stub them anyway... */

int
dbd_db_commit(dbh)
    SV *dbh;
{
    D_imp_dbh(dbh);
    return 1;
}

int
dbd_db_rollback(dbh)
    SV *dbh;
{
    D_imp_dbh(dbh);
    return 1;
}

int
dbd_db_disconnect(dbh)
    SV *dbh;
{
    D_imp_dbh(dbh);
    /* We assume that disconnect will always work       */
    /* since most errors imply already disconnected.    */
    DBIc_ACTIVE_off(imp_dbh);
    if ( dbis->debug >= 2 )
        printf( "imp_dbh->sock: %i\n", imp_dbh->lda.svsock );

    msqlClose( imp_dbh->lda.svsock );

    /* We don't free imp_dbh since a reference still exists    */
    /* The DESTROY method is the only one to 'free' memory.    */
    return 1;
}

void
dbd_db_destroy(dbh)
    SV *dbh;
{
    D_imp_dbh(dbh);
    if (DBIc_ACTIVE(imp_dbh))
        dbd_db_disconnect(dbh);
    /* XXX free contents of imp_dbh */
    DBIc_IMPSET_off(imp_dbh);
}

int
dbd_db_STORE(dbh, keysv, valuesv)
    SV *dbh;
    SV *keysv;
    SV *valuesv;
{
    D_imp_dbh(dbh);
    STRLEN kl;
    char *key = SvPV(keysv,kl);
    SV *cachesv = NULL;

    if (kl==10 && strEQ(key, "AutoCommit")){
        /* Ignore SvTRUE warning: '=' where '==' may have been intended. */
/*        if ( (on) ? ocon(&imp_dbh->lda) : ocof(&imp_dbh->lda) ) {
            ora_error(dbh, &imp_dbh->lda, imp_dbh->lda.rc, "ocon/ocof failed");
        } else {
            cachesv = (on) ? &sv_yes : &sv_no;
        } */
    } else {
        return FALSE;
    }
    if (cachesv) /* cache value for later DBI 'quick' fetch? */
        hv_store((HV*)SvRV(dbh), key, kl, cachesv, 0);
    return TRUE;
}

SV *
dbd_db_FETCH(dbh, keysv)
    SV *dbh;
    SV *keysv;
{
    D_imp_dbh(dbh);
    return sv_2mortal(NULL);
}

SV *
dbd_db_fieldlist(res)
    m_result *    res;
{
    m_field *curField;
    HV * hv;
    SV * rv;
    AV * avkey;
    AV * avnam;
    AV * avnnl;
    AV * avtab;
    AV * avtyp;
    AV * avlength;
    hv = (HV*)sv_2mortal((SV*)newHV());
    hv_store(hv,"NUMROWS",7,(SV *)newSViv((IV)msqlNumRows(res)),0);
    hv_store(hv,"NUMFIELDS",9,(SV *)newSViv((IV)msqlNumFields(res)),0);
    msqlFieldSeek(res,0);
    avkey = (AV*)sv_2mortal((SV*)newAV());
    avnam = (AV*)sv_2mortal((SV*)newAV());
    avnnl = (AV*)sv_2mortal((SV*)newAV());
    avtab = (AV*)sv_2mortal((SV*)newAV());
    avtyp = (AV*)sv_2mortal((SV*)newAV());
    avlength = (AV*)sv_2mortal((SV*)newAV());
    while ( ( curField = msqlFetchField( res ) ) ) {
        av_push(avnam,(SV*)newSVpv(curField->name,strlen(curField->name)));
        av_push(avtab,(SV*)newSVpv(curField->table,strlen(curField->table)));
        av_push(avtyp,(SV*)newSViv(curField->type));
#ifdef MSQL1
        av_push(avkey,(SV*)newSViv(IS_PRI_KEY(curField->flags)));
#else
        av_push(avkey,(SV*)newSVpv("Deprecated", strlen( "Deprecated" ) ) );
#endif
        av_push(avnnl,(SV*)newSViv(IS_NOT_NULL(curField->flags)));
        av_push(avlength,(SV*)newSViv(curField->length));
      }
    rv = newRV((SV*)avnam); hv_store(hv,"NAME",4,rv,0);
    rv = newRV((SV*)avtab); hv_store(hv,"TABLE",5,rv,0);
    rv = newRV((SV*)avtyp); hv_store(hv,"TYPE",4,rv,0);
    rv = newRV((SV*)avkey); hv_store(hv,"IS_PRI_KEY",10,rv,0);
    rv = newRV((SV*)avnnl); hv_store(hv,"IS_NOT_NULL",11,rv,0);
    rv = newRV((SV*)avlength); hv_store(hv,"LENGTH",6,rv,0);
    hv_store(hv,"RESULT",6,(SV *)newSViv((IV)res),0);
    rv = newRV((SV*)hv);
    return rv;
}


/* ================================================================== */

int
dbd_st_prepare(sth, statement, attribs)
    SV *sth;
    char *statement;
    SV *attribs;
{
    D_imp_sth(sth);
    D_imp_dbh_from_sth;

    int i;
    char func[64];

    imp_sth->done_desc = 0;
    imp_sth->cda = &imp_sth->cdabuf;

    /* Parse statement for binds ( also, INSERTS! ) */
    /* Lowercase the statement first */

/*    for ( i = 0 ; i < strlen( statement ) ; i++ ) {
        if ( ( statement[i] == '\'' ) || ( statement[i] == '"' ) )
            if ( inside_quote == 1 ) 
                inside_quote = 0;
            else
                inside_quote = 1;
        if ( isupper( statement[i] ) && ( inside_quote != 1 ) ) 
            statement[i] = tolower( statement[i] );
      }
*/

    sscanf( statement, "%s", func );
    for ( i = 0 ; i < strlen( func ) ; i++ )
        if ( isupper( func[i] ) )
            func[i] = tolower( func[i] );

    if ( strstr( func, "insert" ) != 0 ) {
        if ( dbis->debug >= 2 )
            warn( "INSERT present in statement\n" );
        imp_sth->is_insert = 1;
      }

    if ( strstr( func, "create" ) != 0 ) {
        if ( dbis->debug >= 2 )
            warn( "CREATE present in statement\n" );
        imp_sth->is_create = 1;
      }

    if ( strstr( func, "update" ) != 0 ) {
        if ( dbis->debug >= 2 )
            warn( "UPDATE present in statement\n" );
        imp_sth->is_update = 1;
      }

    if ( strstr( func, "drop" ) != 0 ) {
        if ( dbis->debug >= 2 )
            warn( "DROP present in statement\n" );
        imp_sth->is_drop = 1;
      }

    if ( strstr( func, "delete" ) != 0 ) {
        if ( dbis->debug >= 2 )
            warn( "DELETE present in statement\n" );
        imp_sth->is_delete = 1;
      }

    if ( strstr( func, "select" ) != 0 ) {
        if ( dbis->debug >= 2 )
            warn( "SELECT present in statement\n" );
        imp_sth->is_select = 1;
      }

    if ( strstr( func, "systables" ) != 0 ) {
        if ( dbis->debug >= 2 )
            warn( "dumping tables\n" );
        imp_sth->is_delete = 1;
      }

    /** Copy the statement into the current imp_sth */
    imp_sth->statement = (char *)malloc( strlen( statement ) + 1 );
    memcpy( imp_sth->statement, statement, strlen( statement ) );
    imp_sth->statement[strlen( statement )] = '\0';

    DBIc_IMPSET_on(imp_sth);
    return 1;
}

int
dbd_st_execute( h, imp_sth )
    SV *h;
    imp_sth_t *imp_sth;
{
    D_imp_dbh_from_sth;

    /** 
     * Check to see if we've already described this statement. If we have,
     * then return immediately. Otherwise, set the flag to stop us re-exec'ing
     * this statement.
     */
/*    fprintf( stderr, "imp_sth->done_execute: %d\n", imp_sth->done_execute ); */
    if ( imp_sth->done_execute == 1 ) {
        return 0;
      }
    imp_sth->done_execute = 1;
/*    imp_sth->done_desc = 0; */

    /** Issue the statement */
/*    fprintf( stderr, "Issuing statement: %s\n", imp_sth->statement ); */
    if ( msqlQuery( imp_dbh->lda.svsock, imp_sth->statement ) == -1 ) { 
        do_mSQL_error( (sb2)-1, msqlErrMsg );
        return -2;
      }

    /** Store the result from the Query */
    if ( imp_sth->is_insert || imp_sth->is_create || imp_sth->is_update || imp_sth->is_drop || imp_sth->is_delete ) {
        /**
         * @@For the moment, it appears we cannot store the result of the
         * non-SELECT statements, which means we cannot return the number of
         * rows affected by non-SELECT statements.
         */
/*        imp_sth->cda = msqlStoreResult();
        if ( !imp_sth->cda ) {
            do_mSQL_error( (sb2)-1, "Cannot store result for row count!" );
            return -1;
          }
        imp_sth->row_num = msqlNumRows( imp_sth->cda );
        DBIc_IMPSET_on(imp_sth);
        msqlFreeResult( imp_sth->cda );
        imp_sth->cda = NULL;
        return imp_sth->row_num; */

        imp_sth->cda = NULL;
        imp_sth->row_num = -1;
        DBIc_IMPSET_on( imp_sth );
        return -1;
      }

    /** Store the result in the current statement handle */
    imp_sth->cda = msqlStoreResult();
    if ( !imp_sth->cda ) {
        do_mSQL_error( (sb2)-1, msqlErrMsg );
        return -2;
      }

    imp_sth->row_num = msqlNumRows( imp_sth->cda );

    if ( dbis->debug >= 2 )
        printf( "%d rows matched\n", imp_sth->row_num );

    /** Get number of fields and space needed for field names      */
    imp_sth->fbh_num = msqlNumFields( imp_sth->cda );
    if ( dbis->debug >= 2 )
        printf( "DBD::mSQL::dbd_db_prepare'imp_sth->fbh_num: %d\n",
                imp_sth->fbh_num );

    return imp_sth->row_num;
  }

int
dbd_describe(h, imp_sth)
     SV *h;
     imp_sth_t *imp_sth;
{
    D_imp_dbh_from_sth;

    sb1 *cbuf_ptr;
    int t_cbufl=0;
    sb4 f_cbufl[MAX_COLS];
    int i, field_info_loop;
    m_row cur;
    m_field *curField;
    int length;
/*  FILE *fp = DBILOGFP; */
  
    if ( dbis->debug >= 2 )
        warn( "In: DBD::mSQL::dbd_describe()\n" );

    /** 
     * Check to ensure that a) we've executed the sth; b) we haven't
     * already described this sth.
     */
/*    if ( imp_sth->done_execute == 0 || imp_sth->done_desc == 1 ) {
        return 0;
      }
    imp_sth->done_desc = 1; */

    t_cbufl = 0;

    if ( imp_sth->currow >= imp_sth->row_num )
      {
        imp_sth->fbh_num = 0;
        return 0;
      }

    /** 
     * Find the row we want to be working on in the dataset returned
     * from dbd_st_execute()
     */
    msqlDataSeek( imp_sth->cda, imp_sth->currow );

    field_info_loop = 0;
    while ( ( curField = msqlFetchField( imp_sth->cda ) ) ) {
        if ( dbis->debug >= 2 ) {
            warn( "In: DBD::mSQL::dbd_describe'Fetching Field\n" );      
          }

        f_cbufl[field_info_loop] = sizeof( curField->name );
        switch(curField->type) {
            case REAL_TYPE:
                length = strlen(curField->name);
                if (length < 12) {
                    length = 12;
                  }
                break;
            case INT_TYPE:
                length = strlen( curField->name );
                if ( length < 8 ) {
                    length = 8;
                  }
                break;
            case CHAR_TYPE:
                length = ( strlen(curField->name) < curField->length ? curField->length : strlen( curField->name ) );
                break;

            case NULL_TYPE:
                length = 0;
                imp_sth->fbh_cbuf = '\0';
                break;

            default:
                length = 0;
                imp_sth->fbh_cbuf = '\0';
                break;
          }
        f_cbufl[field_info_loop] = length;
        t_cbufl += length;
        field_info_loop++;
      }
    msqlFieldSeek(imp_sth->cda,0);

    /* allocate field buffers    */
    Newz(42, imp_sth->fbh, imp_sth->fbh_num, imp_fbh_t);
    /* allocate a buffer to hold all the column names */
    Newz(42, imp_sth->fbh_cbuf, t_cbufl + imp_sth->fbh_num, char);
      
    cbuf_ptr = (sb1*)imp_sth->fbh_cbuf;
      
    cur = msqlFetchRow( imp_sth->cda );

    /** Set the number of fields within the handle */
/*    fprintf( stderr, "imp_sth->fbh_num: %d\n", imp_sth->fbh_num ); */
    DBIc_NUM_FIELDS( imp_sth ) = imp_sth->fbh_num;

    /**
     * Foreach row, we need to allocate some space and link the
     * header record to it 
     */
    for( i = 0 ; i < imp_sth->fbh_num ; ++i ) {
        imp_fbh_t *fbh = &imp_sth->fbh[i];
        fbh->imp_sth = imp_sth;
        fbh->cbuf    = cbuf_ptr;
        fbh->cbufl   = f_cbufl[i];
          
        if ( dbis->debug >= 2 )
            warn( "In: DBD::mSQL::dbd_describe'LinkRow: %d\n", i );

        if ( cur[i] == 0 ) { 
            if ( dbis->debug >= 2 )
                warn( "Looks like a NULL!\n" ); 
            fbh->cbuf[0] = '\0'; 
            fbh->cbufl = 0;
            fbh->rlen = fbh->cbufl;
	    fbh->indp = 1;
          } else {
            fbh->cbuf = (sb1*)cur[i];
            fbh->cbufl = (sb4)strlen( (const char*)fbh->cbuf );
            fbh->rlen = fbh->cbufl;
	    fbh->indp = 0;
          } 

        if ( dbis->debug >= 2 )
            warn( "Name: %s\t%i\n", fbh->cbuf, fbh->rlen );

        fbh->cbuf[fbh->cbufl] = '\0'; /* ensure null terminated */ 
        cbuf_ptr += fbh->cbufl + 1;   /* increment name pointer    */ 
          
        /* Now define the storage for this field data.        */
        /* Hack buffer length value */
  
        fbh->dsize = fbh->cbufl;
          
        /* Is it a LONG, LONG RAW, LONG VARCHAR or LONG VARRAW?    */
        /* If so we need to implement oraperl truncation hacks.    */
        /* This may change in a future release.            */

        fbh->bufl = fbh->dsize + 1;
          
        /* for the time being we fetch everything as strings    */
        /* that will change (IV, NV and binary data etc)    */
        /* currently we use an sv, later we'll use an array     */

        if ( dbis->debug >= 2 )
            warn( "In: DBD::mSQL::dbd_describe'newSV\n" );
        fbh->sv = newSV((STRLEN)fbh->bufl); 

        if ( dbis->debug >= 2 )
            warn( "In: DBD::mSQL::dbd_describe'SvUPGRADE\n" );
        (void)SvUPGRADE(fbh->sv, SVt_PV);

        if ( dbis->debug >= 2 )
            warn( "In: DBD::mSQL::dbd_describe'SvREADONLY_ON\n" );
        SvREADONLY_on(fbh->sv);

        if ( dbis->debug >= 2 )
            warn( "In: DBD::mSQL::dbd_describe'SvPOK_only\n" );
        (void)SvPOK_only(fbh->sv);

        if ( dbis->debug >= 2 )
            warn( "In: DBD::mSQL::dbd_describe'SvPVX\n" );
        fbh->buf = (ub1*)SvPVX(fbh->sv);
     }

    if ( dbis->debug >= 2 ) {
        printf( "Entering imp_sth->fbh test cycle\n" );
        for(i = 0 ; i <  imp_sth->fbh_num /* && imp_sth->cda->rc!=10 */ ; ++i ) {

            imp_fbh_t *fbh = &imp_sth->fbh[i];

            printf( "In: DBD::mSQL::dbd_describe'FBHDump[%d]: %s\t%d\n",
                    i, fbh->cbuf, fbh->rlen );
         }
      }
    if ( dbis->debug )
        printf( "Out: DBD::mSQL::dbd_describe()\n" );
    return 0;
  }

int
dbd_st_rows(sth)
    SV *sth;
{
    D_imp_sth(sth);
    return imp_sth->row_num;
  }

int
dbd_st_finish(sth)
    SV *sth;
{
    D_imp_sth(sth);
    /* Cancel further fetches from this cursor.                 */
    /* We don't close the cursor till DESTROY.                  */
    /* The application may re execute it.                       */
    DBIc_ACTIVE_off(imp_sth);
    return 1;
}

void
dbd_st_destroy(sth)
    SV *sth;
{
    D_imp_sth(sth);
    D_imp_dbh_from_sth;

    /* Free off contents of imp_sth     */
    if ( dbis->debug >= 2 ) {
        warn( "dbd_st_destroy()\n" );
      }
/** Unused in DBD::mSQL currently 
    fields = DBIc_NUM_FIELDS(imp_sth);
    imp_sth->in_cache    = 0;
    for(i=0; i < fields; ++i) {
        imp_fbh_t *fbh = &imp_sth->fbh[i];
        fb_ary_free(fbh->fb_ary);
    } */
    Safefree(imp_sth->fbh);
    Safefree(imp_sth->fbh_cbuf);
    Safefree(imp_sth->statement);

    DBIc_IMPSET_off(imp_sth);           /* let DBI know we've done it   */
}

int
dbd_st_STORE(sth, keysv, valuesv)
    SV *sth;
    SV *keysv;
    SV *valuesv;
{
    D_imp_sth(sth);
    STRLEN kl;
    char *key = SvPV(keysv,kl);
    SV *cachesv = NULL;
    int on = SvTRUE(valuesv);

    if (kl==8 && strEQ(key, "ora_long")){
        imp_sth->long_buflen = SvIV(valuesv);

    } else if (kl==9 && strEQ(key, "ora_trunc")){
        imp_sth->long_trunc_ok = on;

    } else {
        return FALSE;
    }
    if (cachesv) /* cache value for later DBI 'quick' fetch? */
        hv_store((HV*)SvRV(sth), key, kl, cachesv, 0);
    return TRUE;
}


SV *
dbd_st_FETCH(sth, keysv)
    SV *sth;
    SV *keysv;
{
    D_imp_sth(sth);
    STRLEN keyLength;
    char *key = SvPV( keysv, keyLength );
    int numFields,
        i;
    SV *retsv = NULL;

    /** Grab the number of fields from the statement handle */
    numFields = i = DBIc_NUM_FIELDS( imp_sth );
/*    fprintf( stderr, "numFields: %d\n", numFields );

    fprintf( stderr, "kl: %d\tkey: %s\n", keyLength, key ); */

    /** Return a reference to an array of the column names */
    if ( keyLength == 4 && strEQ( key, "NAME" ) ) {
        AV *av = newAV();
        m_field *field = msqlFetchField( imp_sth->cda );

        if ( field == NULL ) {
/*            fprintf( stderr, "Field is NULL!\n" ); */
            return Nullsv;
          }
        retsv = newRV( sv_2mortal( (SV *)av ) );

        while ( i >= 0 && field != NULL ) {
/*            fprintf( stderr, "Field: %s\n", field->name ); */
            av_store( av, ( numFields - i ), 
                      newSVpv( (char *)field->name, 0 ) );
            field = msqlFetchField( imp_sth->cda );
            i--;
          }
      } else {
        return Nullsv;
      }

    return sv_2mortal( retsv );
}
