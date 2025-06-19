/* Process lines from the file, building datastream                  */
/*                                 John Hartmann 4 Jul 1987 11:49:46 */
/*%test: sub qdi                                                     */
 
/*********************************************************************/
/* QDI.REXX (c) Copyright  IBM Danmark ApS 1987,  2010.  Property of */
/* IBM.  An unchanged copy may be distributed freely.                */
/*                                                                   */
/* Refer to QDI.XEDIT for usage instructions.                        */
/*                                                                   */
/* Change activity:                                                  */
/*11 Dec 2010  ... C++ stuff was severely broken.                    */
/*12 Feb 2010  +++ Add C++ style comments for C.                     */
/* 6 Mar 2003  +++ Improve performance.                              */
/*21 Nov 1997  +++ Redo FSM; don't nest strings.                     */
/*19 Nov 1997  +++ Cleanup; better state information.                */
/*30 Apr 1996  +++ Add C comment and parens.                         */
/*********************************************************************/
 
signal on novalue
parse arg,
   cols,       /* testing */          /* Columns on display          */
   lines,                             /* Rows on display             */
   colours,                    /* Colour scheme; see the XEDIT macro */
   hilite,                            /* Extended hiliting to use    */
   ps,                             /* Programmable symbol set to use */
   filetype,                     /* The file type (REXX, C, H, etc.) */
   cline,                             /* Line number of first line   */
   blanklines,             /* Number of blank lines at top of screen */
   startcolumn,                       /* Where to start              */
   .
 
'callpipe var STATE.'cline '1|var startstate'
parse var startstate state cmtnest parennest
address command 'GLOBALV SELECT QDI GET REXXPAREN REXXCONT'
/* Discard blanks and test too                                       */
rexxparen=rexxparen='1'
rexxcont=rexxcont='1'
 
firstcomment=length(colours)-1        /* First colour for comments   */
 
/* Define the FSM to use                                             */
select
   when filetype='PATTERN'
      then call do_pattern
   when find('C CPP C++ H HPP H++', filetype)>0
      then call do_c
   otherwise
      call do_rexx
end
 
hiwater=cols
If blanklines=0
   Then clear=''
   Else clear='284100 2842F4 3c'x || d2c(blanklines*cols, 2) || '00'x
 
data='c0c2'x ||,                      /* Clear and restore           */
   '11'x || d2c(lines*cols-1,2) ||,   /* Go to last position         */
   '13'x ||,                          /* Insert cursor               */
   '1d 60'x ||,                       /* Make a protected field.     */
   clear ||,                          /* Possibly some blank lines   */
   '2841'x || hilite ||,              /* Set hilite                  */
   '2843'x || ps                      /* And program symbols         */
 
signal on error
noctl=xrange('01'x, '3f'x) || 'ff'x
                                                              /*%PAGE*/
/*********************************************************************/
/* Finite state machine to scan a line                               */
/*                                                                   */
/* Inputs are classified and the finite state machine navigated.     */
/*********************************************************************/
 
colour=c.state
col=-1                          /* Force colour at beginning of line */
do lineno=1+blanklines
   hiwater=cols-(lineno=lines)
   'readto line'
   'callpipe (name QDI.REXX:86)',
      '|literal' state cmtnest max(0, parennest),
      '|var STATE.'cline '1'
   cline=cline+1
   position=0                        /* At the beginning of the line */
   encoded=translate(line, encode2, encode1, '1')
   origline=line
   linecolours=''
   startcolour=colour
   do while line\=''                  /* Take parts of the line      */
      prevstate=state                 /* Save state before           */
      /* Any attempt  to skip  "uninteresting" characters  will defy */
      /* the two-character sequence tests.  But  it is safe in state */
      /* 0, and we need some speed.                                  */
      ?=0
      If state=0
         Then
            Do                    /* Take a run of blank and "other" */
               ?=verify(encoded, '01')-1
               If ?=-1
                  Then ?=length(encoded)           /* That's the lot */
            End
      If ?>0                          /* Other indeed                */
         Then
            Do
               parse var line c +(?) line
               encoded=substr(encoded, ?+1)
               a=0                 /* Remain in state and do nothing */
            End
         Else                         /* Character to further test   */
            Do
               parse var line c+1 line
               parse var encoded i+1 encoded
               i=max(i, 1)            /* Treat blank as other        */
               a=substr(a.state, i, 1)
               state=substr(s.state, i, 1)
            End
      newcolour=colour
      If a\=0
         Then interpret 'call ACTION_'a
      linecolours=linecolours || copies(colour, length(c))
      colour=newcolour;
   end
   state=right(s.state, 1)
   If state=0
      Then colour=c.0         /* Otherwise don't take state's colour */
   /* Now generate the data stream for the selected columns          */
   linecolours=substr(linecolours, startcolumn+1, hiwater-(lineno=lines), colour)
   origline=substr(origline, startcolumn+1)
   do while length(linecolours)>0
      lc=left(linecolours, 1)
      If col\=lc
         Then
            Do
               data=data || colour(lc)
               col=lc
            End
      run=verify(linecolours, lc)-1   /* Returns 1-origin            */
      If run=-1                       /* All of it?                  */
         Then run=length(linecolours)
      linecolours=substr(linecolours, run+1)
      parse var origline d +(run) origline
      d=translate(d, , noctl, '"')    /* Be sure not to interfere    */
      ld=length(d)
      Select
         When length(linecolours)>0 | ld=run/* Not last part of line */
            Then nop
         when run<10                  /* Not worth the bother        */
            Then d=left(d, run)       /* Be sure to append blanks    */
         When (d='')                  /* Even if length isn't zero   */
            Then d='3c'x || d2c(lineno*cols-(lineno=lines), 2) || '00'x
         when ld<run-10
            Then d=d || '3c'x || d2c(lineno*cols-(lineno=lines), 2) || '00'x
         Otherwise
            d=left(d, run)
      end
      data=data || d
   end
