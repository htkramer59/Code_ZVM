/*---------------------------------------------------------------+
| Function : Convert a Date(S) and Time() set to a linux since   |
|            epoch timestamp                                     |
|                                                                |
| File     : LNXTS    REXX                                       |
+----------------------------------------------------------------+
| Version  : 1.1.0                                               |
|                                                                |
| Files    : .                                                   |
|                                                                |
| Called   : LNXTS    <range>                                    |
|                                                                |
| Comments : Accepts only wordn.m or wn.m and only 1 range       |
|            Assumes timestamp are yyyyMMdd hh:mm:ss             |
|                                                                |
| Author   : H.T.Kramer, ,                                       |
| Created  : 20220124 16:17:05                                   |
| Changes  : .                                                   |
|                                                                |
+---------------------------------------------------------------*/
Parse Upper Arg range .
Numeric Digits 64
/*---------------------------------------------------------------+
| .                                                              |
+---------------------------------------------------------------*/
'CALLPIPE (NAME LNXTS.REXX:25 END ?)',
   '*:',                                         /* Take records     */
   '| stem input.',                              /* Store as         */
   '?',                                          /* 2nd pipe         */
   'var range',                                  /* Take this        */
   '| change ~WORD~W~',                          /* Replace this     */
   '| specs 2;*',                                /* Keep only n.m    */
   '| var range'                                 /* Hand 2 rexx      */
/*---------------------------------------------------------------+
| Take the selection out of the records                          |
+---------------------------------------------------------------*/
'CALLPIPE (NAME LNXTS.REXX:36 END ?)',
   'stem input.',                                /* Take these       */
   '| specs w'range' 1',                         /* Keep this part   */
   '| stem timestamp.'                           /* Store as         */
/*---------------------------------------------------------------+
| Loop thru all the items                                        |
+---------------------------------------------------------------*/
Do t=1 To timestamp.0
/*---------------------------------------------------------------+
| Calculate the seconds to rexx epoch for the file's timestamp   |
+---------------------------------------------------------------*/
   Parse Value timestamp.t With indate intime .
   date=Date('B',indate,'S')
   Parse Value intime With hh':'mm':'ss .
   file2epoch=(Date('B',indate,'S')*24*3600)+((hh*24)+(mm*60)+ss)
/*---------------------------------------------------------------+
| Get the seconds to Linux epoch                                 |
+---------------------------------------------------------------*/
   Parse Value Time() With hh':'mm':'ss
   sec2epoch=(Date('B','19700101','S')*24*3600)+((hh*24)+(mm*60)+ss)
   linuxts=file2epoch-sec2epoch
/*---------------------------------------------------------------+
| Replace the section in the record(s)                           |
+---------------------------------------------------------------*/
   work=input.t
   'CALLPIPE (NAME LNXTS.REXX:61 END ?)',
       'var work',                               /* Take this        */
       '| change w'range' ~'timestamp.t'~'linuxts'~', /* Replace these    */
       '| var work'                              /* Hand 2 rexx      */
   input.t=work
End t
/*---------------------------------------------------------------+
| Hand back the records to our caller                            |
+---------------------------------------------------------------*/
'CALLPIPE (NAME LNXTS.REXX:70 END ?)',
   'stem input.',                                /* Take these       */
   '| *:'                                        /* Hand them 2 callr*/
Return
