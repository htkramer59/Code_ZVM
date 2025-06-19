/*==============================================================*/
/*    Program Name - XEDIT Column Editing/VM                    */
/*    Licensed Material - Program Property of IBM               */
/*                                                              */
/*    Copyright              (c) IBM Corp 1991                  */
/*--------------------------------------------------------------*/
/* REXX stage to replace line just read from XEDIT              */
/*--------------------------------------------------------------*/
 
'addpipe (end /) *:'        ,
    '| a: fanout'           ,
    '| spec "COMMAND -1" 1' ,
    '| subcom xedit'        ,
    '/ a:'                  ,
    '| xedit'               ,
    '/ a:'                  ,
    '| *:'
