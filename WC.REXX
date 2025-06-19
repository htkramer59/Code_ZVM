/*---------------------------------------------------------------+
| Function : Wildcard..different from standard PIPE WILDCARD     |
|                                                                |
| File     : WC       REXX                                       |
+----------------------------------------------------------------+
| Version  : 1.1.0                                               |
|                                                                |
| Files    : .                                                   |
|                                                                |
| Called   : WC       <CASEANY> <ZONE> <STRING>                  |
|                                                                |
| Comments : .                                                   |
|                                                                |
| Author   : H.T.Kramer, ,                                       |
| Created  : 20210120 13:39:58                                   |
| Changes  : .                                                   |
|                                                                |
+---------------------------------------------------------------*/
Parse Arg argline
argline=Strip(argline)                           /* Remove spaces    */
mysep='FF'x
/*---------------------------------------------------------------+
| Some preparation                                               |
+---------------------------------------------------------------*/
'CALLPIPE (NAME WC.REXX:25 END ?)',
    '*:',                                        /* Receive records  */
    '| stem info.',                              /* Store 4 later    */
    '?',                                         /* 2nd pipe         */
    'var argline',                               /* Take this        */
    '| specs -1;-1',                             /* Last one is seprt*/
    '| var sep'                                  /* Store as         */
/*---------------------------------------------------------------+
| Rip the argument line into pieces                              |
+---------------------------------------------------------------*/
'CALLPIPE (NAME WC.REXX:35 END ?)',
    'var argline',                               /* Take this        */
    '| split before string 'mysep||sep||mysep,   /* Split here       */
    '| split after string 'mysep||sep||mysep,    /* ...and here      */
    '| t: take first 1',                         /* Take this        */
    '| split',                                   /* ...and split     */
    '| l: locate anycase ~ANYCASE~',             /* Select these     */
    '| xlate upper',                             /* Uppercase 4 later*/
    '| append literal ',                         /* Initialize       */
    '| join *',                                  /* ...at            */
    '| strip',                                   /* ....least        */
    '| var wc_case',                             /* .....this var    */
    '? l:',                                      /* Conn 2 locate    */
    '| append literal ',                         /* Initialize       */
    '| join *',                                  /* ...at            */
    '| strip',                                   /* ....least        */
    '| var wc_zone',                             /* .....this var    */
    '? t:',                                      /* Conn 2 take      */
    '| nlocate 'mysep||sep||mysep,               /* Remove these     */
    '| split at string ~*~',                     /* Split here       */
    '| specs ~'mysep'~ 1 w1.1 n ~'mysep'~ n',    /* Prepare 4 all    */
    '| join * ~ & ~',                            /* Make 1 record    */
    '| specs ~ALL~ 1 1;* nw',                    /* Prep var         */
    '| var wc_select'                            /* Store as         */
If wc_case='ANYCASE' Then wc_case='CASEI'
                     Else wc_case=''
If wc_zone<>'' Then wc_zone='ZONE 'wc_zone
/*---------------------------------------------------------------+
| Select the records and return them to caller..                 |
+---------------------------------------------------------------*/
'CALLPIPE (NAME WC.REXX:65 END ?)',
    'stem info.',                                /* Take these       */
    '| 'wc_case wc_zone wc_select,               /* Run this filter  */
    '| *:'                                       /* Hand 2 caller    */
Return
