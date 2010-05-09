/*
 * Copyright (C) 2002-2009, Parrot Foundation.
 * $Id$
 */

#ifndef PARROT_IMCC_PARSER_H_GUARD
#define PARROT_IMCC_PARSER_H_GUARD

typedef struct _IdList {
    char* id;
    struct _IdList*  next;
} IdList;

#include "imcparser.h"

#define KEY_BIT(argnum) (1 << (argnum))

/* An opaque pointer. */
#ifndef YY_TYPEDEF_YY_SCANNER_T
#  define YY_TYPEDEF_YY_SCANNER_T
typedef void* yyscan_t;
#endif

void set_filename(PARROT_INTERP, char * const filename);

SymReg * macro(PARROT_INTERP, char *name);

PARROT_EXPORT int yyparse(yyscan_t, PARROT_INTERP);
PARROT_EXPORT int yylex(YYSTYPE *, yyscan_t, PARROT_INTERP);
PARROT_EXPORT int yylex_destroy(yyscan_t);

int yylex_init(yyscan_t*);
int yyget_column(yyscan_t);
void yyset_column(int column_no , yyscan_t);
int yyerror(yyscan_t, Interp*, const char *);

/* These are generated by flex. YY_EXTRA_TYPE is used also by flex, so
 * defining it is handy: we do not need typecasts. */
#define YY_EXTRA_TYPE Interp*
YY_EXTRA_TYPE yyget_extra(yyscan_t yyscanner);
void yyset_extra(YY_EXTRA_TYPE user_defined, yyscan_t yyscanner);

extern void compile_file(PARROT_INTERP, FILE *file, void *);
extern void compile_string(PARROT_INTERP, const char *, void *);

int at_eof(yyscan_t yyscanner);

#endif /* PARROT_IMCC_PARSER_H_GUARD */

/*
 * Local variables:
 *   c-file-style: "parrot"
 * End:
 * vim: expandtab shiftwidth=4:
 */
