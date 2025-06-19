/*---------------------------------------------------------------+
| Function : Round up or down numbers in a record                |
|                                                                |
| File     : ROUND    REXX                                       |
+----------------------------------------------------------------+
| Version  : 1.1.0                                               |
|                                                                |
| Files    : .                                                   |
|                                                                |
| Called   : ROUND    <ranges>                                   |
|                                                                |
|                     <ranges> can be specified as:              |
|                              W1;3                              |
|                              WORD1;3                           |
|                              W1.3                              |
|                              WORD1.3                           |
|                              W2-5                              |
|                              WORD2-5                           |
|                                                                |
| Comments : You can specify multiple ranges                     |
|                                                                |
| Author   : H.T.Kramer, ,                                       |
| Created  : 20220118 10:35:52                                   |
| Changes  : .                                                   |
|                                                                |
+---------------------------------------------------------------*/
Parse Upper Arg ranges
/*---------------------------------------------------------------+
| Take input from caller and split the ranges into a stem        |
+---------------------------------------------------------------*/
invrange=''
'CALLPIPE (NAME ROUND.REXX:32 END ?)',
    '*:',                                        /* Take from caller */
    '| stem input.',                             /* Hand 2 rexx      */
    '?',                                         /* 2nd pipe         */
    'var ranges',                                /* Take input       */
    '| split',                                   /* Split into record*/
    '| strip',                                   /* Remove spaces    */
    '| change ~WORD~W~',                         /* Replace this     */
    '| p: pick 1.1 == ~W~',                      /* Select these     */
    '| specs 2;* 1',                             /* Remove W         */
    '| stem range.',                             /* Hand 2 rexx      */
    '? p:',                                      /* Conn 2 pick      */
    '| join * x40',                              /* Make 1 record    */
    '| append literal ',                         /* Prevent no var   */
    '| var invrange'                             /* Store as         */
If invrange<>'' Then Call Exit '98 Invalid range(s): 'invrange
/*---------------------------------------------------------------+
| Work through the ranges that were entered                      |
+---------------------------------------------------------------*/
Do r=1 To range.0
   Call RangeType
End r
/*---------------------------------------------------------------+
| Return the stuff to the caller                                 |
+---------------------------------------------------------------*/
'CALLPIPE (NAME ROUND.REXX:57 END ?)',
    'stem input.',                               /* Take these       */
    '| space',                                   /* Remove spaces    */
    '| *:'                                       /* Hand 2 caller    */
 
Exit:
/*---------------------------------------------------------------+
| Exit the code and show a message & rc when needed              |
+---------------------------------------------------------------*/
Parse Arg exrc errmsg
If \Datatype(exrc,'NUM') Then exrc=0
If exrc<>'0' Then Say errmsg
Exit exrc
 
 
RangeType:
/*---------------------------------------------------------------+
| Determine what to do with the ranges                           |
+---------------------------------------------------------------*/
special=0
Select
When Pos(';',range.r)<>0 Then Do
                              Parse Value range.r With fr ';' to .
                              Call SemiColon
                              End
When Pos('.',range.r)<>0 Then Do
                              Parse Value range.r With fr '.' no
                              times=no-1
                              Call PrepSpec
                              Call Change_Records 'input.'
                              End
When Pos('-',range.r)<>0 Then Do
                              Parse Value range.r With fr '-' to .
                              If to='*' Then to=999
                              times=to-fr
                              Call PrepSpec
                              Call Change_Records 'input.'
                              End
Otherwise Call Exit '99 Invalid range: 'range.r
End
Return
 
 
SemiColon:
/*---------------------------------------------------------------+
| .                                                              |
+---------------------------------------------------------------*/
pref.0=0;mid.0=0;suff.0=0
part1=fr-1
If part1<>0  Then part1='W1;'part1
             Else part1=''
If to<>'*' Then part2='W'to+1';*'
           Else part2=''
