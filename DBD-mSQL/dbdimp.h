/*
 *  DBD::mSQL - DBI driver for the mysql database
 *
 *  Copyright (c) 1997  Jochen Wiedmann
 *
 *  Based on DBD::Oracle; DBD::Oracle is
 *
 *  Copyright (c) 1994,1995  Tim Bunce
 *
 *  You may distribute this under the terms of either the GNU General Public
 *  License or the Artistic License, as specified in the Perl README file,
 *  with the exception that it cannot be placed on a CD-ROM or similar media
 *  for commercial distribution without the prior approval of the author.
 *
 *  Author:  Jochen Wiedmann
 *           Am Eisteich 9
 *           72555 Metzingen
 *           Germany
 *
 *           Email: wiedmann@neckar-alb.de
 *           Fax: +49 7123 / 14892
 *
 *
 *  $Id: dbdimp.h 1.1 Tue, 30 Sep 1997 00:21:06 +0200 joe $
 */

/*
 *  Header files we use
 */
#define NEED_DBIXS_VERSION 9
#include <DBIXS.h>  /* installed by the DBI module                        */
#include "myMsql.h"


/*
 *  The following are return codes passed in $h->err in case of
 *  errors by DBD::mysql.
 */
enum errMsgs {
    JW_ERR_CONNECT = 1,
    JW_ERR_SELECT_DB,
    JW_ERR_STORE_RESULT,
    JW_ERR_NOT_ACTIVE,
    JW_ERR_QUERY,
    JW_ERR_FETCH_ROW,
    JW_ERR_LIST_DB,
    JW_ERR_CREATE_DB,
    JW_ERR_DROP_DB,
    JW_ERR_LIST_TABLES,
    JW_ERR_LIST_FIELDS,
    JW_ERR_LIST_FIELDS_INT,
    JW_ERR_LIST_SEL_FIELDS,
    JW_ERR_NO_RESULT,
    JW_ERR_NOT_IMPLEMENTED,
    JW_ERR_ILLEGAL_PARAM_NUM,
    JW_ERR_MEM
};


/*
 *  The following values are stored in imp_sth->type.
 *
 *  Positive values indicate a command returning a result, other
 *  commands have negative values.
 */
enum command_types {
    COMMAND_UNKNOWN = 0,
    COMMAND_SELECT,
    COMMAND_SYSTABLES,
    COMMAND_LISTFIELDS,
    COMMAND_CREATE = -1,
    COMMAND_DROP = -2,
    COMMAND_INSERT = -3,
    COMMAND_DELETE = -4,
    COMMAND_UPDATE = -5,
    COMMAND_ALTER = -6
};


/*
 *  Internal constants, used for fetching array attributes
 */
enum av_attribs {
    AV_ATTRIB_NAME = 0,
    AV_ATTRIB_TABLE,
    AV_ATTRIB_TYPE,
    AV_ATTRIB_IS_PRI_KEY,
    AV_ATTRIB_IS_NOT_NULL,
    AV_ATTRIB_NULLABLE,
    AV_ATTRIB_LENGTH,
    AV_ATTRIB_IS_NUM,
    AV_ATTRIB_TYPE_NAME,
#ifdef DBD_MYSQL
    AV_ATTRIB_MAX_LENGTH,
    AV_ATTRIB_IS_KEY,
    AV_ATTRIB_IS_BLOB,
#endif
    AV_ATTRIB_LAST         /*  Dummy attribute, never used, for allocation  */
};                         /*  purposes only                                */


/*
 *  This is our part of the driver handle. We receive the handle as
 *  an "SV*", say "drh", and receive a pointer to the structure below
 *  by declaring
 *
 *    D_imp_drh(drh);
 *
 *  This declares a variable called "imp_drh" of type
 *  "struct imp_drh_st *".
 */
struct imp_drh_st {
    dbih_drc_t com;         /* MUST be first element in structure   */
};


/*
 *  Likewise, this is our part of the database handle, as returned
 *  by DBI->connect. We receive the handle as an "SV*", say "dbh",
 *  and receive a pointer to the structure below by declaring
 *
 *    D_imp_dbh(dbh);
 *
 *  This declares a variable called "imp_dbh" of type
 *  "struct imp_dbh_st *".
 */
