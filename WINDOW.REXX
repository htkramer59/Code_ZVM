/*---------------------------------------------------------------+
| Function : Extract records within a window from now            |
|                                                                |
| File     : WINDOW   REXX                                       |
+----------------------------------------------------------------+
| Version  : 0.0.2                                               |
|                                                                |
| Files    : .                                                   |
|                                                                |
| Called   : WINDOW <sep> <date> <time> <format> <window>        |
|                                                                |
|                   <sep>   : field- or word-separator           |
|                             and separator character.           |
|                   <date>  : range where we can find the date.  |
|                   <time>  : range where we can find the time.  |
|                   <format>: dateformat specify dateformats     |
|                             that dateconv allows.              |
|                             Default: RE - Rexx_European        |
|                   <window>: Window to take in minutes.         |
|                             Default: 30 minutes                |
|                                                                |
| Comments : This stage has a primary and secondary output       |
|            SPECS syntax applies for date & time ranges         |
|            Dateformats not included that contain:              |
|                      JAN or JANUARI style months               |
|                                                                |
| Examples : ..| window w1.1 w2.1 iso |...                       |
|            ..| window fs ; f3.1 f9.1 60 |...                   |
|                                                                |
|                                                                |
|                                                                |
| Author   : H.T.Kramer, ,                                       |
| Created  : 20190926 15:08:38                                   |
| Changes  : .                                                   |
|            20190927 H.T.Kramer : Update due to stream error    |
|                            while handing back records.         |
|                                                                |
|                                                                |
|                                                                |
+---------------------------------------------------------------*/
Parse Upper Arg inputline
Parse Source . . myfn myft .
/*---------------------------------------------------------------+
| Main line                                                      |
+---------------------------------------------------------------*/
Call Init
Call Normalise_Input
Call Get_Records
Call Prep_CutOff
Call Filter_Input
Call Return_Records
Exit
 
 
Init:
/*---------------------------------------------------------------+
| Initialise and set some defaults                               |
+---------------------------------------------------------------*/
def_window=30
def_datefmt='RE'
fs=0
ws=0
record.0=0
unmatch.0=0
Return
 
 
Normalise_Input:
/*---------------------------------------------------------------+
| Normalise the inputline and check for fs and/or ws             |
+---------------------------------------------------------------*/
'CALLPIPE (NAME WINDOW.REXX:72 END ?)',
      'var inputline',                          /* Take the input   */
      '| change ~FIELDSEP~FS~',                 /* Reduce these     */
      '| change ~WORDSEP~WS~',                  /* .                */
      '| change ~FIELD~F~',                     /* .                */
      '| change ~WORD~W~',                      /* .                */
      '| split',                                /* Split            */
      '| strip',                                /* ....remove space */
      '| join * x40',                           /* Make 1 line      */
      '| change ~F ~F~',                        /* Replace these    */
      '| change ~W ~W~',                        /* .                */
      '| var inputline',                        /* Hand 2 rexx      */
      '| if1: if pick w1.1 == ~FS~ or w1.1 == ~WS~',  /* Any of thes  */
      '|    specs ~/~ 1 w1.1 n ~/1~ n',         /* Fill w 1         */
      '| if1:',                                 /* Conn 2 if        */
      '|    specs ~/~ 1 w1.1 n ~/0~ n',         /* Fill w 0         */
      '| if1:',                                 /* Conn 2 if        */
      '| varload'                               /* Hand 2 rexx      */
/*---------------------------------------------------------------+
| Is there a Field- or Word-separator and deal with it           |
+---------------------------------------------------------------*/
If fs | ws Then Do
             ranges=Subword(inputline,3)
             fsws=Subword(inputline,1,2)
             End
             Else Do
             ranges=inputline
             fsws=''
             End
/*---------------------------------------------------------------+
| More than 2 words in ranges...adjust some stuff                |
+---------------------------------------------------------------*/
If Words(ranges)>2 Then Do
             rest=SubWord(ranges,3)
             ranges=Subword(ranges,1,2)
             End
/*---------------------------------------------------------------+
| Take ranges                                                    |
+---------------------------------------------------------------*/
Parse Value ranges With daterange timerange .
/*---------------------------------------------------------------+
| Any dateformat ... if not move it to window                    |
+---------------------------------------------------------------*/
Parse Value rest With datefmt window .
If DataType(datefmt,'N') Then Do
             window=datefmt
             datefmt=def_datefmt
             End
