/*---------------------------------------------------------------+
| Function : Mimic the behavior of SFSDIRECT stage               |
|                                                                |
| File     : MDDIRECT REXX                                       |
+----------------------------------------------------------------+
| Version  : 1.1.0                                               |
|                                                                |
| Files    : .                                                   |
|                                                                |
| Called   : MDDIRECT <uid> <mdisk> <option> <strings>           |
|                                                                |
| Comments : .                                                   |
|                                                                |
| Author   : H.T.Kramer, At_home,                                |
| Created  : 20250603 15:55:17                                   |
| Changes  : .                                                   |
|                                                                |
+---------------------------------------------------------------*/
Parse Arg uid mdisk option strings
Upper uid mdisk option
mdisk=Right(mdisk,4,'0')
/*---------------------------------------------------------------+
| Check if uid/mdisk exists and if not already linked            |
+---------------------------------------------------------------*/
linked=0
'CALLPIPE (NAME MDDIRECT.REXX:25 END ?)',
    'cp QUERY MDISK USER 'uid mdisk' DIR LOC',   /* Ask cp           */
    '| drop first 1',                            /* Remove hdr       */
    '| count lines',                             /* How many?        */
    '| var uidok',                               /* Store as boolean */
    '?',                                         /* 2nd pipe         */
    'cp QUERY MDISK USER * 0-FFFF',              /* Ask cp           */
    '| pick w3.1 == ~'uid'~ and',                /* Select these     */
           'w4.1 == ~'mdisk'~',                  /* .                */
    '| specs w2.1 1',                            /* Keep linked cuu  */
    '| strip leading /0/',                       /* Remove zeros     */
    '| var mdisk',                               /* Hand 2 rexx      */
    '| count lines',                             /* How many         */
    '| var linked'                               /* Store as boolean */
If \uidok Then Exit 90
/*---------------------------------------------------------------+
| Check the input parameters                                     |
+---------------------------------------------------------------*/
extra=''
pc='00'x
Select
When option=''          |,
     option='FORMAT'    Then Do
                        option='NOHEADER ISODATE'
                        extra='| specs w1.1 1.8',
                                      'w2.1 nw.8',
                                      '~-~ nw',
                                      'substr 2.1 of w3 n',
                                      'w4;* nw',
                              '| dateconv w8.1 iso usa_short',
                              '| if1: if pick substr 1.1 of w8.1 == ~0~',
                              '|         change substr 1.1 of w8.1 /0/ /',
                              '| if1:',
                              '| if2: if pick substr 1.1 of w9.1 == ~0~',
                              '|         change substr 1.1 of w9.1 /0/ /',
                              '| if2:',
                              '| specs 1;* 1',
                                      '~'uid'~ nw.8',
                                      '~'mdisk'~ nw.4 right'
                        End
When option='NOFORMAT'  Then Do
                        option='NOHEADER ISODATE'
                        extra='| specs xF1000070 1',
                                      'w1.1 n.8',
                                      'w2.1 n.8',
                                      'substr 2.1 of w3 n',
                                      'w4.1 n',
                                      'x0060 n',
                                      'w5.1 d2c n',
                                      'pad 'pc' w6.1 d2c n.8 right',
                                      'substr 2;* of w8.1 44',
                                      'w9.1 n',
                                      '~'uid'~ n.8',
                                      '~'mdisk'~ n.4 right',
                                      'w8.1 93',
                                      'w8.1 n',
                                '| change 44-104 ~-~/~'
                        End
When option='ISODATE'   |,
     option='SHORTDATE' |,
     option='FULLDATE'  Then Do
                        option='NOHEADER 'option
                        extra='| specs 1;* 1 ~'uid'~ nw.8 ~'mdisk'~ nw.5 right'
                        End
When option='STANDARD'  Then Do
                        option='NOHEADER ISODATE'
                        extra='| change w8.1 ~-~~',
                              '| change w9.1 ~:~~',
                              '| change w8.2 ~ ~~',
                              '| specs 1;* 1 ~'uid'~ nw.8 ~'mdisk'~ nw.5 right'
                        End
When option='STRING'    Then Do
                        option='NOHEADER ISODATE'
                        Call Process_Strings
                        End
Otherwise Exit 92
End
/*---------------------------------------------------------------+
| Do we need to LINK/ACCESS the disk?                            |
+---------------------------------------------------------------*/
If \linked Then Call Get_Mdisk
           Else Call Get_Filemode
/*---------------------------------------------------------------+
| Obtain data, adjust it and hand back to caller                 |
+---------------------------------------------------------------*/
'CALLPIPE (NAME MDDIRECT.REXX:106 END ?)',
    'cms LISTFILE * * 'tmode'( 'option,          /* List the files   */
    extra,                                       /* Apply changes    */
    '| *:'                                       /* Return 2 caller  */