end
 
error:
'callpipe (name QDI.REXX:86)',
   '|literal' state cmtnest max(0, parennest),
   '|var STATE.'cline '1'
 
If lineno<=lines                      /* Screen not full?            */
   Then data=data || '284100'x ||,    /* turn off hilite             */
            '3c'x || d2c(lines*cols-1, 2) || '00'x          /* clear */
'output' data
exit RC
 
                                                              /*%PAGE*/
/*********************************************************************/
/* Define the  encoding vector  and the  finite state  machine.  The */
/* three routines set up the variables slightly differently.         */
/*                                                                   */
/* Input classes:                                                    */
/* 0   blank (for comment lookahead)                                 */
/* 1   "other"                                                       */
/* 2   single quote                                                  */
/* 3   double quote                                                  */
/* 4   / for comment begin                                           */
/* 5   * for comment end                                             */
/* 6   escape                                                        */
/* 7   left paren                                                    */
/* 8   right paren                                                   */
/* 9   continuation comma                                            */
/* 10  end-of-line                                                   */
/*                                                                   */
/* s. is the state array.  a. is the action array.  c. is the colour */
/* index array.                                                      */
/*                                                                   */
/* Actions:                                                          */
/* 0   none                                                          */
/* 1   Change colour before character                                */
/* 2   Change colour after character                                 */
/* 3   Scan ahead from comma                                         */
/* 4   Process left parenthesis                                      */
/* 5   Process right parenthesis                                     */
/* 6   Process comment begin (slash star) also nested.               */
/* 7   Process comment end (star slash)                              */
/* 8   Process C++ comment (slash slash)                             */
/* 9   Strip leading *s from stuff within a comment.                 */
/*                                                                   */
/* For states, see the individual states below.                      */
/*********************************************************************/
 
do_rexx:
comments_nest=1
encode1='''"/*'
encode2= '2345'
If rexxparen
   Then
      Do
         encode1=encode1'()'
         encode2=encode2'78'
      End
If rexxcont
   Then
      Do
         encode1=encode1','
         encode2=encode2'9'
      End
s.6='6668766666'                      /* Comments nest               */
signal c_actions
 
do_pattern:
comments_nest=1
encode1='''"/*()'
encode2= '234578'
s.6='6668766666'                      /* Comments nest               */
signal c_actions
 
