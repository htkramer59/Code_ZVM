/*--------------------------------------------------------------------+
| Function : Strip within a zones in a record                         |
|                                                                     |
| File     : ZSTRIP   REXX                                            |
+---------------------------------------------------------------------+
| Version  : 1.1.0                                                    |
|                                                                     |
| Files    : .                                                        |
|                                                                     |
| Called   : ZSTRIP   <zone> <L,T,B> <character>                      |
|                                                                     |
|            <zone>      Inputrange to be stripped                    |
|            <L,T,B>     Leadin, Trailing or Both                     |
|            <character> Can be a delimited charactor or hex value    |
|                        e.g. /0/ , x51. Defaults to x40/space        |
|                                                                     |
| Comments : Only 1 zone can be specified!!                           |
|                                                                     |
| Author   : H.T.Kramer, At_home,                                     |
| Created  : 20260312 20:31:29                                        |
| Changes  : .                                                        |
|                                                                     |
+--------------------------------------------------------------------*/
Parse Upper Arg zone lead_trail char .
/*--------------------------------------------------------------------+
| Check the arguments                                                 |
+--------------------------------------------------------------------*/
Upper lead_trail zone
Select
When lead_trail=''  Then lead_trail='BOTH'
When lead_trail='B' Then lead_trail='BOTH'
When lead_trail='L' Then lead_trail='LEADING'
When lead_trail='T' Then lead_trail='TRAILING'
Otherwise Call Exit '26 Invalid value for L,T,B: 'lead_trail
End
If char=''       Then char='x40'
If Substr(zone,1,1)='W' Then Call Zoning 'W'
                        Else Call Zoning
/*--------------------------------------------------------------------+
| Take the records in                                                 |
+--------------------------------------------------------------------*/
'CALLPIPE (NAME ZSTRIP.REXX:42 end ?)',
      '*:',                                           /* Take from caller */
      '| stem item.'                                  /* Hand 2 rexx      */
/*--------------------------------------------------------------------+
| Loop thru the records and process them                              |
+--------------------------------------------------------------------*/
Do i=1 To item.0
   work=item.i
   'CALLPIPE (NAME ZSTRIP.REXX:50 end ?)',
        'var work',                                   /* Take this        */
        '| fo: fanout',                               /* Duplicate record */
        part1,                                        /* .                */
        '| fi: faninany',                             /* Take in others   */
        '| sort 1.1',                                 /* Sort on recno    */
        '| specs 3;* 1',                              /* Remove recno     */
        '| join * x40',                               /* Make 1 record    */
        '| var work',                                 /* Hand 2 rexx      */
        '? fo:',                                      /* Conn 2 fanout    */
        part2,                                        /* .                */
        '| split at x40',                             /* Split here       */
        '| strip 'lead_trail char,                    /* Remove char      */
        '| join * x40',                               /* Make 1 record    */
        '| specs ~2~ 1 1;* nw',                       /* Add recno        */
        '| fi:',                                      /* Conn 2 faninany  */
        '? fo:',                                      /* Conn 2 fanout    */
        part3,                                        /* .                */
        '| fi:'                                       /* Conn to faninany */
   item.i=work
End i
/*--------------------------------------------------------------------+
| .                                                                   |
+--------------------------------------------------------------------*/
'CALLPIPE (NAME ZSTRIP.REXX:74 end ?)',
   'stem item.',                                      /* Take these       */
   '| *:'                                             /* Hand 2 caller    */
 
Exit:
/*---------------------------------------------------------------+
| General Exit routine                                           |
+---------------------------------------------------------------*/
Parse Arg exrc errmsg
If Datatype(exrc,'NUM') Then Say errmsg exrc
                        Else exrc=0
Exit exrc
 
 
Zoning:
/*--------------------------------------------------------------------+
| Do some prep for zone with words                                    |
+--------------------------------------------------------------------*/
Parse Arg wrd .
range='';dash=0;semi=0;dot=0
If wrd<>'' Then Do
                wrd='W'
                Parse Value zone With 'WORD'range
                If range='' Then Parse Value zone With 'W'range
                End
                Else Do
                wrd=''
                range=zone
                End
dash=Pos('-',range);semi=Pos(';',range);point=Pos('.',range)
Select
When semi<>0  Then Do
/*--------------------------------------------------------------------+
| We found a semicolon so we need these steps                         |
+--------------------------------------------------------------------*/
              Parse Value range With upto ';' from .
              If from+1=0 Then part3='| hole'
                          Else part3='| specs ~3~ 1 'wrd||from+1';* nw'
              Select
              When upto-1=0 Then part1='| hole'
              When upto<0   Then part1='| specs ~1~ 1 'wrd'1;'upto+1' nw'
              When upto>0   Then part1='| specs ~1~ 1 'wrd'1;'upto-1' nw'
              Otherwise Nop
              End
              part2='| specs 'zone' 1'
              End
When dash<>0  Then Do
/*--------------------------------------------------------------------+
| We found a dash (-) prepare for that                                |
+--------------------------------------------------------------------*/
              Parse Value range With upto '-' from .
              If upto>1 Then part1='| specs ~1~ 1 'wrd'1-'upto-1' nw'
                        Else part1='| hole'
              part2='| specs 'zone' 1'
              part3='| specs ~3~ 1 'wrd||from+1'-* nw'
              End
When point<>0 Then Do
/*--------------------------------------------------------------------+
| Dealing with a . (point)                                            |
+--------------------------------------------------------------------*/
              Parse Value range With upto '.' from .
              If upto>1 Then part1='| specs ~1~ 1 'wrd'1-'upto-1' nw'
                        Else part1='| hole'
              part1='| specs ~1~ 1 'wrd'1.'upto-1' nw'
              part2='| specs 'zone' 1'
              part3='| specs ~3~ 1 'wrd||from+1';* nw'
              End
Otherwise Call Exit '28 Invalid spec: 'zone
End
Return
