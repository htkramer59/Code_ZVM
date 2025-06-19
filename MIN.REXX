/*---------------------------------------------------------------+
| Function : Get the minimal value out of a column               |
|                                                                |
| File     : MIN      REXX                                       |
+----------------------------------------------------------------+
| Version  : 1.1.0                                               |
|                                                                |
| Files    : .                                                   |
|                                                                |
| Called   : MIN      <word ranges> APPEND                       |
|                                                                |
|            <word ranges>                                       |
|                     w1.1, w2;*, w2.1 w5.1, etc.                |
|                                                                |
|            APPEND                                              |
|                     optional, appends MIN to output            |
|                                                                |
| Comments : Assumes all records with the same amount of words   |
|                                                                |
| Author   : H.T.Kramer, ,                                       |
| Created  : 20200929 12:59:23                                   |
| Changes  : .                                                   |
|                                                                |
+---------------------------------------------------------------*/
Parse Upper Arg inputline                        /* Take arguments   */
If Wordpos('APPEND',inputline)<>0 Then Do
      preface='| preface stem input.'
      Parse Value inputline With part1 'APPEND' part2
      locs=part1 part2
      End
      Else Do
      preface=''
      locs=inputline
      End
/*---------------------------------------------------------------+
| Initialise some values                                         |
+---------------------------------------------------------------*/
If locs='' Then locs='w1.1'                      /* Default          */
output=''                                        /* Init             */
/*---------------------------------------------------------------+
| Split the locations, capture the input and get a worcount      |
+---------------------------------------------------------------*/
'CALLPIPE (NAME MIN.REXX:43 END ?)',
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
'CALLPIPE (NAME MIN.REXX:67 END ?)',
     'var output',
     preface,
     '| *:'
Return
 
 
Point:
/*---------------------------------------------------------------+
| We found a point in the location...this is what we need to do  |
+---------------------------------------------------------------*/
Parse Value loc.l With start'.'fields .
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
'CALLPIPE (NAME MIN.REXX:105 END ?)',
    'stem input.',                               /* Take these       */
    '| specs pad 0 w's'.1 1.30 right',           /* Select this      */
    '| sort w1.1',                               /* Sort             */
    '| take first 1',                            /* Take the lowest  */
    '| strip leading ~0~',                       /* Remove these     */
    '| var work'                                 /* Hand to rexx     */
output=Strip(output' 'work)                      /* Add to this      */
Return
