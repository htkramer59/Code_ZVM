/*---------------------------------------------------------------+
| Function : Convert words from one si-unit to an other.         |
|                                                                |
| File     : SICONV   REXX                                       |
+----------------------------------------------------------------+
| Version  : 1.1.0                                               |
|                                                                |
| Files    : none                                                |
|                                                                |
| Called   : SICONV   <word> <conversion> <picture> <si-unit>    |
|                                                                |
|            <word>       is W<start>.<length>                   |
|            Examples:    word2.1 , w1.1                         |
|                                                                |
|            <conversion> convert from si-unit x to si-unit y    |
|            Examples: M2K, megabyte to kilobyte. G2M, gigabyte  |
|                      to megabyte, etc.                         |
|                                                                |
|            <picture> Optional, defines how many characters are |
|                      before and after the decimal point        |
|            Examples: 10.5, 5.5, 8                              |
|                                                                |
|            <si-unit> Optional, any non-blank character to      |
|                      signal that the si-unit needs to be       |
|                      appended to the new value.                |
|                                                                |
| Examples : ..| siconv w2.1 k2b | ...                           |
|            if w2.1 contains 1 the new content will be 1024     |
|            if w2.1 contains 1k the new content will be 1024    |
|                                                                |
|          : ..| siconv w5.1 m2k 12.2 | ...                      |
|            if w5.1 contains 1345 the new content: 1377280.00   |
|                                                                |
|          : ..| siconv w4.1 k2m 5.2 x | ...                     |
|            if w5.1 contains 1345 the new content: 1.31M        |
|                                                                |
|          : ..| siconv w4.1 k2m w4.1 g2m | ...                  |
|            will convert w4.1 from k & g to m                   |
|                                                                |
|                                                                |
| Comments : If the word contains the si-unit it will be         |
|            stripped automatically                              |
|                                                                |
| Author   : H.T.Kramer, ,                                       |
| Created  : 20200812 12:52:54                                   |
| Changes  : .                                                   |
|            20210809 H.T.Kramer : Removed decimal point when    |
|                   last item in <picture> is 0.                 |
|            20201110 H.T.Kramer : Fixed small problem with      |
|                    converting and made it more strict          |
|            20201014 H.T.Kramer : Added numeric digits          |
|            20200910 H.T.Kramer : Changed some items to         |
|                    anycase to prevent errors                   |
|                                                                |
|                                                                |
+---------------------------------------------------------------*/
/*---------------------------------------------------------------+
| The units we are going to support...                           |
+---------------------------------------------------------------*/
numeric digits 64
B=1    /* Byte(s) */
K=1024 /* Kilo */ ; M=K*K  /* Mega */ ; G=M*K  /* Giga */
T=G*K  /* Tera */ ; P=T*K  /* Peta */ ; E=P*K  /* Exa  */
Z=E*K  /* Zeta */ ; Y=Z*K  /* Yotta*/
units='BKMGTPEZY'                     /* To be able to check the conversions */
defpict='--------------------9.99999' /* Def. picture 20 before dec . and 5 after */
/*---------------------------------------------------------------+
| Getting the input                                              |
+---------------------------------------------------------------*/
Parse Upper Arg argline
/*---------------------------------------------------------------+
| We process the input and the arguments here                    |
+---------------------------------------------------------------*/
'CALLPIPE (NAME SICONV.REXX:74 END ?)',
       '*:',                                    /* Read all records from caller */
       '| buffer',                              /* Prevent stall    */
       '| stem input.',                         /* Store as         */
       '?',                                     /* A 2nd pipe started */
       'var argline',                           /* Take this */
       '| strip',
       '| change anycase ~WORD~W~',             /* Replace this */
       '| split before string ~W~',             /* Split here       */
       '| stem argum.'                          /* Store as array */
/*---------------------------------------------------------------+
| Loop thru the input with 2 words at a time                     |
+---------------------------------------------------------------*/
Do a=1 To argum.0
   Parse Value argum.a With loc cnv pict siunit . /* Split into usable parts */
   Parse Value loc     With 'W'strt'.'len .       /* Split into start and length */
   Parse Value cnv     With fr'2'to .             /* Split into from and to */
   If siunit<>'' Then siunit=to
                 Else siunit=''
/*---------------------------------------------------------------+
| Processing the picture if present                              |
+---------------------------------------------------------------*/
   If pict<>'' Then Do
                    Parse Value pict With predec'.'postdec .
                    pict=Copies('-',predec-1)'9'
                    If postdec<>'' Then pict=pict'.'Copies('9',postdec)
                    End
               Else pict=defpict
/*---------------------------------------------------------------+
| Change the layout...                                           |
+---------------------------------------------------------------*/
   If strt=1 Then rework='w-1;-1 1 ~'siunit'~ n w'strt+len';-2 nw'     /* If it is 1 we need different action */
             Else rework='w1.'strt-1' 1 w-1;-1 nw ~'siunit'~ n w'strt+len';-2 nw'  /* Do some rework  */
   Call Check_Conversion
   Interpret('factor='fr)                       /* We need to multiply by this */
   Interpret('diviso='to)                       /* We need to divide by this */
   If fr='B' Then Do
                  if21=''
                  if22=''
                  End
             Else Do
                  if21='| if2: if pick anycase substr -1;-1 of 'loc' == ~'fr'~'
                  if22='| if2:'
                  End
   'CALLPIPE (NAME SICONV.REXX:118 END ?)',
       'stem input.',                           /* Take this stem */
       '| buffer',                              /* Prevent a loop */
       '| if1: if pick anycase substr -1;-1 of 'loc' \== ~'to'~',
       if21,
       '| change anycase 'loc' ~'fr'~~',        /* Remove the SI sign if present  */
       '| specs 1;* 1',                         /* Take the complete record  */
       '        u: 'loc' .',                    /* Select this column */
       '        set #0:=u*'factor,              /* Start the multiplication */
       '        print #0 picture 'defpict' nw',    /* Add to the end of the record */
       '| specs w1;-2 1',                       /* Take the record minus the last column */
       '        v: w-1;-1 .',                   /* Take the last column/word     */
       '        set #1:=v/'diviso,              /* Divide it */
       '        print #1 picture 'pict' nw',    /* Adjusting layout using picture */
       '| specs 'rework,                        /* Re-align the layout of the records */
       if22,
       '| if1:',
       '| stem input.'                          /* Rewrite the stem */
End a
/*---------------------------------------------------------------+
| Send the changed records to the caller...                      |
+---------------------------------------------------------------*/
If postdec='0' Then removedecdot='| change 'loc' ~.~~'
               Else removedecdot=''
 
'CALLPIPE (NAME SICONV.REXX:143 END ?)',
    'stem input.',                              /* Take the stem    */
    removedecdot,
    '| *:'                                      /* Feed 2 caller    */
Return
 
 
Check_Conversion:
/*---------------------------------------------------------------+
| Check if the conversion is correct...                          |
+---------------------------------------------------------------*/
If fr=to Then Do                                /* They are equal, unneeded      */
               Say cnv 'is invalid'
               Exit 99
               End
If Pos(fr,units)=0 Then Do                      /* From is not valid */
               Say fr 'in 'cnv' is invalid'
               Exit 99
               End
If Pos(to,units)=0 Then Do                      /* To is not valid  */
               Say to 'in 'cnv' is invalid'
               Exit 99
               End
Return
