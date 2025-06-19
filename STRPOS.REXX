/*---------------------------------------------------------------+
| Function : Locate strings within a record and return the       |
|            column.length of the string                         |
|                                                                |
| File     : STRPOS   REXX                                       |
+----------------------------------------------------------------+
| Version  : 1.1.0                                               |
|                                                                |
| Files    : .                                                   |
|                                                                |
| Called   : STRPOS   <scanstring>  <ANYCASE> <DETAILS>          |
|                                                                |
|                     <scanstring> is a string we are scanning   |
|                                  for delimited by 2 equal      |
|                                  characters (e.g. /Scan/)      |
|                     <ANYCASE>    Makes the scan case-          |
|                                  insensitive, when ommitted    |
|                                  casing does matter            |
|                     <DETAILS>    If entered the record prefixed|
|                                  with the line number and      |
|                                  suffixed with the             |
|                                  column.length will be shown   |
|                                  When ommitted only the        |
|                                  linenumber with column.length |
|                                  will be returned              |
|                                                                |
| Comments : .                                                   |
|                                                                |
| Author   : H.T.Kramer, ,                                       |
| Created  : 20230117 09:30:20                                   |
| Changes  : .                                                   |
|                                                                |
+---------------------------------------------------------------*/
Parse Arg input
strsep=Substr(input,1,1)
input=Substr(input,2)
Parse Value input With scanstring c2x(strsep) options
options=Strip(options)
Upper options
If Wordpos('ANYCASE',options)<>0 Then caresens='ANYCASE'
                                 Else caresens=''
If Wordpos('DETAILS',options)<>0 Then detail=1
                                 Else detail=0
/*---------------------------------------------------------------+
| Get the input from caller                                      |
+---------------------------------------------------------------*/
'CALLPIPE (NAME STRPOS.REXX:47 END ?)',
   '*:',                                         /* Take from caller */
   '| specs pad 0 recno 1.6 right 1;* nw',       /* Add line no      */
   '| stem record.'                              /* Hand 2 rexx      */
/*---------------------------------------------------------------+
| Loop thru the records                                          |
+---------------------------------------------------------------*/
Do r=1 To record.0
   line=Substr(record.r,1,6)                     /* Take line no     */
   work=Substr(record.r,8)                       /* Take content     */
   columns=''                                    /* Initialise       */
   'CALLPIPE (NAME STRPOS.REXX:58 END ?)',
      'var work',                                /* Take this        */
      '| split 'caresens' before string ~'scanstring'~',   /* Split here       */
      '| split 'caresens' after  string ~'scanstring'~',   /* .and here        */
      '| stem work.'                             /* Hand 2 rexx      */
   strlen=Length(scanstring)                     /* Determine length */
   colpos=1                                      /* Initialise       */
/*---------------------------------------------------------------+
| Loop thru the parts of the record                              |
+---------------------------------------------------------------*/
   Do w=1 To work.0
      itemlen=Length(work.w)
      work.w=work.w colpos'.'strlen
      colpos=colpos+itemlen
   End w
/*---------------------------------------------------------------+
| Now collect and join all findings                              |
+---------------------------------------------------------------*/
   'CALLPIPE (NAME STRPOS.REXX:76 END ?)',
      'stem work.',                              /* Take these       */
      '| pick 'caresens' 1;'strlen' == ~'scanstring'~',   /* Select these     */
      '| specs w2;* 1',                          /* Keep column.length*/
      '| join * x40',                            /* Make 1 record    */
      '| var columns tracking'                   /* Hand 2 rexx      */
/*---------------------------------------------------------------+
| Do we need details?                                            |
+---------------------------------------------------------------*/
   If detail Then Do
             record.r=record.r columns
             filter=''
             End
             Else Do
             record.r=line columns
             filter='| pick w2.1 \== ~~'
             End
   Drop work work. columns strlen itemlen
End r
/*---------------------------------------------------------------+
| Return the outcome to our caller                               |
+---------------------------------------------------------------*/
'CALLPIPE (NAME STRPOS.REXX:98 END ?)',
    'stem record.',                              /* Take these       */
    filter,                                      /* Filter if needed */
    '| *:'                                       /* Return 2 caller  */
Return
