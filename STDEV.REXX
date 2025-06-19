/*---------------------------------------------------------------+
| Function : Calculate standard deviation                        |
|                                                                |
| File     : STDEV    REXX                                       |
+----------------------------------------------------------------+
| Version  : 1.1.0                                               |
|                                                                |
| Files    : .                                                   |
|                                                                |
| Called   : STDEV    <word ranges> F <rexx format> APPEND       |
|                                                                |
|            <word ranges>                                       |
|                     w1.1, w2;*, w2.1 w5.1, etc.                |
|                                                                |
|            <rexx format>                                       |
|                     number of digits before and after decimal  |
|                     point. See REXX FORMAT.                    |
|                     Example: 2,2 or ,3                         |
|                                                                |
|            APPEND                                              |
|                     optional, appends STDEV to output          |
|                                                                |
| Comments : Assumes all records with the same amount of words   |
|                                                                |
| Author   : H.T.Kramer, ,                                       |
| Created  : 20200929 13:13:02                                   |
| Changes  : .                                                   |
|                                                                |
+---------------------------------------------------------------*/
numeric digits 64                                /* Prevent problems */
Parse Upper Arg inputline
If Wordpos('APPEND',inputline)<>0 Then Do
      preface='| preface stem input.'
      Parse Value inputline With part1 'APPEND' part2
      locs=part1 part2
      End
      Else Do
      preface=''
      locs=inputline
      End
Parse Upper Arg locs 'F' prepoint','postpoint .  /* Get arguments    */
If locs='' Then locs='w1.1'                      /* Default          */
output=''                                        /* Init..           */
/*---------------------------------------------------------------+
| Split the locations, capture the input and get a worcount      |
+---------------------------------------------------------------*/
'CALLPIPE (NAME STDEV.REXX:47 END ?)',
     'var locs',                                 /* Take this        */
     '| xlate upper',                            /* Upper case       */
     '| split',                                  /* Split into recs  */
     '| change ~WORD~W~',                        /* Replace these    */
     '| change ~W ~~',                           /* .                */
     '| change ~W~~',                            /* .                */
     '| stem loc.',                              /* Store as         */
     '?',                                        /* 2nd pipe         */
     '*:',                                       /* Take input       */
     '| stem input.',                            /* Store as         */
     '| take 1',                                 /* Take just one    */
     '| count words',                            /* How many words   */
     '| var wordmax'                             /* Store it         */
/*---------------------------------------------------------------+
| Loop thru the locations...                                     |
+---------------------------------------------------------------*/
Do l=1 To loc.0
   If Pos('.',loc.l)<>0 Then Call Point
   If Pos(';',loc.l)<>0 Then Call SemiColon
End l
/*---------------------------------------------------------------+
| Return the findings to the calller...                          |
+---------------------------------------------------------------*/
'CALLPIPE (NAME STDEV.REXX:71 END ?)',
     'var output',
     preface,
     '| *:'
Return
 
 
Point:
/*---------------------------------------------------------------+
| We found a point in the location...this is what we need to do  |
+---------------------------------------------------------------*/
Parse Value loc.l With start'.'fields .
fields=fields-1
Do s=start To start+fields
   Call SelData
End s
Return
 
 
SemiColon:
/*---------------------------------------------------------------+
| We found a semicolon, take this into account and act..         |
+---------------------------------------------------------------*/
Parse Value loc.l With start';'fields .
If Pos('*',fields)<>0 Then fields=wordmax
If Pos('-',fields)<>0 Then Do
           Parse Value fields With '-' fields .
           fields=wordmax-fields+1
           End
Do s=start To fields
   Call SelData
End s
Return
 
 
SelData:
/*---------------------------------------------------------------+
| Select the data out of the input                               |
+---------------------------------------------------------------*/
avg=''
'CALLPIPE (NAME STDEV.REXX:111 END ?)',
     'stem input.',                              /* Take these       */
     '| specs w's'.1 1',                         /* Keep this        */
     '| stem work.',                             /* Intermed. storage*/
     '| f: fanout',                              /* Dupl. records    */
     '| specs printonly eof',                    /* Create a total   */
             'a: w1.1     .',                    /* .                */
             'set #0+=a',                        /* .                */
             'eof',                              /* .                */
             'print #0 1',                       /* .                */
     '| strip',                                  /* Remove spaces    */
     '| var total',                              /* Store as         */
     '? f:',                                     /* Conn 2 fannout   */
     '| count lines',                            /* How many lines   */
     '| var count'                               /* Store as         */
avg=total/count                                  /* Calc. average    */
'CALLPIPE (NAME STDEV.REXX:127 END ?)',
     'stem work.',                               /* Take these       */
     '| specs a: w1.1 .',                        /* Calculate        */
             'set #0:=a-'avg,                    /* ...deviation     */
             'print #0 1',                       /* .                */
     '| specs b: w1.1 .',                        /* Make             */
             'set #1:=b*b',                      /* ...power         */
             'print #1 1',                       /* ....of 2         */
     '| specs printonly eof',                    /* Total            */
             'c: w1.1 .',                        /* .....of          */
             'set #2+=c',                        /* ......the        */
             'eof',                              /* ./......results  */
             'print #2 1',                       /* .                */
     '| var stdev'                               /* Store as         */
stdev=stdev/count                                /* Calc. STDEV      */
If prepoint=''  &,                               /* Format           */
   postpoint='' Then Nop                         /* ...the outcome   */
                Else Do                          /* .                */
                If prepoint=''  Then prepoint=20 /* .                */
                If postpoint='' Then postpoint=0 /* .                */
                stdev=Strip(Format(stdev,prepoint,postpoint))   /* .                */
                End
stdev=sqrt(stdev)
output=Strip(output' 'stdev)                     /* Add to this      */
Drop avg total count stdev work.                 /* To prevent dups  */
Return
