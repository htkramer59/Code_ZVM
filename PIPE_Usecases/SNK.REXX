/*---------------------------------------------------------------+
| Function : Emulate the CMS PIPELINE SNAKE stage                |
|                                                                |
| File     : SNK      REXX                                       |
+----------------------------------------------------------------+
| Version  : 1.1.0                                               |
|                                                                |
| Files    : .                                                   |
|                                                                |
| Called   : SNK      <columns> <rows>                           |
|                                                                |
|            <columns> between 1 and ......                      |
|            <rows>    empty, between 1 and ...                  |
|                                                                |
| Comments : .                                                   |
|                                                                |
| Author   : H.T.Kramer, ,                                       |
| Created  : 20200813 07:56:10                                   |
| Changes  : .                                                   |
|            20200813 H.T.Kramer : Added 2 subroutines,          |
|                    Simple_Snake & Complex_Snake                |
|                    Added an Exit routine to display errors     |
|                    and messages                                |
|                                                                |
+---------------------------------------------------------------*/
Parse Upper Arg columns rows .
/*---------------------------------------------------------------+
| Check if the input is correct                                  |
+---------------------------------------------------------------*/
If columns='' Then Call Exit '96 Required operand missing'
If Datatype(columns,'NUM')<>1 Then Call Exit '97 Decimal number expected, 'columns' was found'
If columns<1  Then Call Exit '99 Invalid operand 'columns rows
output.0=0                                       /* Initialise stem  */
remove=0                                         /* Init this        */
/*---------------------------------------------------------------+
| Accept all records from our caller                             |
+---------------------------------------------------------------*/
'CALLPIPE (NAME SNK.REXX:39 END ?)',
    '*:',                                        /* Conn 2 caller    */
    '| stem line.'                               /* Store here       */
/*---------------------------------------------------------------+
| Determine some things                                          |
+---------------------------------------------------------------*/
If Strip(columns)//2=1 Then extra=0              /* Determine if we  */
                       Else extra=1              /* .need an extra row */
maxrows=line.0%columns+extra                     /* Determine no of rows */
/*---------------------------------------------------------------+
| .                                                              |
+---------------------------------------------------------------*/
If rows='' Then Call Simple_Snake
           Else Call Complex_Snake
/*---------------------------------------------------------------+
| Return the new records to our caller                           |
+---------------------------------------------------------------*/
'CALLPIPE (NAME SNK.REXX:56 END ?)',
    'stem output.',                              /* Take these       */
    '| *:'                                       /* Conn 2 caller    */
Return
 
 
Exit:
/*---------------------------------------------------------------+
| Universal exit routine                                         |
+---------------------------------------------------------------*/
Parse Arg exrc emsg
If exrc='' | exrc='RC' Then exrc=0
If exrc<>0 Then Say emsg
Exit exrc
 
 
Complex_Snake:
/*---------------------------------------------------------------+
| The real snaky bit...down here                                 |
+---------------------------------------------------------------*/
If Datatype(rows,'NUM')<>1 Then Call Exit '95 Decimal number expected, 'rows' was found'
If rows<1     Then Call Exit '98 Invalid operand 'columns rows
block=columns*rows                               /* Calculate the blocks */
/*---------------------------------------------------------------+
| Add row numbers....in front of the content                     |
+---------------------------------------------------------------*/
Do l=1 To line.0 by rows
   cursor=l
   Do rowcount=1 To rows
      line.cursor=Right(rowcount,3,'0') line.cursor
      cursor=cursor+1
   End rowcount
End l
/*---------------------------------------------------------------+
| Now we do the real snaking                                     |
+---------------------------------------------------------------*/
Do l=1 To line.0 by block
   'CALLPIPE (NAME SNK.REXX:91 END ?)',
       'stem line.',                             /* Take these       */
       '| drop first 'remove,                    /* Forget these     */
       '| take first 'block,                     /* Take this ammount */
       '| sort 1.3',                             /* Sort on column 1 (row count) */
       '| join keylen 3',                        /* Join them        */
       '| specs 5;* 1',                          /* Remove row count */
       '| stem output. append'                   /* Add to stem      */
   remove=remove+block                           /* Increase remove  */
End l
Return
 
 
Simple_Snake:
/*---------------------------------------------------------------+
| Simple snake.....no rows asked                                 |
+---------------------------------------------------------------*/
/*---------------------------------------------------------------+
| Now prepare the column content                                 |
+---------------------------------------------------------------*/
rows=maxrows                                     /* .                */
Do c=1 To columns                                /* .                */
   'CALLPIPE (NAME SNK.REXX:113 END ?)',
       'stem line.',                             /* Take these       */
       '| drop first 'remove,                    /* Drop  a number   */
       '| take first 'rows,                      /* Take next no..   */
       '| stem cell.'c'.'                        /* Store as         */
   remove=remove+rows
End c
/*---------------------------------------------------------------+
| Compose the new output records                                 |
+---------------------------------------------------------------*/
Do c=1 To cell.1.0                               /* Loop thru first column entries   */
   output=''                                     /* Empty this var   */
   Do r=1 To columns                             /* Loop thru the celss */
     If Substr(cell.r.c,1,5)='CELL.' Then cell.r.c=''   /* Check if it has content */
     output=output cell.r.c                      /* Compose new record */
   End r
   'CALLPIPE (NAME SNK.REXX:129 END ?)',
       'var output',                             /* Take this        */
       '| strip',                                /* Remove spaces    */
       '| stem output. append'                   /* Add to stem      */
End c
Return
