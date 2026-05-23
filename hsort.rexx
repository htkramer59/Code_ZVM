/*--------------------------------------------------------------------+
| Function : Sort words within a record                               |
|                                                                     |
| File     : HSORT    REXX                                            |
+---------------------------------------------------------------------+
| Version  : 1.1.0                                                    |
|                                                                     |
| Files    : .                                                        |
|                                                                     |
| Called   : HSORT    <zone> <asc_desc>                               |
|                                                                     |
|            <zone>     Inputrange to be sorted (only Words)          |
|            <asc_desc> Ascending or Descending, specify A or D       |
|                                                                     |
|                                                                     |
|                                                                     |
| Comments : Only 1 zone can be specified!!                           |
|                                                                     |
| Author   : H.T.Kramer, At_home,                                     |
| Created  : 20260312 20:31:46                                        |
| Changes  : .                                                        |
|                                                                     |
+--------------------------------------------------------------------*/
Parse Upper Arg zone asc_desc .
/*--------------------------------------------------------------------+
| .                                                                   |
+--------------------------------------------------------------------*/
If zone='' Then Call Exit '28 No arguments'
If asc_desc='' then asc_desc='A'
If Pos('A',asc_desc)=0 & Pos('D',asc_desc)=0 Then Call Exit '29 Invalid input: 'asc_desc
/*--------------------------------------------------------------------+
| Find out how zone was specified and act on it                       |
+--------------------------------------------------------------------*/
point=Pos('.',zone);dash=Pos('-',zone);semi=Pos(';',zone)
If Substr(zone,1,1)='W' Then Do
                             wrd='W'
                             Parse Value zone With 'W' range .
                             If range='' Then Parse Value zone With 'WORD' range .
                             End
                             Else wrd=''
/*--------------------------------------------------------------------+
| Deal with zone specified with ;,- or .                              |
+--------------------------------------------------------------------*/
Select
When semi<>0 Then Do
                  Parse Value range With upto';'from
                  If upto='1' Then part1=''
                              Else part1='| specs ~1~ 1 'wrd'1;'upto-1' nw'
                  part2='| specs 'zone' 1'
                  If from='*' Then from=99999
                  part3='| specs ~3~ 1 'wrd||from+1';* nw'
                  End
When dash<>0 Then Do
                  Parse Value range With upto'-'from
                  If upto='1' Then part1=''
                              Else part1='| specs ~1~ 1 'wrd'1-'upto-1' nw'
                  part2='| specs 'zone' 1'
                  If from='*' Then from=99999
                  part3='| specs ~3~ 1 'wrd||from+1'-* nw'
                  End
When point<>0 Then Do
                  Parse Value range With upto'.'from
                  If upto='1' Then part1=''
                              Else part1='| specs ~1~ 1 'wrd'1.'upto-1' nw'
                  part2='| specs 'zone' 1'
                  If from='*' Then from=99999
                  part3='| specs ~3~ 1 'wrd||upto+from';* nw'
                  End
Otherwise Call Exit '29 Invalid spec'
End
/*--------------------------------------------------------------------+
| Take all records from caller                                        |
+--------------------------------------------------------------------*/
'CALLPIPE (NAME HSORT.REXX:74 end ?)',
   '*:',                                              /* Take records     */
   '| stem item.'                                     /* Hand 2 rexx      */
/*--------------------------------------------------------------------+
| Loop thru the records/items                                         |
+--------------------------------------------------------------------*/
Do i=1 To item.0
   work=item.i
   'CALLPIPE (NAME HSORT.REXX:82 end ?)',
       'var work',                                    /* Take this        */
       '| fo: fanout',                                /* Dupl. record     */
       part1,                                         /* .                */
       '| fi: faninany',                              /* Take in others   */
       '| sort 1.1',                                  /* Sort on label    */
       '| specs 3;*',                                 /* Remove label     */
       '| join * x40',                                /* Make 1 record    */
       '| var work',                                  /* Hand 2 rexx      */
       '? fo:',                                       /* Conn 2 fanout    */
       part2,                                         /* .                */
       '| split at x40',                              /* Split into record*/
       '| sort 'asc_desc,                             /* Sort             */
       '| join * x40',                                /* Rejoin them      */
       '| specs ~2~ 1 1;* nw',                        /* Add label        */
       '| fi:',                                       /* Conn 2 faninany  */
       '? fo:',                                       /* Conn 2 fanout    */
       part3,                                         /* .                */
       '| fi:'                                        /* Conn 2 faninany  */
   item.i=work
End i
/*--------------------------------------------------------------------+
| Hand all items/records back                                         |
+--------------------------------------------------------------------*/
'CALLPIPE (NAME HSORT.REXX:106 end ?)',
    'stem item.',                                     /* Take these       */
    '| *:'                                            /* Return 2 caller  */
 
Exit:
/*---------------------------------------------------------------+
| General Exit routine                                           |
+---------------------------------------------------------------*/
Parse Arg exrc errmsg
If Datatype(exrc,'NUM') Then Say errmsg exrc
                        Else exrc=0
Exit exrc