/*---------------------------------------------------------------+
| Remove the LINKed disk                                         |
+---------------------------------------------------------------*/
If \linked Then Address CMS 'VMLINK 'uid mdisk' <DET (NONAMES QUIET'
Exit
 
 
Get_Filemode:
/*---------------------------------------------------------------+
| Get the filemode for an already linked MDISK                   |
+---------------------------------------------------------------*/
tmode=''
'CALLPIPE (NAME MDDIRECT.REXX:121 END ?)',
    'cms QUERY ACCESSED',                        /* Ask CMS          */
    '| pick w4.1 == ~'mdisk'~',                  /* Select this one  */
    '| specs 1.1',                               /* Keep filemode    */
    '| var tmode tracking'                       /* Hand 2 rexx      */
Return
 
 
Get_Mdisk:
/*---------------------------------------------------------------+
| Link and access the requested disk                             |
+---------------------------------------------------------------*/
Address CMS 'VMLINK 'uid mdisk' (NONAMES QUIET MODE0 .fm'
If rc=0 Then Parse Pull . . tmode .
        Else Exit rc
Return
 
 
Process_Strings:
/*---------------------------------------------------------------+
| Split the sting into separate items                            |
+---------------------------------------------------------------*/
'CALLPIPE (NAME MDDIRECT.REXX:143 END ?)',
   'var strings',                                /* Take this        */
   '| strip',                                    /* Remove spaces    */
   '| specs 2;-2 1',                             /* Remove separators*/
   '| change ~%%~%~',                            /* Replace this     */
   '| split before string ~%~',                  /* Split here       */
   '| f: fanout',                                /* Dupl. records    */
   '| specs 1.2 1',                              /* Keep this        */
   '| strip',                                    /* Remove spaces    */
   '| stem string.',                             /* Hand 2 rexx      */
   '? f:',                                       /* Conn 2 fanout    */
   '| specs ~/~ 1 3;* n ~/ n~ n',                /* Keep this        */
   '| change ~// n~~',                           /* Remove these     */
   '| stem ext.'                                 /* Hand 2 rexx      */
/*---------------------------------------------------------------+
| Create the additional parts for the SPECS statement            |
+---------------------------------------------------------------*/
Do s=1 To string.0
     Select
     When string.s='%'  Then string.s=string.s||' /%/ n 'ext.s
     When string.s='%Y' Then string.s=string.s||' substr 1.4 of w8.1 n 'ext.s
     When string.s='%y' Then string.s=string.s||' substr 3.2 of w8.1 n 'ext.s
     When string.s='%m' Then string.s=string.s||' substr 6.2 of w8.1 n 'ext.s
     When string.s='%n' Then string.s=string.s||' a: substr 6.2 of w8.1 . set #0:=a-0 print #0 pict --9 n.2 right 'ext.s
     When string.s='%d' Then string.s=string.s||' substr 9.2 of w8.1 n 'ext.s
     When string.s='%e' Then string.s=string.s||' b: substr 9.2 of w8.1 . set #1:=b-0 print #1 pict --9 n.2 right 'ext.s
     When string.s='%H' Then string.s=string.s||' substr 1.2 of w9.1 n 'ext.s
     When string.s='%k' Then string.s=string.s||' c: substr 1.2 of w9.1 . set #2:=c-0 print #2 pict --9 n.2 right 'ext.s
     When string.s='%M' Then string.s=string.s||' substr 3.2 of w9.1 n 'ext.s
     When string.s='%S' Then string.s=string.s||' substr 7.2 of w9.1 n 'ext.s
     When string.s='%F' Then string.s=string.s||' w8.1 n 'ext.s
     When string.s='%T' Then string.s=string.s||' w9.1 n 'ext.s
     When string.s='%t' Then string.s=string.s||' specs /00/ n 'ext.s
     Otherwise Nop
     End
End s
/*---------------------------------------------------------------+
| Create the overall SPECS statement                             |
+---------------------------------------------------------------*/
'CALLPIPE (NAME MDDIRECT.REXX:182 END ?)',
   'stem string.',                               /* Take these       */
   '| specs w2;* 1',                             /* Remove %. items  */
   '| join * x40',                               /* Make 1 record    */
   '| specs x4F 1'.                              /* Compose          */
           '~specs w1.7 1 x40 n~ nw',            /* .new             */
           '1;* nw',                             /* . SPECS          */
           '~/'uid'~ nw.8',                      /* .  statement     */
           '~'mdisk'~ nw.4 right',               /* .                */
           '~/ nw~ nw',                          /* .                */
   '| var extra'                                 /* Hand 2 rexx      */
Return
 
/**
***  Settings copied from PIPE SFSDIRECT ***
%%   A single %.
%Y   Four digits year including century (0000-9999).
%y   Two-digit year of century (00-99).
%m   Two-digit month (01-12).
%n   Two-digit month with initial zero changed to blank (1-12).
%d   Two-digit day of month (01-31).
%e   Two-digit day of month with initial zero changed to blank      ( 1-31).
%H   Hour, 24-hour clock (00-23).
%k   Hour, 24-hour clock first leading zero blank ( 0-23).
%M   Minute (00-59).
%S   Second (00-60).
%F   Equivalent to %Y-%m-%d (the ISO 8601 date format).
%T   Short for %H:%M:%S.
%t   Tens and hundredth of a second (00-99).
**/