times=to-fr+1
/*---------------------------------------------------------------+
| Start the separation, into pieces                              |
+---------------------------------------------------------------*/
Call ChopFile 'W'fr';'to' mid.'
If part1<>'' Then Call ChopFile part1' pref.'
If part2<>'' Then Call ChopFile part2' suff.'
/*---------------------------------------------------------------+
| Prep for rounding the mid part of the records                  |
+---------------------------------------------------------------*/
fr=1;to=times
Call PrepSpec
Call Change_Records 'mid.'
/*---------------------------------------------------------------+
| Re-marry the lot, mending the pieces                           |
+---------------------------------------------------------------*/
'CALLPIPE (NAME ROUND.REXX:126 END ?)',
   'stem pref.',                                 /* Take these       */
   '| specs pad 0 recno 1.10 right xFD n w1;* nw',   /* Add recno&marker */
   '| fi: faninany',                             /* Take in others   */
   '| sort w1.1',                                /* Sort on recno+   */
   '| join keylen 10',                           /* Join on recno    */
   '| change xFF ~~',                            /* Remove           */
   '| change xFE ~~',                            /* ...markers       */
   '| change xFD ~~',                            /* .                */
   '| specs 12;* 1',                             /* Remove recno     */
   '| stem input.',                              /* Hand back 2 rexx */
   '?',                                          /* 2nd pipe         */
   'stem mid.',                                  /* Take these       */
   '| specs pad 0 recno 1.10 right xFE n w1;* nw',   /* Add recno&marker */
   '| fi:',                                      /* Conn 2 faninany  */
   '?',                                          /* 3rd pipe         */
   'stem suff.',                                 /* Take these       */
   '| specs pad 0 recno 1.10 right xFF n w1;* nw',   /* Add recno&marker */
   '| fi:'                                       /* Conn 2 faninany  */
Return
 
 
ChopFile:
/*---------------------------------------------------------------+
| Chop records into pieces for later use                         |
+---------------------------------------------------------------*/
Parse Arg spec stemname .
'CALLPIPE (NAME ROUND.REXX:153 END ?)',
    'stem input.',                               /* Take this        */
    '| specs 'spec' 1',                          /* Keep selection   */
    '| stem 'stemname                            /* Store as         */
Return
 
 
PrepSpec:
/*---------------------------------------------------------------+
| Prepare the SPEC statements for later use                      |
+---------------------------------------------------------------*/
'CALLPIPE (NAME ROUND.REXX:164 END ?)',
    'literal W',                                 /* Take this        */
    '| dup 'times,                               /* Dupl n times     */
    '| specs w1.1 1 recno from 'fr' nw ~.1~ nw', /* Add recno        */
    '| specs w2.1 1 w1.1 nw w2.1 n w3.1 n',      /* Reshuffle        */
    '| specs a: w1.1 .',                         /* Subtract 1       */
            'set (#0:=a-1;#1:=a+1)',             /* .   and add 1    */
            'print #0 1',                        /* .                */
            'print #1 nw',                       /* .                */
            'w2;* nw',                           /* .                */
    '| specs ~W1;~ 1',                           /* Compose spec     */
            'w1.1 n',                            /* ...settings      */
            '~1 ! W~ nw',                        /* .                */
            'w2.1 n',                            /* .                */
            '~;* NW !~ n',                       /* .                */
            'w3;* nw',                           /* .                */
    '| stem change.'                             /* Store as         */
Return
 
 
Change_Records:
/*---------------------------------------------------------------+
| Change the record...                                           |
+---------------------------------------------------------------*/
Parse Upper Arg stemname .
Do c=1 To change.0
  Parse Value change.c With part1 '!' part2 '!' changeword
  If part1='W1;0 1' Then part1=''
  'CALLPIPE',
     'stem 'stemname,                            /* Take these       */
     '| buffer',                                 /* Prevent loop     */
     '| if: if pick fs . substr f2 of 'changeword' >= ~5~', /* Make selection   */
     '|        specs 'part1,                     /* Round the nr up  */
                     'a: fs . substr f1 of 'changeword' .', /* .                */
                     'set #0:=a+1',              /* .                */
                     'print #0 nw',              /* .                */
                     part2,                      /* .                */
     '| if:',                                    /* Conn 2 if        */
     '|        specs 'part1,                     /* Round the nr down*/
                     'fs . substr f1 of 'changeword' nw', /* .                */
                     part2,                      /* .                */
     '| if:',                                    /* Conn 2 if        */
     '| stem 'stemname                           /* Store as         */
End c
Return