do_c:
comments_nest=0
encode1='''"/*\(){}[]'                /* parens, braces, brackets    */
encode2= '23456787878'
s.6='6666766666'                      /* Comments do not nest        */
 
/*********************************************************************/
/* Declare FSM.  s. is new state a. action c. new colour.            */
/*********************************************************************/
 
c_actions:
encode1=' 'encode1 || xrange()
encode2='0'encode2
 
/* outside strings and comments                                      */
/* I=o'"/.\(),                                                       */
s.0='0135000000'
a.0='011000453'
c.0='1'
 
/* after single quote                                                */
/* I=o'"/.\(),                                                       */
s.1='1011121111'
a.1='020000000'
c.1='2'
 
/* in single quote after escape                                      */
/* I=o'"/.\(),                                                       */
s.2='1111111111'
a.2='000000000'
c.2='2'
 
/* after double quote                                                */
/* I=o'"/.\(),                                                       */
s.3='3303343331'
a.3='002000000'
c.3='3'
 
/* in double quote after escape                                      */
/* I=o'"/.\(),                                                       */
s.4='3333333331'
a.4='000000000'
c.4='3'
 
/* After slash                                                       */
/* I=o'"/.\(),                                                       */
If comments_nest
   Then
      Do
         s.5='0135600000'
         a.5='011060453'              /* // not active               */
      end
   Else
      Do
         s.5='0130600000'
         a.5='011860453'              /* // is active                */
      end
c.5='1'
 
/* After slash star; in such a comment or a nested one               */
/* State and actions depend on whether comments nest                 */
/* I=o'"/.\(),                                                       */
a.6='000000000'
c.6='6'
 
/* In slash star comment after *                                     */
/* I=o'"/.\(),                                                       */
s.7='6666766666'
a.7='000790000'
c.7='6'
 
/* In REXX slash star comment after /                                */
/* I=o'"/.\(),                                                       */
s.8='66666666666'
a.8='000060000'                       /* Nested comment              */
c.8='0'
 
return
                                                              /*%PAGE*/
/*********************************************************************/
/* Action routines.                                                  */
/*********************************************************************/
 
action_1:                             /* change colour now           */
colour=c.state
newcolour=colour
return
 
action_2:
newcolour=c.state
return
 
action_3:                      /* Comma.  Se whether rest is comment */
todox=strip(encoded,, '0')            /* Get rid of blanks           */
xnest=0
do while todox\=''
   parse var todox n2+2 todox
   todox=strip(todox, 'Leading', 0)
   Select
      When n2='45'                    /* begin comment               */
         Then xnest=xnest+1
      When xnest=0                   /* Not begin and not in comment */
         Then return
      When n2\='54'                   /* Not End comment             */
         Then return
      otherwise
         xnest=xnest-1
         If xnest=0
            Then iterate
   end
   parse var todox nbeg '45' +0 br
   parse var todox nend '54' +0 er
   Select
      When nbeg==nend
         Then leave                   /* Unterminated comment        */
      When length(nbeg)<length(nend)  /* Begin nested                */
         Then todox=br
      otherwise                       /* End comment before next     */
         todox=er
   end
end
colour='6'                            /* Make comma blue             */
append=colour(c.0)                    /* And switch back             */
return
 
nest:
xnest=xnest+arg(1)
todox=strip(substr(todox, arg(2)+2))
return
 
action_4:
parennest=parennest+1;
call parencol
return
 
action_5:
call parencol
parennest=parennest-1;
return
 
parencol:
colour=4+parennest//3
return
 
/*********************************************************************/
/* Begin or nest REXX comment.                                       */
/*********************************************************************/
 
action_6:                             /* After slash star            */
call nestcomment
?=verify(encoded, '01236789')         /* Up to next * or /           */
If ?=1
   Then return
call chewdata ?
return
 
chewdata:
If length(encoded)=0
   Then return
If ?=0
   Then ?=length(encoded)
?=?-1                                 /* Up to the last one          */
parse var line ?? +(?) line
c=c || ??
encoded=substr(encoded, ?+1)
return
 
nestcomment:                          /* Back up to before the /     */
cmtnest=cmtnest+1
call cmtcolour 0                      /* Switch before               */
linecolours=overlay(colour, linecolours, length(linecolours))
return
 
/*********************************************************************/
/* End of REXX-style commenet.                                       */
/*********************************************************************/
 
action_7:
cmtnest=cmtnest-1
Select
   When cmtnest>0
      Then call cmtcolour 1           /* Switch after                */
   When cmtnest<0
      Then say 'negative' data '***' line
   otherwise
      state=0
      newcolour=c.state
End
return
 
/*********************************************************************/
/* c++ style line comment //---                                      */
/*********************************************************************/
 
action_8:
call nestcomment                      /* Start the comment           */
cmtnest=0                             /* End it now                  */
c=left(c || line, cols-position)
line=''                               /* Nothing left                */
encoded=''
return
 
/*********************************************************************/
/* Two asterisks in  a comment.  Probably a lot of  them.  Get there */
/* faster.                                                           */
/*********************************************************************/
 
action_9:
?=verify(encoded, '5')
If ?=1
   Then return
call chewdata ?
return
 
cmtcolour:
??=firstcomment+cmtnest//2
If arg(1)=''                          /* After paren                 */
   Then return ??
newcolour=??
If arg(1)='0'
   Then colour=newcolour
return
 
colour:
return '2842'x || substr(colours, arg(1), 1)
 
/*********************************************************************/
/* This part is test cases                                           */
/*********************************************************************/
 
/*
*/
abc, /* a /* nested */ comment */ , /* but */ 0
abc, /* a /* nested */ comment */ /* and nothing */
 
 
a='abc"def"ghi"j*/kl'
a="abc'd/*ef'ghi'j/*kl""xyz'def"
a='abc''def'
c="x\'y"
/* here is an order                                                 */
/* nested /* comment /* even more */ here */ 'ends" */
/* a long comment                                                             */
a line
/* a long comment                                                             */
/*               /*                                                           */                                                                    */
"a"
/**/                                                                                                                                             /**/
"a"
/**/                                                                         /***/                                      /***********/           /***/
"a"
/**                                                                                                                                               **/
"a"
/* a long comment                                                                                                                                 */
abc
/* a long comment                                                                                                                                  */
"abc"
                              /* an even longer comment                                           abcdefghin567y8u9yurty6tyutyut56                  */
"abc"
                               /* an even longer comment                                           abcdefghin567y8u9yurty6tyutyut56                  */
abc
                               /* an even longer comment                                           abcdefghin567y8u9yurty6tyutyut56                  */
'abc', /* cmt                                                                                                                                       */
'def'
'abc', /* cmt   /**/                                                                                                                                */
'def'
'abc'                                                                                                                                           'defghij'
  'xx'
/'abc'
/
'abc'
 
*/
'abc'
*/
/**/
'abc'
/* // */
//* */    / /**/   abc
                                                                                                                                                'abc'
                                                                                                                                                'abcd'
                                                                                                                                                'abcde'
/
* abc
