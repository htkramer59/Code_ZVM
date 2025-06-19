/*---------------------------------------------------------------+
| Function : Mark the highest value in a column by prefixing     |
|            it with *                                           |
|                                                                |
| File     : MAXMARK  REXX                                       |
+----------------------------------------------------------------+
| Version  : 1.1.0                                               |
|                                                                |
| Files    : .                                                   |
|                                                                |
| Called   : MAXMARK  <w1.1 wn.n>                                |
|                                                                |
| Comments : .                                                   |
|                                                                |
| Author   : H.T.Kramer, ,                                       |
| Created  : 20220127 14:47:28                                   |
| Changes  : .                                                   |
|                                                                |
+---------------------------------------------------------------*/
Parse Upper Arg ranges
/*---------------------------------------------------------------+
| Take in the records and work on the ranges                     |
+---------------------------------------------------------------*/
'CALLPIPE (NAME MAXMARK.REXX:4 END ?)',
    '*:',                                        /* Take in fr caller*/
    '| stem work.',                              /* Hand 2 rexx      */
    '?',                                         /* 2nd pipe         */
    'var ranges',                                /* Take argument    */
    '| split',                                   /* Split            */
    '| change anycase ~WORD~W~',                 /* Replace this     */
    '| stem range.'                              /* Hand 2 rexx      */
/*---------------------------------------------------------------+
| Set these equal                                                |
+---------------------------------------------------------------*/
marker.0=range.0
Do r=1 To range.0
   Select
   When Pos(';',range.r)<>0 Then Call SetRange ';'
   When Pos('.',range.r)<>0 Then Call SetRange '.'
   When Pos('-',range.r)<>0 Then Call SetRange '-'
   Otherwise marker=''
   End
   Call Mark
End r
'CALLPIPE (NAME MAXMARK.REXX:22 END ?)',
   'stem work.',                                 /* Take these       */
   marker,                                       /* Make changes     */
   '| *:'                                        /* Hand 2 caller    */
Return
 
 
Mark:
/*---------------------------------------------------------------+
| Create the markings                                            |
+---------------------------------------------------------------*/
Parse Var range strcol endcol .
Do m=strcol To endcol
  'CALLPIPE (NAME MAXMARK.REXX:35 END ?)',
      'stem work.',                              /* Take these       */
      '| specs pad 0 w'strcol'.1 1.10 right',    /* Take column      */
      '| sort w1.1 d',                           /* Sort descending  */
      '| take first 1',                          /* Take highest     */
      '| strip leading ~0~',                     /* Remove zeros     */
      '| specs ~CHANGE w'strcol'.1 /~ 1',        /* Compose          */
              'w1.1 n',                          /* ..pipe           */
              '~/*~ n',                          /* ...changes       */
              'w1.1 n',                          /* .                */
              '~/~ n',                           /* .                */
      '| var work'                               /* Hand 2 rexx      */
  marker.r=work                                  /* Move to stem     */
End m
'CALLPIPE (NAME MAXMARK.REXX:45 END ?)',
   'stem marker.',                               /* Take these       */
   '| join * x4F',                               /* Make 1 record    */
   '| specs x4F 1 1;* nw',                       /* Add vert. bar    */
   '| var marker'                                /* Hand 2 rexx      */
marker=marker' | change ~ *~*~'                  /* Add this         */
Return
 
 
SetRange:
/*---------------------------------------------------------------+
| Rework the ranges to usable stuff..                            |
+---------------------------------------------------------------*/
Parse Arg type .
If type='.' Then Do
       Parse Value range.r With 'W' start '.' len .
       range=start start+len
       End
If type='-' Then Do
       Parse Value range.r With 'W' start '-' len .
       range=start len
       End
/*---------------------------------------------------------------+
| Needs work on -n;-m and n;*                                    |
+---------------------------------------------------------------*/
If type=';' Then Do
       Parse Value range.r With 'W' start ';' len.
       If len='*' Then len=9999
       range=start start+len
       End
Return
