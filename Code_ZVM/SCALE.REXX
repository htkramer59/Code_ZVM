/*---------------------------------------------------------------+
| Function : Add a scale to the output....                       |
|                                                                |
| File     : SCALE    REXX                                       |
+----------------------------------------------------------------+
| Version  : 1.1.0                                               |
|                                                                |
| Files    : .                                                   |
|                                                                |
| Called   : SCALE    .                                          |
|                                                                |
| Comments : .                                                   |
|                                                                |
| Author   : H.T.Kramer, ,                                       |
| Created  : 20180705 15:26:12                                   |
| Changes  : .                                                   |
|            20211028 H.T.Kramer : Added offset                  |
|                                                                |
|                                                                |
|                                                                |
+---------------------------------------------------------------*/
Parse Arg offset .
If offset='' Then offset=1
'CALLPIPE (NAME SCALE.REXX:24 END ?)',
'cms QUERY DISPLAY',                     /* QUERY display   */
       '| specs w3.1',                          /* Take this       */
       '| var length'                           /* Store here      */
dup=length/10
'CALLPIPE (NAME SCALE.REXX:28 END ?)',
       'literal ....+....',                     /* Begin scale     */
       '| strip',                               /* Remove space    */
       '| dup 'dup,                              /* Duplicate recs  */
       '| specs 1;* 1 recno n.1',               /* Add count       */
       '| join *',                              /* Make 1 record   */
       '| specs x4F 'offset' 2;* n',            /* Replace 1st char*/
       '| specs 1.'length,                      /* Adjust length   */
       '| var scale'                            /* Show            */
'CALLPIPE (NAME SCALE.REXX:37 END ?)',
       '*:',                                    /* Take recs caller*/
       '| preface var scale',                   /* Add the scale    */
       '| *:'                                   /* Return recs     */
