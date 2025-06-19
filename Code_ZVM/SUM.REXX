/*---------------------------------------------------------------+
| Function : Sum columns...                                      |
|                                                                |
| File     : SUM      REXX                                       |
+----------------------------------------------------------------+
| Version  : 1.1.0                                               |
|                                                                |
| Files    : .                                                   |
|                                                                |
| Called   : SUM      <word ranges> F <rexx format> APPEND       |
|                                                                |
|            <word ranges>                                       |
|                     w1.1, w2;*, w2.1 w5.1, etc.                |
|                                                                |
|            <rexx format>                                       |
|                     rexx format syntax e.g. 2,2                |
|                                                                |
|            APPEND                                              |
|                     optional, appends sum to output            |
|                                                                |
|                                                                |
| Comments : Assumes all records with the same amount of words   |
|                                                                |
| Author   : H.T.Kramer, ,                                       |
| Created  : 20201105 13:13:02                                   |
| Changes  : .                                                   |
|                                                                |
+---------------------------------------------------------------*/
numeric digits 64                                /* Prevent problems */
Parse Upper Arg inputline
If Wordpos('APPEND',inputline)<>0 Then Do
      preface='| preface stem input.'
      Parse Value inputline With part1 'APPEND' part2
      inputline=part1 part2
      End
      Else preface=''
Parse Value inputline With locs 'F' prepoint','postpoint .
If locs='' Then locs='w1.1'                      /* Default          */
output=''                                        /* Init..           */
/*---------------------------------------------------------------+
| Split the locations, capture the input and get a worcount      |
+---------------------------------------------------------------*/
'CALLPIPE (NAME SUM.REXX:43 END ?)',
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
'CALLPIPE (NAME SUM.REXX:67 END ?)',
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
'CALLPIPE (NAME SUM.REXX:107 END ?)',
       'stem input.',                            /* Take these       */
       '| specs w's'.1 1',                       /* Keep this        */
       '| f: fanout',                            /* Dupl. records    */
       '| specs printonly eof',                  /* Create a total   */
               'a: w1.1     .',                  /* .                */
               'set #0+=a',                      /* .                */
               'eof',                            /* .                */
               'print #0 1',                     /* .                */
       '| strip',                                /* Remove spaces    */
       '| var sum'                               /* Store as         */
If prepoint=''  &,
   postpoint='' Then Nop
                Else Do
                If prepoint=''  Then prepoint=20
                If postpoint='' Then postpoint=0
                sum=Strip(Format(sum,prepoint,postpoint))
                End
output=output' 'sum                              /* Add to this      */
output=Strip(output)
Drop sum                                         /* To prevent dups  */
Return