/*---------------------------------------------------------------+
| Check if the content of window is valid                        |
+---------------------------------------------------------------*/
'CALLPIPE (NAME WINDOW.REXX:123 END ?)',
      'var window',
      '| locate anyof ~.,;-:~',
      '| count lines',
      '| var wininvalid'
If wininvalid Then Do
              Call Return_Records
              Exit 11
              End
If window='' | window='WINDOW' Then window=def_window
Return
 
 
Get_Records:
/*---------------------------------------------------------------+
| Take in all records from previous stage                        |
+---------------------------------------------------------------*/
'CALLPIPE (NAME WINDOW.REXX:140 END ?)',
     '*:',
     '| stem record.'
Return
 
 
Return_Records:
/*---------------------------------------------------------------+
| Fill both streams...and hand to next in line                   |
+---------------------------------------------------------------*/
Parse Arg stemname
If stemname='' | stemname='STEMNAME' Then stemname='record.'
'STREAMST ALL cnct'                             /* Determine if 2nd */
cnct=Words(cnct)                                /* Output is connctd*/
If record.0<>0 Then 'CALLPIPE (NAME WINDOW.REXX:154 END ?)',
    'stem 'stemname,                            /* Take these       */
    '| *.OUTPUT.0:'                             /* Conn 2 stream 1  */
If unmatch.0<>0 & cnct=2 Then 'CALLPIPE (NAME WINDOW.REXX:157 END ?)',
    'stem unmatch.',                            /* Take these       */
    '| *.OUTPUT.1:'                             /* Conn 2 stream 2  */
Return
 
 
Filter_Input:
/*---------------------------------------------------------------+
| Actual filtering gets done here                                |
+---------------------------------------------------------------*/
'CALLPIPE (NAME WINDOW.REXX:167 END ?)',
    'stem record.',                             /* Take in records  */
    '| buffer',                                 /* Prevent stall    */
    '| v1: verify 'fsws daterange' ~0123456789/-~',     /* Check 4 validity */
    '| v2: verify 'fsws timerange' ~0123456789:~',      /* Check 4 valitity */
    '| specs 'fsws daterange' 1 'timerange' nw 1;* nw', /* Make sortable    */
    '| dateconvert w1.1 'datefmt' RS',          /* Conv 2 rexx_sortd*/
    '| specs w1.1 1 w2;* n',                    /* Join date&time   */
    '| change w1.1 ~:~~',                       /* Remove this      */
    '| sort w1.1 d',                            /* Sort on time     */
    '| p: pick w1.1 >= ~'cutoftime'~',          /* Keep these       */
    '| specs w2;*',                             /* Remove label     */
    '| stem record.',                           /* Hand 2 caller    */
    '? v1:',                                    /* Conn 2 verify    */
    '| fi: faninany',                           /* Take in other    */
    '| stem unmatch.',                          /* Store as         */
    '? v2:',                                    /* Conn 2 verify    */
    '| fi:',                                    /* Conn 2 faninany  */
    '? p:',                                     /* Conn 2 pick      */
    '| specs w2;*',                             /* Remove label     */
    '| fi:'                                     /* Conn 2 faninany  */
Return
 
 
Prep_CutOff:
/*---------------------------------------------------------------+
| Check if window is entered...or set default...and check        |
+---------------------------------------------------------------*/
If window='' Then window=def_window           /* Time in minutes  */
If \Datatype(window,'N') Then Exit 9          /* Invalid window   */
cutof=Time('M')-window                        /* Calculate cutof  */
/*---------------------------------------------------------------+
| If time is below zero we go to previous day                    |
+---------------------------------------------------------------*/
If cutof<0 Then Do
         cutof=cutof+(24*60)                     /* .                */
         cutofd=Date('S',Date('B')-1,'B')        /* .                */
         cutoftime=cutofd||ToTime(cutof)         /* .                */
         End
         Else cutoftime=Date('S')||ToTime(cutof) /* .                */
Return
 
 
ToTime:
/*---------------------------------------------------------------+
| Rework to a usable timestamp                                   |
+---------------------------------------------------------------*/
Parse Arg secs .
hh=Right(secs%60,2,0)                           /* Rework to hours  */
mm=Right(secs//60,2,0)                          /* Rework to minutes*/
ss='00'                                         /* Not important    */
return hh||mm||ss
