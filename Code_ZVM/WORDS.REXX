/*---------------------------------------------------------------+
| Function : Show the wordcount in a line before the real        |
|            content                                             |
|                                                                |
| File     : WORDS    REXX                                       |
+----------------------------------------------------------------+
| Version  : 1.1.0                                               |
|                                                                |
| Files    : .                                                   |
|                                                                |
| Called   : WORDS    .                                          |
|                                                                |
| Comments : Note: this is display only...                       |
|                                                                |
| Author   : H.T.Kramer, ,                                       |
| Created  : 20200805 16:00:07                                   |
| Changes  : .                                                   |
|                                                                |
+---------------------------------------------------------------*/
/*---------------------------------------------------------------+
| Define some characters to prevent problems with PIPEs in REXX  |
+---------------------------------------------------------------*/
string_sep='FF'x                                /* Define string separator */
stage_sep='00'x                                 /* Define stage separator  */
end_char='01'x                                  /* Define end character    */
/*---------------------------------------------------------------+
| Start a loop                                                   |
+---------------------------------------------------------------*/
Do main=1
  'READTO WORK'                                 /* Read this into variable work */
  If rc<>0 Then Leave main                      /* If no input...quit   */
  If work='' Then Do
                  'CALLPIPE (stagesep 'stage_sep' end 'end_char')',
                      'literal --- no words ---',  /* Add this         */
                      stage_sep' append var work', /* Add line         */
                      stage_sep' *:'            /* Hand 2 caller    */
                  Iterate
                  End
  'CALLPIPE (stagesep 'stage_sep' end 'end_char')',
      'var work',                               /* Take this...     */
      stage_sep' split',                        /* Split into words */
      stage_sep' f: fanout',                    /* Duplicate records */
      stage_sep' specs recno 1',                /* Add a count to the record */
      stage_sep' strip',                        /* Remove spaces    */
      stage_sep' stem wrdloc.',                 /* Store as (the word count) */
      end_char' f:',                            /* Connect 2 fanout  */
      stage_sep' stem wrd.'                     /* Store as (the words) */
  wrdline=work                                  /* Duplicate the content */
/*---------------------------------------------------------------+
| Start a loop with the words found                              |
+---------------------------------------------------------------*/
  Do w=1 To wrd.0
     repl=Substr(wrdloc.w,1,Length(wrd.w),'.')  /* Compose the replacement string */
    'CALLPIPE (stagesep 'stage_sep' end 'end_char')',
          'var wrdline',                        /* Take this        */
          stage_sep' change w'wrdloc.w'.1 ',    /* Here we change   */
                     string_sep||,              /* ...the words     */
                     wrd.w||,                   /* ....in the record*/
                     string_sep||,              /* ..to             */
                     repl||,                    /* ...the word count*/
                     string_sep' 1',            /* .                */
          stage_sep' var wrdline'               /* Store again as..  */
  End w
  'CALLPIPE (stagesep 'stage_sep' end 'end_char')',
        'var wrdline',                          /* Take this        */
        stage_sep' append var work',            /* Add content      */
        stage_sep' append literal ',            /* Add empty lines  */
        stage_sep' *:'                          /* Feed 2 caller    */
  Drop wrkline repl wrd. wrdloc.                /* Clean these to prevent problems */
End main                                        /* End of the loop  */
Return