struct imp_dbh_st {
    dbih_dbc_t com;         /*  MUST be first element in structure   */
    
#ifdef DBD_MYSQL
    MYSQL mysql;
#endif
    dbh_t svsock;           /*  socket number for msql, &mysql for
			     *  mysql
			     */
};


/*
 *  The bind_param method internally uses this structure for storing
 *  parameters.
 */
typedef struct imp_sth_ph_st {
    SV* value;
    int type;
} imp_sth_ph_t;


/*
 *  Finally our part of the statement handle. We receive the handle as
 *  an "SV*", say "dbh", and receive a pointer to the structure below
 *  by declaring
 *
 *    D_imp_sth(sth);
 *
 *  This declares a variable called "imp_sth" of type
 *  "struct imp_sth_st *".
 */
struct imp_sth_st {
    dbih_stc_t com;       /* MUST be first element in structure     */

    result_t cda;            /* result                                 */
    int currow;           /* number of current row                  */
    int row_num;          /* total number of rows                   */

    int   done_desc;      /* have we described this sth yet ?	    */
    long  long_buflen;    /* length for long/longraw (if >0)	    */
    bool  long_trunc_ok;  /* is truncating a long an error	    */
    int   command;        /* Statement command, e.g. COMMAND_SELECT */
    int   insertid;       /* ID of auto insert                      */
    imp_sth_ph_t* params; /* Pointer to parameter array             */
    AV* av_attr[AV_ATTRIB_LAST];/*  For caching array attributes        */
};


/*
 *  And last, not least: The prototype definitions.
 *
 * These defines avoid name clashes for multiple statically linked DBD's	*/
#ifdef DBD_MYSQL
#define dbd_init		mysql_init
#define dbd_db_login		mysql_db_login
#define dbd_db_do		mysql_db_do
#define dbd_db_commit		mysql_db_commit
#define dbd_db_rollback		mysql_db_rollback
#define dbd_db_disconnect	mysql_db_disconnect
#define dbd_db_destroy		mysql_db_destroy
#define dbd_db_STORE_attrib	mysql_db_STORE_attrib
#define dbd_db_FETCH_attrib	mysql_db_FETCH_attrib
#define dbd_st_prepare		mysql_st_prepare
#define dbd_st_rows		mysql_st_rows
#define dbd_st_execute		mysql_st_execute
#define dbd_st_fetch		mysql_st_fetch
#define dbd_st_finish		mysql_st_finish
#define dbd_st_destroy		mysql_st_destroy
#define dbd_st_blob_read	mysql_st_blob_read
#define dbd_st_STORE_attrib	mysql_st_STORE_attrib
#define dbd_st_FETCH_attrib	mysql_st_FETCH_attrib
#define dbd_describe		mysql_describe
#define dbd_bind_ph		mysql_bind_ph
#else
#define dbd_init		msql_init
#define dbd_db_login		msql_db_login
#define dbd_db_do		msql_db_do
#define dbd_db_commit		msql_db_commit
#define dbd_db_rollback		msql_db_rollback
#define dbd_db_disconnect	msql_db_disconnect
#define dbd_db_destroy		msql_db_destroy
#define dbd_db_STORE_attrib	msql_db_STORE_attrib
#define dbd_db_FETCH_attrib	msql_db_FETCH_attrib
#define dbd_st_prepare		msql_st_prepare
#define dbd_st_rows		msql_st_rows
#define dbd_st_execute		msql_st_execute
#define dbd_st_fetch		msql_st_fetch
#define dbd_st_finish		msql_st_finish
#define dbd_st_destroy		msql_st_destroy
#define dbd_st_blob_read	msql_st_blob_read
#define dbd_st_STORE_attrib	msql_st_STORE_attrib
#define dbd_st_FETCH_attrib	msql_st_FETCH_attrib
#define dbd_describe		msql_describe
#define dbd_bind_ph		msql_bind_ph
#endif

#include <dbd_xsh.h>
void	 do_error _((SV* h, int rc, char *what));
SV	*dbd_db_fieldlist _((result_t res));

void    dbd_preparse _((imp_sth_t *imp_sth, SV *statement));

