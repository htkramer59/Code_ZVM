/* FTP REXX -- CMS Pipelines FTP client device driver                 */
c = '(c) Copyright International Business Machines Corporation 1997,',
    '2021'
/*--------------------------------------------------------------------*/
/*                                                                    */
/* "ftp" connects to a remote system using the TCP/IP File Transfer   */
/* Protocol (FTP).  Data may be copied between the pipeline and the   */
/* remote system's file system(s).                                    */
/*                                                                    */
/* Examples:                                                          */
/*                                                                    */
/*     PIPE < test file a | rexx ftp userid@host.domain/test.file     */
/*                                                                    */
/*     PIPE rexx ftp userid@host.domain/test.file | > test file a     */
/*                                                                    */
/*     PIPE rexx ftp host.domain | browse                             */
/*                                                                    */
/* For full syntax and usage information, please see the help file.   */
/*                                                                    */
/* Enter:  HELP FTPREXX                                               */
/*                                                                    */
/*--------------------------------------------------------------------*/
/* Original Author:                                                   */
/* Steve Hayes (TSGSH at GFORD1 / tsgsh@vnet.ibm.com)                 */
/* IBM Global Services, Network Services, EMEA SNA I&S                */
/* Additional updates by:                                             */
/* Bruce Hayden (bjhayden@us.ibm.com)                                 */
/* IBM Washington Systems Center                                      */
/* Version: 0.99.09              All updates listed in update file    */
/*--------------------------------------------------------------------*/
call trace trace!()                      /* set trace using GLOBALV   */
signal on novalue                        /* No uninitialised variables*/
signal on failure                        /* no failures allowed       */
signal on error                          /* errors in subroutines     */
parse source . . ftp .
 
Main:
call CheckPlumbing                       /* can't go with lead piping */
call declare                             /* set variables             */
call topology arg(1)                     /* changes for place in pipe */
call parameters arg(1)                   /* read parameters           */
Select                                   /* various syntax forms      */
  when ^commands? then call url          /* must be a url             */
  when url = '' then nop                 /* no initial host           */
  when verify(url, '@/', 'M') = 0 then call host /* just initial host */
  otherwise call url                     /* parse the initial url     */
  end
call AddPlumbing                         /* modify the topology       */
if commands?                             /* command stream?           */
  then do
    if server ^= ''                      /* If we have an initial URL */
      then do                            /* then we logon to it       */
       call Open server, port, tolerant? /* Open the first server     */
        Select                           /* do we do the login?       */
          when ^connected? then nop      /* Initial OPEN failed       */
          when symbol('USERID')   = 'LIT' then nop
          otherwise                      /* Login                     */
            if symbol('PASSWORD') = 'LIT'
              then call Login userid, , account, tolerant?
              else call Login userid, password, account, tolerant?
            do i = 1 to cwd.0 while result
              call Command 'CWD', cwd.i  /* Navigate to the directory */
              end                        /*                           */
          end                            /* Select                    */
        end                              /* then do                   */
     parse value 'A S F' with type mode structure
     end                                 /*                           */
  else do                                /* if commands?              */
    call Open server, port, tolerant?    /* Open the control connect. */
    if symbol('PASSWORD') = 'LIT'        /* we do not know a password */
      then call Login userid, , account  /* logon with prompt         */
      else call Login userid, password, account
    if site ^= '' then call Command 'SITE', site, tolerant?
    try? = type mode structure = ''      /* if none of these options  */
    if try?                              /* go for sensible defaults  */
      then call TryEBCDIC                /* else we had options (only */
      else do                            /* poss. if no secondary in) */
        Select                           /* set type or default       */
          when type = '' then type = 'A'
          when Command('TYPE', type, tolerant?) then nop
          otherwise type = 'A'           /* set failed, revert to     */
          end                            /* default                   */
        Select                           /* set type or default       */
          when mode = '' then mode = 'S'
          when Command('MODE', mode, tolerant?) then nop
          otherwise mode = 'S'           /* set failed, revert to     */
          end                            /* default                   */
        Select                           /* set type or default       */
          when structure = '' then structure = 'F'
          when Command('STRU', structure, tolerant?) then nop
          otherwise structure = 'S'      /* set failed, revert to     */
          end                            /* default                   */
        end                              /* TYPE/MODE/STRUCTURE set   */
    do i = 1 to cwd.0                    /*                           */
      call Command 'CWD', cwd.i          /* Navigate to the directory */
      end                                /*                           */
    end                                  /* Now what to do?           */
/*--------------------------------------------------------------------*/
/* We have navigated to the directory.  First we start with either a  */
/* PORT or PASV command.  For a proxy, we must do PORT first then     */
/* PASV since we are going via the socks server and so we would get   */
/* EADDRINUSE if we used the default port which is the control port.  */
/*--------------------------------------------------------------------*/
call DataStream 1                        /* ensure we've a data stream*/
Select                                   /* Execute request(s)        */
  when commands?                         /* We have many commands     */
    then do                              /* perform them without fuss */
      if responses? then 'EOFREPORT ANY' /* keep an eye on secondary  */
      signal off error                   /* tolerate RC 12            */
      'SELECT BOTH 1'                    /* question                  */
      'PEEKTO record'                    /* Ensure first command      */
      do while RC < 12                   /* While we have a command   */
        Select                           /* EoF on secondary output   */
          when RC = 0 then nop           /* no,                       */
          when ^responses?               /* Don't care about output   */
            then do                      /* EoF                       */
              'EOFREPORT CURRENT'        /* switch off checking       */
              'PEEKTO record'            /* repeek the record         */
              iterate                    /* and go round again        */
              end                        /*                           */
          otherwise                      /* EoF on an output stream   */
            'STREAMSTATE OUTPUT'         /* check secondary           */
            if RC = 12 then leave        /* EoF -- terminate now      */
            if RC = 8 then 'SUSPEND'     /* not waiting for me        */
            'PEEKTO record'              /* try again                 */
            if RC ^= 0 then leave        /* PEEKTO changed 1.0110x11  */
          end                            /* no EoF, continue          */
        parse var record cmd parameters  /* get the command           */
        Select                           /* What to do with it        */
          when record = '' then nop      /* Null command              */
          when wordpos(translate(cmd), FTPCOMMANDS USERCOMMANDS) > 0
            then call Command cmd, parameters, tolerant?
          otherwise
            say "Unrecognised command:" record
            RC = 8
            signal TheEnd
          end                            /*                           */
        'SELECT BOTH 1'                  /* get correct stream again  */
        'READTO'                         /* consume input record      */
        'PEEKTO record'                  /* next record               */
        end                              /* EoF                       */
      end                                /*                           */
  /*------------------------------------------------------------------*/
  /* We don't have the command stream so issue one command only       */
  /*------------------------------------------------------------------*/
  when action = 'NLST' & file = '' then call Command 'NLST'
  when action = 'NLST'             then call Command 'NLST', file
  when action = 'LIST' & file = '' then call Command 'LIST'
  when action = 'LIST'             then call Command 'LIST', file
  when action = ''     & file = '' then call Command 'NLST'
  otherwise                              /* might be a file           */
    file? = 0                            /* assume not for the moment */
    if action = '' & first?              /* in this case, we can..    */
      then if Command('CWD', file, 1)    /* try CWD                   */
        then call Command 'NLST'         /* and if OK, NLST it        */
        else file? = 1                   /* can't be NLST it's a file */
      else file? = 1                     /* it must be a file         */
    Select                               /* other defaults to try     */
      when ^file? then nop               /* don't try anything else   */
      when ^try?  then nop               /* something explicit, keep  */
      when TryRecord() then nop          /* try record first and if   */
      otherwise call TryBlock            /* it fails, try block       */
      end                                /*                           */
    Select                               /*                           */
      when ^file? then nop               /* don't try anything else   */
      when action = '>'  then call Command 'STOR', file
      when action = '>>' then call Command 'APPE', file
      when action = '<'  then call Command 'RETR', file
      otherwise /* '' */
       if first?
         then call Command 'RETR', file
         else call Command 'STOR', file
      end
  end
RC = 0
 
/*--------------------------------------------------------------------*/
/* Single end point, tell the remote server we're done and then close */
/* both ends of our data and control streams                          */
/*--------------------------------------------------------------------*/
TheEnd:
eRC = RC * (RC ^= 12 & RC ^= 8 & RC ^= 4 & RC ^= 221)
signal off error
signal off failure
'STREAMSTATE OUTPUT ctl'
Select
  when RC = 12 then nop
  when RC ^= 0 then call CloseControl
  otherwise
    tolerant? = 1
    call Command 'QUIT'
    if RC ^= 221 then call CloseControl
  end
call Datastream 0
Exit eRC
 
/*--------------------------------------------------------------------*/
/* Initialise global variables to defaults                            */
/*--------------------------------------------------------------------*/
declare:
variables  = 'ftp server address port controlport dataport userid',
             'password account type mode structure url file site action',
             'timeout tcpip ascii ebcdic a2e e2a socksuser socksserver',
             'socksaddress socksport proxyuser proxypass proxyserver',
             'proxyaddress proxyport pasv? accept? socks? socksconfig?',
             'proxy? external? echo? first? commands? responses?',
             'tolerant? anydataport? markers? connected? cwd. use?.',
             'response. FTPCOMMANDS USERCOMMANDS epsv? passvar ndigits'
server          = ''
address         = ''
port            = 21
controlport      = 0
dataport        = 0
userid          = ''
password        = ''
passvar         = ''
account         = ''
type            = ''
mode            = ''
structure       = ''
url             = ''
file            = ''
site            = ''
proxy           = ''
ndigits         = 14
timeout         = 30
tcpip           = 'TCPIP'
ebcdic          = 1047
ascii           = 819
'CALLPIPE (end \) xrange|xlate from 1047 to 819|var a2e',
               '\ xrange|xlate from 819 to 1047|var e2a'
anydataport?    = 0
pasv?           = 0
epsv?           = 0
accept?         = 0
external?       = 0
echo?           = 0
first?          = 0
commands?       = 0
responses?      = 0 /* NB. c.f. response? which is not global */
tolerant?       = 0 /* NB. c.f. tolerate? which is not global */
markers?        = 0
socks?          = translate(value('SOCKS_FLAG', ,'GLOBAL SOCKS') = 'ON')
socksconfig?    = stream('SOCKS CONFIG *', 'c', 'query exists') ^= ''
connected?      = 0
socksuser       = word(value('SOCKS_USER', ,'GLOBAL SOCKS') userid(), 1)
socksserver     = value('SOCKS_SERVER', ,'GLOBAL SOCKS')
socksaddress    = value('SOCKS_SERVER', ,'GLOBAL SOCKS')
socksport       = 1080
proxy?          = 0
proxyserver     = ''
proxyaddress    = ''
proxyport       = 21
proxyuser       = word(value('PROXY_USER', ,'GLOBAL PROXY') userid(), 1)
proxypass       = ''
cwd.0           = 0
use?.           = 1
response.0      = 0
FTPCOMMANDS     = 'USER PASS ACCT CWD CDUP SMNT QUIT REIN PORT PASV',
                  'TYPE STRU MODE RETR STOR STOU APPE ALLO REST RNFR',
                  'RNTO ABOR DELE RMD MKD PWD LIST NLST SITE SYST STAT',
                  'HELP EPSV NOOP'
USERCOMMANDS    = 'OPEN CLOSE EXIT LOGIN PORT PASV EPSV PROXY CODEPAGES'
return
 
/*--------------------------------------------------------------------*/
/* Variables dependent on plumbing topology                           */
/*--------------------------------------------------------------------*/
topology: procedure expose (variables)
signal off error
'MAXSTREAM INPUT'                        /* Check only one stream     */
Select
  when RC > 2 then call PipeErrorMsg 264 /* too many streams: crash   */
  when RC > 0
    then do
      if RC = 2 then markers? = 1
      'STREAMSTATE INPUT 1'
      commands? = (RC ^= 12)
      'STREAMSTATE OUTPUT 1'
      responses? = (RC ^= 12)
      end
  when arg(1) = '' then call PipeErrorMsg 11 /* no parameters nor 2y  */
  otherwise
  end
'STAGENUM'                               /* Are we first?             */
first? = (RC = 1)                        /* Our behaviour varies      */
tolerant? = responses?                   /* default behaviour         */
return
 
/*--------------------------------------------------------------------*/
/* Parameters: parse the parameters passed and set variables          */
/*--------------------------------------------------------------------*/
parameters: procedure expose ftp (variables)
signal on error name TheEnd
arg action .                             /* </>/>>/LIST/NLST          */
parse arg . url opts                     /*   then url options        */
Select                                   /* Select action             */
  when action = '' & commands? then nop  /* don't need action here    */
  when action = '' then call PipeErrorMsg 11
  when action = 'NLST' & ^first?         /* NLST command must be 1st  */
    then call PipeErrorMsg 87            /* if not then error         */
  when action = 'LIST' & ^first?         /* LIST command must be 1st  */
    then call PipeErrorMsg 87            /* if not then error         */
  when action = '<' & ^first?            /* RETR command must be 1st  */
    then call PipeErrorMsg 87            /* if not then error         */
  when action = '>' & first?             /* STOR command can't be 1st */
    then call PipeErrorMsg 127           /* if so then error          */
  when action = '>>' & first?            /* APPE command can't be 1st */
    then call PipeErrorMsg 127           /* if so then error          */
  when wordpos(action, '< > >> LIST NLST') > 0 then nop
  otherwise                              /* not </>/>>                */
    action = ''                          /* decide after reading URL  */
    parse arg url opts                   /* re-parse arguments        */
  end                                    /* action is chosen & valid  */
if action ^= '' & commands?              /* When secondary input is   */
  then call PipeErrorMsg 111, , action   /* connected, no <, >, >>    */
do while opts ^= ''                      /* other options, process    */
  parse var opts keyword opts            /* keyword or keyword plus   */
  keyword = translate(keyword)           /* case insensitive          */
  Select                                 /* dstring                   */
    when abbrev('QUIET', keyword, 5)     /* QUIET                     */
      then echo? = 0                     /*   set flag                */
    when abbrev('NOISY', keyword, 5)     /* NOISY                     */
      then echo? = 1                     /*   set flag                */
    when abbrev('TOLERANT', keyword, 3)  /* TOLerant                  */
      then tolerant? = 1                 /*   set flag                */
    when abbrev('INTOLERANT', keyword, 5) /* INTOLerant               */
      then tolerant? = 0                 /*   set flag                */
    when abbrev('ASCII', keyword, 3) & ^commands?
      then type = 'A'                    /*   set type                */
    when abbrev('EBCDIC', keyword, 3) & ^commands?
      then type = 'E'                    /*   set type                */
    when (abbrev('BINARY', keyword, 3) | abbrev('IMAGE', keyword, 3)),
         & ^commands?
      then type = 'I'                    /*   set type                */
    when abbrev('BLOCK', keyword, 3) & ^commands?
      then mode = 'B'                    /*   set mode                */
    when abbrev('STREAM', keyword, 3) & ^commands?
      then mode = 'S'                    /*   set mode                */
    when abbrev('FILE', keyword, 3) & ^commands?
      then structure = 'F'               /*   set structure           */
    when abbrev('RECORD', keyword, 3) & ^commands?
      then structure = 'R'               /*   set structure           */
    when abbrev('PASSIVE', keyword, 6)   /* PASV for preference       */
      then pasv? = 1                     /*   set flag                */
    when abbrev('EPASSIVE', keyword, 6)  /* EPSV for preference       */
      then epsv? = 1                     /*   set flag                */
    when abbrev('ANYDATAPORT', keyword, 7) /* For BC's FTP daemon     */
      then anydataport? = 1              /*   set flag                */
    when abbrev('TIMEOUT', keyword, 7)   /* Timeout option            */
      then do                            /*    save timeout value     */
        if opts = '' then call PipeErrorMsg 156
        parse var opts timeout opts
        if verify(timeout, '0123456789') > 0
          then call PipeErrorMsg 58, , timeout
        end                              /*                           */
    when abbrev('USERID', keyword, 4)    /* USERid option             */
      then do
        if opts = '' then call PipeErrorMsg 156
         parse upper var opts tcpip .    /*    save TCPIP value       */
         parse var opts . opts           /*    remove from options    */
        end                              /*                           */
    when abbrev('PROXY', keyword, 5)     /* PROXY parameter           */
      then do                            /*                           */
        if opts = '' then call PipeErrorMsg 156
        parse var opts proxyurl opts     /* remove url                */
        call proxy proxyurl              /* get proxy details         */
        end                              /*                           */
    when abbrev('CODEPAGES', keyword, 5) /* Codepage or two           */
      then do                            /*                           */
        if opts = '' then call PipeErrorMsg 156
        parse var opts ebcdic opts       /* remove EBCDIC codepage    */
        if ^datatype(ebcdic, 'W')        /* test it                   */
          then call PipeErrorMsg 58, , ebcdic /* next ASCII codepage  */
        if datatype(word(opts, 1), 'W')
          then parse var opts ascii opts
          else ascii = ''
        call codepages ebcdic ascii
        end                              /*                           */
    when abbrev('A2ETABLE', keyword, 3)
      then do                            /* remove dstring            */
        if opts = '' then call PipeErrorMsg 156
        parse value dstring(opts) with a2e ' ' opts
        a2e = left(x2c(a2e), 256, '00'x) /* convert to xlate table    */
        parse value '' with ebcdic ascii /* don't use these           */
        end                              /*                           */
    when abbrev('E2ATABLE', keyword, 3)
      then do                            /* remove dstring            */
        if opts = '' then call PipeErrorMsg 156
        parse value dstring(opts) with e2a ' ' opts
        e2a = left(x2c(e2a), 256, '00'x) /* convert to xlate table    */
        parse value '' with ebcdic ascii /* don't use these           */
        end                              /*                           */
    when abbrev('SITE', keyword, 4) & ^commands?
      then do                            /* remove dstring            */
        if opts = '' then call PipeErrorMsg 156
        parse value dstring(opts) with site ' ' opts
        site = x2c(site)                 /* convert back to character */
        end                              /*                           */
    when abbrev('PASSWORDVAR', keyword, 9) /* Password in Rexx var    */
      then do
        if opts = '' then call PipeErrorMsg 156
        parse var opts passvar opts      /* remove variable name      */
        If symbol(passvar)='BAD' then call PipeErrorMsg 235, , passvar
        signal off error
        'CALLPIPE (name' ftp':PassVar end \)',
                 'var passvar',        /* contains variable to fetch*/
              '|a:varfetch 1 nomsg233',
              '|  var passvar',        /* Get value or drop if none */
              '\a:',
              '|  hole'
        If RC=233 | symbol('passvar')='LIT' then passvar=''
        signal on error
        end
    otherwise call PipeErrorMsg 111, , keyword
    end                                  /* unrecognised keyword!     */
  end                                    /*                           */
return
 
/*--------------------------------------------------------------------*/
/* Interpret the host parameter                                       */
/*--------------------------------------------------------------------*/
host: procedure expose (variables)
if pos(':', url) > 0
  then do
    parse var url server ':' port
    Select
      when port = '' then port = 21
      when verify(port, '0123456789') = 0 & port ^> 65535 & port ^< 1
        then nop
      otherwise call BadURL "invalid port number"
      end
    end
  else server = url
url = ''
drop userid password account
return
 
/*--------------------------------------------------------------------*/
/* Interpret the URL to get initial sequence of commands              */
/* URLDEBLOCK is used strangely... we must split at slashes to get    */
/* CWD commands but we can't do this after urldeblock because then we */
/* would split at encoded slashes and that's important in principle   */
/* since it is possible we are not authorised for some intermediate   */
/* directories and multiple CWDs might fail where one succeeds.       */
/*--------------------------------------------------------------------*/
url: procedure expose (variables)
parse var url scheme '//' local
if local = '' then parse value 'FTP:' url with scheme local
if translate(scheme) ^= 'FTP:'
  then call BadURL "invalid URL scheme '"scheme"'"
parse var local login '/' file
if pos('@', login) = 0
  then parse value 'anonymous' login with login server
  else parse var login login '@' server
if server = '' then call BadURL "no host specified"
parse var login userid ':' password
parse var server server ':' port
if port = '' then port = 21
if verify(port, '0123456789') > 0 | port > 65535 | port < 1
  then call BadURL "invalid port number"
call xlatestages 1
'CALLPIPE (name' ftp':DecodeURL end \ listerr)',
      '| var userid'                , /* input stream has four lines  */
      '| append var password'       , /* for userid and password      */
      '| append var server'         , /* host and file                */
      '| append var file'           , /* non-encoded plus to blank    */
      '| change /&/%26/'            , /* Encode chars that the        */
      '| change /+/%2b/'            , /*   urldeblock stage would     */
      '| change /;/%3b/'            , /*   notice so they pass thru   */
      '| split before /'            , /* get each cwd and a file.     */
      '| strip leading /'           , /* this combo allows trailing / */
         xlate2a                    , /* convert to ASCII             */
      '| urldeblock'                , /* decode each separate bit     */
         xlata2e                    , /* convert to EBCDIC            */
      '| var userid'                , /* save first record            */
      '| drop 1'                    , /* don't need any more          */
      '| var password'              , /* save second record           */
      '| drop 1'                    , /* don't need any more          */
      '| var server'                , /* save third record            */
      '| drop 1'                    , /* don't need any more          */
      '| t: take last 1'            , /* separate path and file       */
      '| c: chop before ;'          , /* just the file name           */
      '| var file'                  , /* save filename                */
      '\ c:'                        , /* ;type=X                      */
      '| var typeparm'              , /* save first record            */
      '| xlate upper'               , /* save filename                */
      '| strip leading string ";TYPE="', /* remove parameter          */
      '| var typecode'              , /* save first record            */
      '\ t:'                        , /* path here                    */
      '| split before %',
      '| x: strfind /%/',
      '| y: verify anycase 2-3 /0123456789ABCDEF/',
      '| specs 2-3 x2c 1 4-* n',
      '| xlate 1 a2e',
      '| xlate 1 to 037',
      '| z: faninany',
      '| stem cwd.',                /* Save CWD commands              */
      '\ x:',
      '| z:',
      '\ y:',
      '| z:',
         table2a,                     /* input translate tables to    */
         tabla2e                      /* xlate if needed              */
 
/*--------------------------------------------------------------------*/
/* Sort out remaining defaults                                        */
/*--------------------------------------------------------------------*/
Select
  when pos(':', login) > 0  then nop
  when passvar <> '' then password = passvar
  when userid = 'anonymous' then password = email()
  otherwise drop password
  end
Select
  when translate(left(typeparm, 6)) ^= ';TYPE=' & typeparm ^= ''
    then call BadURL "invalid parameter '"typeparm"'"
  when typecode ^= '' & commands?
    then call BadURL "do not specify URL type when secondary",
                     "input stream is connected"
  when typecode  = 'A' then type = 'A'
  when typecode  = 'I' then type = 'I'
  when typecode  = 'E' then type = 'E'
  when typecode  = 'D'
    then if action = '<' | action = ''
      then action = 'NLST'
      else
        call BadURL "invalid transfer type '"typecode"' for '"action"'"
  when typecode ^= ''
    then call BadURL "invalid transfer type '"typecode"'"
  otherwise
  end
Select
  when commands? then nop
  when action ^= ''
    then if file = '' & action ^= 'NLST' & action ^= 'LIST'
      then call BadURL "no file specified for '"action"'"
  when ^first? then action = '>'
  when typecode = 'A' | typecode = 'I' then action = '<'
  when typecode = 'D' then action = 'NLST'
  otherwise /* leave undecided a little longer */
  end
if (commands? | action = 'D') & file ^= ''
  then do
    temp = cwd.0+1
    cwd.temp = file
    cwd.0 = temp
    file = ''
    end
return
 
/*--------------------------------------------------------------------*/
/* Interpret the proxy URL to get where we must logon                 */
/*--------------------------------------------------------------------*/
proxy: procedure expose (variables)
parse arg proxyurl, tolerate?
if ^arg(2, 'E') then tolerate? = 0
proxy? = 0 /* for now */
if proxyurl ^= ''
  then do
    'CALLPIPE (name' ftp':ProxyURL end \)',
             'var proxyurl',
           '| urldeblock',
           '| var proxyurl'
    if RC = 0
      then do
        parse var proxyurl scheme '//' proxylogin
        if proxylogin = ''
          then parse value 'FTP:' proxyurl with scheme proxylogin
        Select
          when translate(scheme) ^= 'FTP:'
            then call BadURL "invalid URL scheme '"scheme"'", tolerate?
          when pos('/', proxylogin) > 0
            then call BadURL "path specified for FTP Proxy URL",tolerate?
          otherwise
            if pos('@', proxylogin) = 0
              then parse value 'anonymous' proxylogin with,
                 proxylogin proxyserver
              else parse var proxylogin proxylogin '@' proxyserver
            if proxyserver = ''
              then call BadURL "no proxy specified", tolerate?
              else do
                parse var proxylogin proxyuser ':' proxypass
                parse var proxyserver proxyserver ':' proxyport
                if proxyport = '' then proxyport = 21
                Select
                  when pos(':', proxylogin) > 0  then nop
                  when proxyuser = 'anonymous' then proxypass = email()
                  otherwise drop proxypass
                  end
                proxy? = 1 /* at last ! */
                end
          end
      end
    end
return
 
BadUrl:
'MESSAGE SJHFTP0001E' arg(1)
RC = 8
if arg(2) = 1
  then return
  else Signal TheEnd
 
/*--------------------------------------------------------------------*/
/* Check the code pages specified                                     */
/*--------------------------------------------------------------------*/
codepages: procedure expose (variables)
parse arg e a, tolerate?
if ^arg(2, 'E') then tolerate? = 0
if e = '' then e = 1047
if a = '' then a = 819
if ^tolerate? then signal on error name TheEnd
'CALLPIPE (nomsg 15) literal|xlate from' e 'to' a /* test it !  */
if RC = 0 then parse value e a with ebcdic ascii a2e e2a
return
 
/*--------------------------------------------------------------------*/
/* Add extra plumbing                                                 */
/*                                                                    */
/* Process the data according to whether we are reading or writing    */
/* We have a post or pre-processor which handles the type, mode and   */
/* structure for each file transferred.  It operates using callpipe.  */
/* The control pipe is created with ADDPIPE and endures for each      */
/* OPEN.  A data pipe is added whenever it is needed it is dropped    */
/* whenever a PASV or PORT command is issued.  These are issued       */
/* implicitly whenever a command which must transfer data is to be    */
/* run.                                                               */
/*                                                                    */
/* <                                >/>>                              */
/*                                                                    */
/*  tcplisten<ƒƒƒƒƒƒƒƒƒø            tcplisten<ƒƒƒƒƒƒƒƒƒø              */
/*  ≥                  ≥             ≥                 ≥              */
/*  ‰ƒtcpdata(data)    ≥            è‰ƒtcpdata(data)<ƒƒƒƒƒø           */
/*  ≥  ≥               ≥            è≥                 ≥  ≥           */
/*  ≥  ≥  ⁄ƒƒƒƒƒƒƒƒƒø  ≥            è≥     ⁄ƒƒƒƒƒƒƒƒƒø ≥  ≥           */
/*  ≥  ≥  ≥   FTP   ≥  ≥            è≥    è≥   FTP   ≥ ≥  ≥           */
/*  ≥  ≥  ≥         ≥  ≥            è≥     ≥         ≥ ≥  ≥           */
/*  ≥  ≥  0 ⁄ƒpostƒƒ0ƒƒƒƒ>          è≥  >ƒƒ0ƒƒpreƒƒø 0 ≥  ≥           */
/*  ≥  ≥  ≥ ≥       ≥  ≥            è≥     ≥       ≥ ≥ ≥  ≥           */
/*  ≥  ¿ƒƒdata   data  ≥            è≥     data   dataƒƒƒƒŸ           */
/*  ≥     ≥         ≥  ≥            è≥    è≥        è≥ ≥              */
/*  ¿ƒƒƒƒ>port   portƒƒŸ            è¿ƒƒƒƒ>port   portƒŸ              */
/*        ≥         ≥                     è≥        è≥                */
/*  cmdsƒ>1ƒƒƒøechoƒ1ƒƒƒƒ>           cmdsƒ>1ƒƒƒøechoƒ1ƒƒƒƒ>           */
/*        ≥ ⁄ƒ≥ƒŸ   ≥                     è≥ ⁄ƒ≥ƒŸ  è≥                */
/*  ⁄ƒƒƒƒ>ctl ¿ƒƒ>ctlƒƒƒƒƒø          ⁄ƒƒƒƒ>ctl ¿ƒƒ>ctlƒƒƒƒƒø          */
/*  ≥     ≥         ≥     ≥          ≥     ≥        è≥    è≥          */
/*  ≥     ¿ƒƒƒƒƒƒƒƒƒŸ     ≥          ≥    è¿ƒƒƒƒƒƒƒƒƒŸ    è≥          */
/*  ¿ƒƒƒƒƒƒtcpclientƒƒƒƒƒƒŸ          ¿ƒƒƒƒƒƒtcpclientƒƒƒƒƒƒŸ          */
/*         (control)                        (control)                 */
/*                                                                    */
/* Passive variant                                                    */
/*                                                                    */
/* <                                >/>>                              */
/*                                                                    */
/*  tcpclient(data)                 ètcpclient(data)<ƒƒƒƒƒø           */
/*     ≥                            è                     ≥           */
/*     ≥  ⁄ƒƒƒƒƒƒƒƒƒø               è      ⁄ƒƒƒƒƒƒƒƒƒø    ≥           */
/*     ≥  ≥   FTP   ≥               è     è≥   FTP   ≥    ≥           */
/*     ≥  ≥         ≥               è      ≥         ≥    ≥           */
/*     ≥  0 ⁄ƒpostƒƒ0ƒƒƒƒ>          è   >ƒƒ0ƒƒpreƒƒø 0    ≥           */
/*     ≥  ≥ ≥       ≥               è      ≥       ≥ ≥    ≥           */
/*     ¿ƒƒdata   data               è      data   dataƒƒƒƒŸ           */
/*        ≥         ≥                     è≥        è≥                */
/*  cmdsƒ>1ƒƒƒøechoƒ1ƒƒƒƒ>           cmdsƒ>1ƒƒƒøechoƒ1ƒƒƒƒ>           */
/*        ≥ ⁄ƒ≥ƒŸ   ≥                     è≥ ⁄ƒ≥ƒŸ  è≥                */
/*  ⁄ƒƒƒƒ>ctl ¿ƒƒ>ctlƒƒƒƒƒø          ⁄ƒƒƒƒ>ctl ¿ƒƒ>ctlƒƒƒƒƒø          */
/*  ≥     ≥         ≥     ≥          ≥     ≥        è≥    è≥          */
/*  ≥  ⁄ƒ>sox     soxƒƒø  ≥          ≥ è⁄ƒ>sox     soxƒƒø è≥          */
/*  ≥  ≥  ¿ƒƒƒƒƒƒƒƒƒŸ  ≥  ≥          ≥  ≥ è¿ƒƒƒƒƒƒƒƒƒŸ  ≥ è≥          */
/*  ≥  ¿ƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒŸ  ≥          ≥ è¿ƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒŸ è≥          */
/*  ≥                     ≥          ≥ è                  è≥          */
/*  ¿ƒƒƒƒƒƒtcpclientƒƒƒƒƒƒŸ          ¿ƒƒƒƒƒƒtcpclientƒƒƒƒƒƒŸ          */
/*         (control)                        (control)                 */
/*                                                                    */
/* The port output stream is use to pass the sockaddr_in structure to */
/* the added pipe to verify the givesocket() record from tcplisten    */
/* The tertiary marker stream may also exist                          */
/*--------------------------------------------------------------------*/
AddPlumbing:
signal off error
if ^commands? & ^responses?
  then do
    'ADDSTREAM BOTH'      /* Add secondary for echo    */
    'ADDPIPE (name' ftp':out.1 end \ listerr) *.out.1:|hole'
    end
if markers?
  then 'ADDPIPE (name' ftp':Markers end \ listerr)',
               '*.out.2:',
            '|o:fanout',
            '|  hole',
            '\o:',
            '|  *.out.2:'
'ADDSTREAM BOTH ctl'                     /* FTP control (Telnet)      */
'ADDSTREAM BOTH data'                    /* FTP data                  */
'ADDSTREAM BOTH port'                    /* for local port info       */
if socks? & socksconfig?                 /* If the global socks_flag  */
  then do                                /* is on & we have a config  */
    'ADDSTREAM BOTH sox'                 /* versatile socks support   */
    'ADDPIPE (name' ftp':sockscfg end \ listerr)',
            '*.out.sox:',
          '| sockscfg',
          '| *.in.sox:'
    end
return
 
/*--------------------------------------------------------------------*/
/* Which ipaddress and port do we connect to?                         */
/* Open a control connection using proxy or socks if necessary        */
/* Note that address and port are exposed and global                  */
/* socksserver may also be set by a call to sockscfg via *.sox:       */
/* if socksserver is non-null, socksaddress will be set.              */
/* 0 for its IP address                                               */
/*--------------------------------------------------------------------*/
Open: procedure expose ftp (variables)
parse arg s, port, tolerate?
if ^arg(3, 'E') then tolerate? = 0
signal off error
if proxy?
  then do
    'CALLPIPE (name' ftp':resolveserver end \ nomsg 15)',
             'var proxyserver',
           '| append var proxyport',
           '| join " "',
           '| tcpdots',
           '| socka2ip',
           '| spec w3 1',
           '| var proxyaddress'
    if RC = 0
      then do
        if echo?
          then say 'Opening control connection to' proxyserver,
             '('address') port' port
        call connect 'ctl', 'ctl', proxyaddress, proxyport, controlport
        ok? = result ^= ''
        if ok? then parse var result . controlport .
        if ok? & echo? then say 'Local control port is:' controlport
        end
      else ok? = 0
    if ok? then external? = 1
    end
  else do
    'CALLPIPE (name' ftp':resolveserver end \ nomsg 15)',
             'var s',
           '| append var port',
           '| join " "',
           '| tcpdots',
           '| socka2ip',
           '| spec w3 1',
           '| var address'
    if RC = 0
      then do
        if socks?
          then do
            if socksconfig?
              then 'CALLPIPE (name' ftp':socksserver end \ listerr)',
                            'var address',
                         '|  *.out.sox:',
                         '\*.in.sox:',
                         '|  var socksserver'
            if socksserver ^= ''
              then do
                'CALLPIPE (name' ftp':resolvesocks end \ nomsg 15)',
                         'var socksserver',
                       '| append var socksport',
                       '| join " "',
                       '| tcpdots',
                       '| socka2ip',
                       '| spec w3 1',
                       '| var socksaddress'
                external? = 1
                end
              else external? = 0
            end
          else external? = 0
        if external?
          then do
            if echo?
              then do
                say 'Opening control connection to' server,
                    '('address') port' port','
                say 'using SockS server' socksserver.
                    '('socksaddress') port' socksport
                end
            call rconnect 'ctl', 'ctl', address, port, controlport,,
                 socksaddress, socksport
            end
          else do
            if echo? then say 'Opening control connection to',
               server '('address') port' port
            call connect 'ctl', 'ctl', address, port, controlport
            end
        ok? = result ^= ''
        if ok? then parse var result . controlport .
        if ok? & echo? then say 'Local control port is' controlport
        end
      else ok? = 0
    end
Select
  when ^ok? & ^tolerate? then Signal TheEnd
  when ^ok? then nop
  otherwise
    call Telnet
    'SELECT BOTH ctl'                    /* talk on control stream    */
    connected? = Greeting(tolerate?)     /* Should get 220 back       */
    if connected? & proxy?
      then do
        if symbol('PROXYPASS') = 'VAR'   /* missing ^= empty password */
          then call Login proxyuser, proxypass, , tolerate?
          else call Login proxyuser, , ,tolerate?
        if result = 1 then call Command 'SITE', server, tolerate?
        ok? = (result = 1)
        end
      else ok? = connected?
    use?. = 1                            /* assume full capability    */
  end
if ok? then dataport = controlport       /* set default dataport      */
return ok?
 
/*--------------------------------------------------------------------*/
/* Ensure we have a suitable data stream set up                       */
/*--------------------------------------------------------------------*/
DataStream: procedure expose ftp (variables)
arg want?, tolerate?                     /* Do we want it, do we care */
if ^arg(2, 'E') then tolerate? = 0       /* Normally, we care         */
signal off error                         /* lots of non zero codes    */
'SELECT BOTH data'                       /* work with data stream     */
'STREAMSTATE INPUT'                      /* examine input state       */
in?  = RC ^= 12                          /* input connected flag      */
'STREAMSTATE OUTPUT'                     /* examine output state      */
out? = RC ^= 12                          /* output connected flag     */
result = 1                               /* assume we are happy       */
if want?                                 /* If we want the stream     */
  then Select                            /* we may have to add it     */
    when in? & out? then nop             /* if it exists: OK          */
    when epsv? then call command 'EPSV', , tolerate?, 0
    when ^pasv? then call command 'PORT', , tolerate?, 0
    when ^proxy? then call command 'PASV', , tolerate?, 0
    otherwise                            /* we always issue both PORT */
      call command 'PORT', , tolerate?, 0 /* and PASV to avoid EADDR- */
      call command 'PASV', , tolerate?, 0 /* INUSE when using socks   */
    end                                  /*                           */
  else do                                /* Don't want it             */
    if in?  then 'SEVER INPUT'           /* sever input if connected  */
    if out? then 'SEVER OUTPUT'          /* sever output if connected */
    'SELECT BOTH port'                   /* terminate TCPLISTEN?      */
    'SEVER INPUT'                        /* sever input if connected  */
    'SEVER OUTPUT'                       /* sever output if connected */
    accept? = 0                          /* not listening any more    */
    end                                  /*                           */
return result
 
/*--------------------------------------------------------------------*/
/* Connect directly to a remote server                                */
/*--------------------------------------------------------------------*/
Connect: procedure expose ftp (variables)
parse arg out, in, a, p, q
signal on error
'SELECT BOTH port'                       /* need the port stream      */
'SEVER INPUT'                            /* sever it for re-use       */
'SEVER OUTPUT'                           /* sever it for re-use       */
accept? = 0                              /* not listening any more    */
'ADDPIPE (name' ftp':Connect end \ listerr)' ,
         '*.out.'out':'                , /* send stream               */
       '| t: tcpclient' a p 'localport' q 'getsockname reuseaddr userid',
             tcpip,
       '| u: take 1'                   , /* extract sockname record   */
       '| *.in.port:'                  , /* make available to REXX    */
       '\ u:'                          , /* data here                 */
       '| *.in.'in':'                  ; /* receive stream            */
result = GetSockName(out, in, 'local' out)
return result
 
 
/*--------------------------------------------------------------------*/
/* Connect via a socks server                                         */
/* We always use a new port, irregardless of the current local port   */
/* since we go via a socks server & we'd get EADDRINUSE               */
/*--------------------------------------------------------------------*/
rConnect: procedure expose ftp (variables)
parse arg out, in, a, p, q, sa, sp
signal off error
'SELECT BOTH port'                       /* need the port stream      */
'SEVER INPUT'                            /* sever it for re-use       */
'SEVER OUTPUT'                           /* sever it for re-use       */
accept? = 0                              /* not listening any more    */
signal on error
'ADDPIPE (name' ftp':rConnect end \ listerr)',
       '\ *.out.'out':'                , /* send stream               */
       '| f: fanin 1 0'                , /* preface socks header      */
       '| t: tcpclient' sa sp 'getsockname reuseaddr userid' tcpip,
       '| u: take 1'                   , /* extract sockname record   */
       '| i: faninany'                 , /* append socks request      */
       '| *.in.port:'                  , /* make available to REXX    */
       '\ u:'                          , /* data here                 */
       '| v: take 8 bytes'             , /* socks server response     */
       '| i:'                          , /* make available to REXX    */
       '\ v:'                          , /* socks response            */
       '| *.in.'in':'                  , /* receive stream            */
       '\ strliteral "AF_INET' p a'"'  , /* text socket description   */
       '| ip2socka'                    , /* convert to sockaddr_in    */
       '| spec x0401 1 3.6 n "'socksuser'" n x00 n', /* socks request */
       '| o: fanout'                   , /* take copy for console     */
       '| f:'                          , /* in front of data          */
copies('\ o:'                          , /* copy of socks request     */
       '| spec 5.4 1 3.2 n'            , /* IP address port           */
       '| vchar 8 16'                  , /* make 16 bit unsigned      */
       '| fblock 2'                    , /* one octet per record      */
       '| spec 1-2 c2d 1'              , /* decimal numbers           */
       '| strip'                       , /* clean up                  */
       '| join * ","'                  , /* PORT or PASV format       */
       '| insert "Issuing SOCKS connect() for "',
       '| cons'               , echo?) ; /* write out                 */
sockname = GetSockName(out, in, out)
call SocksResponse                       /* Get response from SockS   */
if RC = 90                               /* RC 90 (x5A) is OK?        */
  then return sockname
  else return ''
 
/*--------------------------------------------------------------------*/
/* Listen: Create data port for remote server to connect back         */
/* Provide both the local port information and the descriptor record  */
/* on the port stream.   Take the first immediately and the second    */
/* later.                                                             */
/*--------------------------------------------------------------------*/
Listen: procedure expose ftp (variables)
parse arg out, in, a, p, q
signal off error
'SELECT BOTH port'                       /* need the port stream      */
'SEVER INPUT'                            /* sever it for re-use       */
'SEVER OUTPUT'                           /* sever it for re-use       */
accept? = 0                              /* not listening any more    */
signal on error
'ADDPIPE (name' ftp':Listen end \ listerr)',
         'literal +'timeout            , /* Timeout is default 30s    */
       '| delay'                       , /* wait that long            */
       '| a: faninany'                 , /* or from bad connection    */
       '| g: gate'                     , /* then give up              */
       '\ tcplisten' q 'getsockname reuseaddr userid' tcpip,
       '| g:'                          , /* terminate abruptly        */
       '| *.in.port:'                  ; /* make available to REXX    */
result = GetSockName(out, in, out)
accept? = result ^= ''                   /* 2nd record on port stream */
return result
 
/*--------------------------------------------------------------------*/
/* rListen: Create local and socks data ports for remote server       */
/* Similar to Listen except that when we have the sockaddr_in         */
/* structure for the local port, we use this to generate a SOCKS      */
/* bind() request from the local port and convert the SOCKS reply to  */
/* the sockaddr_in corresponding to the external port to be used by   */
/* the remote server, not the local port which is not reachable       */
/* rListen is very similar to rConnect in the way it works except that*/
/* the code is x02 and there are 16 bytes of responses expected of    */
/* which the last 8 must be tested later after sending a PORT command */
/*--------------------------------------------------------------------*/
rListen: procedure expose ftp (variables)
parse arg out, in, a, p, q, sa, sp       /* NB. p is control port!    */
signal off error
'SELECT BOTH port'                       /* need the port stream      */
'SEVER INPUT'                            /* sever it for re-use       */
'SEVER OUTPUT'                           /* sever it for re-use       */
accept? = 0                              /* not listening any more    */
signal on error
'ADDPIPE (name' ftp':rListen end \ listerr)',
       '\ *.out.'out':'                , /* send stream               */
       '| f: fanin 1 0'                , /* preface socks header      */
       '| t: tcpclient' sa sp 'localport' q 'getsockname reuseaddr',
               'userid' tcpip 'linger'  timeout,
       '| u: take 1'                   , /* extract sockname record   */
       '| i: faninany'                 , /* append socks request      */
       '| *.in.port:'                  , /* make available to REXX    */
       '\ u:'                          , /* data here                 */
       '| v: take 16 bytes'            , /* socks server responses    */
       '| fblock 8'                    , /* split responses           */
       '| i:'                          , /* make available to REXX    */
       '\ v:'                          , /* socks response            */
       '| *.in.'in':'                  , /* receive stream            */
       '\ strliteral "AF_INET' p a'"'  , /* text socket description   */
       '| ip2socka'                    , /* convert to sockaddr_in    */
       '| spec x0402 1 3.6 n "'socksuser'" n x00 n', /* socks request */
       '| o: fanout'                   , /* take copy for console     */
       '| f:'                          , /* in front of data          */
copies('\ o:'                          , /* copy of socks request     */
       '| spec 5.4 1 3.2 n'            , /* IP address port           */
       '| vchar 8 16'                  , /* make 16 bit unsigned      */
       '| fblock 2'                    , /* one octet per record      */
       '| spec 1-2 c2d 1'              , /* decimal numbers           */
       '| strip'                       , /* clean up                  */
       '| join * ","'                  , /* PORT or PASV format       */
       '| insert "Issuing SOCKS bind() with primary connection of "',
       '| cons'               , echo?) ; /* write out                 */
parse value GetSockName(out, in, out) with . dataport . /* record it  */
call SocksResponse                       /* Get response from SockS   */
if RC = 90 then accept? = 1              /* RC 90 (x5A) is OK?        */
return result
 
/*--------------------------------------------------------------------*/
/* Accept: We have added the TCPLISTEN stage with Listen() now we     */
/* need to hand the descriptor record (without delaying it) a TCPDATA */
/* stage.                                                             */
/*--------------------------------------------------------------------*/
Accept: procedure expose ftp (variables)
parse arg out, in, a, p, . , sa, sp      /* NB. p is control port!    */
parse value Listenresponse() with . p a 1 sockname
Select
  when p a = ''
    then do
      say 'Remote host did not connect to the data port within',
           timeout 'second timeout period'
      ok? = 0
      end
  when ^proxy? & p = (port-1) & a = address  then ok? = 1
  when ^proxy? & a = address  & anydataport? then ok? = 1
  when proxy?  & p = (proxyport-1) & a = proxyaddress then ok? = 1
  when proxy?  & a = proxyaddress  & anydataport?     then ok? = 1
  otherwise
    ok? = 0
    if a = address
      then do
        say 'Bad connection attempt from remote host ('a') using port',
            p'.'
        say 'This is probably caused by a broken FTP daemon.'
        say 'Use the PASSIVE option or the ANYDATAPORT option.'
        end
      else say 'Unexpected attempt to connect to data port from host',
           a', port' p
  end
/*--------------------------------------------------------------------*/
/* We add a co-processor for the accept() function which handles the  */
/* new connection.  Then we pass the validated connection descriptor  */
/* to the co-processor to start it.                                   */
/*--------------------------------------------------------------------*/
if ok?
  then do
    'ADDPIPE (name' ftp':Accept end \ listerr)',
         '*.out.port:'                 , /* get the descriptor record */
       '| take 1'                      , /* disconnect after it       */
       '| i: fanin'                    , /* connection then data      */
       '| tcpdata oobinline'           , /* read/write data here      */
       '| *.in.'in':'                  , /* data arrives here         */
       '\ *.out.'out':'                , /* data sent here            */
       '| i:'                          ; /* append to connection      */
    'CALLPIPE (name' ftp':GiveSocket end \ listerr)',
       '| *.in.port:'                  , /* get the descriptor record */
       '| take 1'                      , /* limit it to one           */
       '| *.out.port:'                 ; /* and pass it to accept()   */
    end
if ok?
  then return sockname
  else return ''
 
/*--------------------------------------------------------------------*/
/* rAccept: When doing a socks listen(), we get two socks responses.  */
/* We simply read the second to do the accept()                       */
/* Note that we can ony do one accept() for a socks bind() unlike a   */
/* listen() which allows many                                         */
/*--------------------------------------------------------------------*/
rAccept: procedure expose ftp (variables)
parse arg out, in, a, p, . , sa, sp      /* NB. p is control port!    */
parse value socksresponse() with . p a 1 sockname
Select
  when RC ^= 90 then ok? = 0
  when p = (port-1) & a = address then ok? = 1
  when a = address & anydataport? then ok? = 1
  otherwise
    ok? = 0
    if a = address
      then do
        say 'Bad connection attempt from remote host ('a') using port',
            p'.'
        say 'This is probably caused by a broken FTP daemon.'
        say 'Use the PASSIVE option or the ANYDATAPORT option.'
        end
      else say 'Unexpected attempt to connect to data port from host',
           a', port' p
  end
accept? = 0                        /* flag that we've taken it  */
if ok?
  then return sockname
  else return ''
 
/*--------------------------------------------------------------------*/
/* Return IP and port information for the newly bound data stream     */
/* from Listen, or sever it if its dead                               */
/*--------------------------------------------------------------------*/
GetSockName: procedure expose ftp (variables)
parse arg out, in, adjective
if adjective = 'ctl' then adjective = 'control'
signal off error
'SELECT INPUT port'
'PEEKTO result'
if RC ^= 0
  then do
    say space('Unable to bind' adjective 'socket')
    'SELECT INPUT' in
    'SELECT OUTPUT' out
    'SEVER INPUT'
    'SEVER OUTPUT'
    RC = 16
    result = ''
    end
  else do
    'CALLPIPE (name' ftp':GetSockName end \ listerr)',
        '*.in.port:'                   , /* produced at listen start  */
      '| take 1'                       , /* to be sure to be sure     */
      '| socka2ip'                     , /* make readable             */
      '| split'                        , /* AF_INET / port / address  */
      '| drop 1'                       , /* drop keyword              */
      '| var p'                        , /* record ephemeral port     */
      '| drop 1'                       , /* drop port                 */
      '| pick w1 ^== "0"'              , /* don't want IP address 0   */
      '| append hostid'                , /* append default address    */
      '| var a'                        ; /* save one or the other     */
      result = 'AF_INET' p a
    end
return result
 
/* ListenResponse: extract the address of the connecting server       */
/* Note that we *must* not consume the record: hence the dynamic rexx */
/* return sockaddr_in  in text form                                   */
ListenResponse: procedure expose ftp (variables) RC sigl
parse arg
signal off error
'SELECT INPUT PORT'
'CALLPIPE (name' ftp':SocksResponse end \ listerr)',
        'literal +'timeout             , /* Timeout is default 30s    */
      '| delay'                        , /* wait that long            */
      '| g: gate'                      , /* then give up              */
      '\ *.in.port:'                   , /* get the TCPLISTEN record  */
      '| g:'                           , /* record here means stop    */
      '| r: rexx (*.1:)'               , /* peek one record only      */
      '| spec 65.16 1'                 , /* to sockaddr_in            */
      '| socka2ip'                     , /* to text                   */
      '| append literal'               , /* in case no value          */
      '| var result'                   , /* and save                  */
      '\ literal /**/ "PEEKTO x";"OUTPUT" x',
      '| r:'                           ; /* Feed to rexxror message   */
return result
 
/* Socksresponse: parse the response from the socks server            */
/* return sockaddr_in  in text form                                   */
SocksResponse: procedure expose ftp (variables) RC sigl
signal off error
'CALLPIPE (name' ftp':SocksResponse end \ listerr)',
        'literal +'timeout             , /* Timeout is default 30s    */
      '| delay'                        , /* wait that long            */
      '| g: gate'                      , /* then give up              */
      '\ *.in.port:'                   , /*                           */
      '| take 8 bytes'                 , /* only take one socks reply */
      '| g:'                           , /* record here means stop    */
      '| o: fanout'                    , /*                           */
      '| spec 1-2 c2x 1'               , /* to hex                    */
      '| append literal 0008'          , /* timeout is RC 8           */
      '| take 1'                       , /* timeout only if no resp.  */
      '| l: lookup 1.4 master'         , /* code to message           */
      '| i: faninany'                  , /* get unknown codes         */
      '| chop after string "005A"'     , /* discard if OK             */
      '| c: chop after blank'          , /* split into code & text    */
      '| spec w1 x2d'                  , /* convert to return code    */
      '| var sRC'                      , /* and save                  */
      '\ c:'                           , /* bad code from server: msg */
      '| locate w1'                    , /*                           */
      '| cons'                         , /* write out if not          */
      '\ o:'                           , /* RC dstport dstip here     */
      '| strfind x005A'                , /* only interested RC 90     */
      '| spec pad 00 x0002 1 3.6 3-16' , /* to sockaddr_in            */
      '| socka2ip'                     , /* to text                   */
      '| append literal'               , /* in case of bad value      */
      '| var result'                   , /* and save                  */
      '\ literal 005A Connecting."'    , /* Socks message codes       */
      '| literal 005B SOCKS request rejected or failed.',
      '| literal 005C SOCKS request rejected because server cannot',
                'connect to identd on the client.',
      '| literal 005D SOCKS request rejected because the client program',
                'and identd report different user-ids.',
      '| literal 0008 SOCKS server did not respond within' timeout,
                'second timeout period',
      '| l:'                           ,
      '| spec w1 1 "Unexpected SOCKS server reply: 0x" nw w1 n',
      '| i:'                           ; /* write the error message   */
RC = sRC
if RC = 90 & word(result, 3) = 0
  then result = subword(result, 1, 2) socksaddress /* INADDR_ANY */
return result
 
/*--------------------------------------------------------------------*/
/* ADDPIPE the basic TELNET processor                                 */
/* The pipe itself performs the minimum TELNET option negotiation     */
/* and handles all Telnet control sequences as well as EBCDIC-ASCII   */
/* conversion sequences.  A tcpclient stage must be connected with    */
/* ADDPIPE to the ctl streams.  Telnet adds a pre-and-post processor  */
/* routine to the stream allowing record-based EBCDIC input and       */
/* output to the client.  The routine also removes all Telnet         */
/* control codes returned by the server and replies automatically as  */
/* needed.                                                            */
/* Because the processor does not support any options with            */
/* subnegotiation possibilities, all subnegotiations are discarded    */
/* This is done by using juxtapose to prefix the entire stream with   */
/* the last SE or SB code received and discarding all SB lines.  We   */
/* should never have to do this because we respond negatively to all  */
/* option requests and we should never get any of them either.        */
/* We cannot support SYNCH because we cannot tell whether data is     */
/* urgent.                                                            */
/*--------------------------------------------------------------------*/
Telnet: procedure expose ftp (variables)
call telnetcodes
call xlatestages 1
'ADDPIPE (name' ftp':Telnet end \ listerr)',
       '\ *.out.ctl:'                  , /* FTP commands written here */
copies('| o2: fanout'                  , /* echo commands sent        */
       '| x1: if pick anycase w1 == "PASS"', /* is it a PASS command? */
       '| spec w1 1 "********" nw'     , /* yes treat as special case */
       '| x1:'                         , /* end of special            */
       '| insert ">>> "'               , /* highlight commands        */
       '| cons'                        , /* merge with echo stream    */
       '\ o2:'                 , echo?), /* commands again            */
       '| insert x0D25 after'          , /* append CRLF               */
       xlate2a                         , /* convert to ASCII          */
       '| change' _IAC _IAC_IAC        , /* double IACs               */
       '| f1: fanintwo'                , /* negotiation responses 1st */
       '| *.out.ctl:'                  , /* to tcpclient              */
       '\ strliteral' _SE              , /* ^subnegotiation to start  */
       '| e1: elastic'                 , /* loopback SB/SE flags      */
       '| j: juxtapose'                , /* prefix to stream          */
       '| strfind' _SE                 , /* Discard subnegotiations   */
       '| not chop 1'                  , /* discard SE flag           */
       '| split before' _IAC           , /* IACs at to start of lines */
       '| joincont trailing' _IAC      'keep', /* get escaped char    */
       '| joincont trailing' _IAC_SB   'keep', /* and any option code */
       '| joincont trailing' _IAC_WILL 'keep', /* and any option code */
       '| joincont trailing' _IAC_WONT 'keep', /* and any option code */
       '| joincont trailing' _IAC_DO   'keep', /* and any option code */
       '| joincont trailing' _IAC_DONT 'keep', /* and any option code */
       '| IAC: strnfind' _IAC          , /* not TELNET commands       */
       '| f2: fanintwo'                , /* data that came with cmds  */
       xlata2e                         , /* convert to EBCDIC         */
       '| deblock CRLF'                , /* reblock lines             */
copies('| o3: fanout'                  , /* responses again           */
       '| cons'                        , /* merge with echo stream    */
       '\ o3:'                 , echo?), /* responses again           */
       '| elastic'                     , /* allow backlog for later   */
       '| *.in.ctl:'                   , /* FTP responses here        */
       '\ *.in.ctl:'                   , /* from tcpclient            */
       '| j:'                          , /* prefix with SB/SE flags   */
       '\ i1: faninany'                , /* negotiation responses     */
       '| f1:'                         , /* feedback asap             */
       '\ i2: faninany'                , /* get SE/SB here            */
       '| e1:'                         , /* feedback with no stall    */
       '\ i3: faninany'                , /* data after commands       */
       '| f2:'                         , /* feedback asap             */
       '\ IAC:'                        , /* TELNET IAC characters     */
       '| not chop 1'                  , /* remove the IAC            */
       '| p1: pick 1 ==' _IAC          , /* it was an escaped IAC     */
       '| i3:'                         , /* merge together again      */
       '\ p1:'                         , /* TELNET command (+data?)   */
       '| p2: pick 1 <<' _SB           , /* single byte command       */
       '| c1: not chop 1'              , /* redirect command only     */
       '| i3:'                         , /* data with main stream     */
       '\ p2:'                         , /* double byte command       */
       '| c2: not chop 2'              , /* remove control sequence   */
       '| i3:'                         , /* data with main stream     */
       '\ c1:'                         , /* handle single-byte cmds   */
       '| SE:   strnfind' _SE          , /* ignore except SE          */
       '\ c2:'                         , /* handle double-byte cmds   */
       '| SB:   strnfind' _SB          , /* SB flag data ^significant */
       '| WILL: strnfind' _WILL        , /* WILL respond DONT         */
       '| WONT: strnfind' _WONT        , /* WONT confirm DONT         */
       '| DO:   strnfind' _DO          , /* DO   respond WONT         */
       '| DONT: strnfind' _DONT        , /* DONT confirm WONT         */
       '\ SE:'                         , /* SE byte alone.  Prefix it */
       '| i2:'                         , /* and use these as flags    */
       '\ SB:'                         , /* SB byte/code.  Prefix them*/
       '| i2:'                         , /* to data := ^significant   */
       '\ WILL:'                       , /* WILL + code, send a DON'T */
       '| spec' _DONT '1 2 2'          , /* back immediately          */
       '| i1:'                         , /*                           */
       '\ WONT:'                       , /* WONT + code, send a DON'T */
       '| spec' _DONT '1 2 2'          , /* back immediately          */
       '| i1:'                         , /*                           */
       '\ DO:'                         , /* DO + code, send a WON'T   */
       '| spec' _WONT '1 2 2'          , /* back immediately          */
       '| i1:'                         , /*                           */
       '\ DONT:'                       , /* DONT + code, send a WON'T */
       '| spec' _WONT '1 2 2'          , /* back immediately          */
       '| i1:'                         , /*                           */
       table2a                         , /* input translate tables to */
       tabla2e                         ; /* xlate if needed           */
return
 
/* xlatestages: set primary and secondary pipeline segments for       */
/*              xlate stages for EBCDIC-ASCII and v.v.                */
/*              variables are xlate2a, table2a, xlata2e, tabla2e      */
/*              labels are E2A: and A2E:                              */
/* called with flag: 1 translation needed, 0 not needed               */
xlatestages:
Select
  when ^arg(1) then parse value '' with xlate2a table2a xlata2e tabla2e
  when ebcdic ^= '' & ascii ^= ''        /* xlate using codepages     */
    then do
      xlate2a = '| E2A: xlate from' ebcdic 'to' ascii
      table2a = ''
      xlata2e = '| A2E: xlate from' ascii 'to' ebcdic
      tabla2e = ''
      end
  otherwise                              /* xlate using tables        */
    xlate2a = '| E2A: xlate'
    table2a = '\ strliteral x'c2x(e2a) '| E2A:'
    xlata2e = '| A2E: xlate'
    tabla2e = '\ strliteral x'c2x(a2e) '| A2E:'
  end
return
 
/*--------------------------------------------------------------------*/
/* For the Type, Mode and Structure, if nothing is specified, we try  */
/* our defaults of Ebcdic, Block and Record but don't complain if it  */
/* fails.   However if any is specified explicitly then we stop if    */
/* it fails                                                           */
/*--------------------------------------------------------------------*/
TryEBCDIC: procedure expose ftp (variables)
Select
  when ^use?.0EBCDIC           then type = 'A'
  when Command('TYPE', 'E', 1) then nop
  otherwise
    type = 'A'
    use?.0EBCDIC = 0
  end
return use?.0EBCDIC
 
TryRecord: procedure expose ftp (variables)
Select
  when ^use?.0RECORD           then structure = 'F'
  when Command('STRU', 'R', 1) then nop
  otherwise
    strucure = 'F'
    use?.0RECORD = 0
  end
return use?.0RECORD
 
TryBlock: procedure expose ftp (variables)
Select
  when ^use?.0BLOCK            then mode = 'S'
  when Command('MODE', 'B', 1) then nop
  otherwise
    mode = 'S'
    use?.0BLOCK = 0
  end
return use?.0BLOCK
 
DefaultTypeModeStructure:
if type      = ''   then type      = 'A'
if mode      = ''   then mode      = 'S'
if structure = ''   then structure = 'F'
return
 
/*--------------------------------------------------------------------*/
/* CloseControl: Heavy handed approach to closing the control pipe    */
/*--------------------------------------------------------------------*/
CloseControl: procedure expose ftp (variables)
signal off error
signal off failure
'SELECT BOTH ctl'
'SEVER INPUT'
'SEVER OUTPUT'
connected? = 0
return
 
/*--------------------------------------------------------------------*/
/* Blocker: return preprocessor to add linends and block              */
/* For EBCDIC files with FILE structure in BLOCK mode, we treat as    */
/* RECORD structure anyway: VM does this so we will too.              */
/*--------------------------------------------------------------------*/
Blocker: procedure expose ftp (variables)
pipe = ''
Select
  when mode = 'S'
    then Select
      when structure = 'F'
        then Select
          when type = 'A'
            then pipe = pipe '| block 65535 string x0D0A terminate'
          when type = 'E'
            then pipe = pipe '| block 65535 linend terminate'
          otherwise
          end
      when structure = 'R'
        then pipe = pipe,
               '|  change xFF xFFFF',
               '|I:if take last 1',
               '|  insert xff03 after',
               '|I:',
               '|  insert xff01 after',
               '|I:'
      otherwise
      end
  when mode = 'B'
    then Select
      when structure = 'F' & type = 'A'
        then pipe = pipe,
              '|  block 65535 string x0D0A terminate',
              '|  addrdw cms',
              '|I:if take last 1',
              '|  insert x40',
              '|I:',
              '|  insert x00',
              '|I:'
      when structure = 'F' & type = 'I'
        then pipe = pipe,
              '|  addrdw cms',
              '|I:if take last 1',
              '|  insert x40',
              '|I:',
              '|  insert x00',
              '|I:'
      when structure = 'R' | (structure = 'F' & type = 'E')
        then pipe = pipe               , /* need to handle EoR & EoF  */
             '| S: spec number 1 write outstream 1 1-* 1', /* recno   */
             '| J: juxtapose'          , /* number spilled records    */
             '| spec select second x00 1 11-* 2 a: 1-10 . break a x80 1',
             '| O: fanout'             , /* straighten pipe           */
             '\ S:'                    , /* record contents           */
             '| deblock fixed 65535'   , /* spill into blocks         */
             '| addrdw cms'            , /* prefix with length        */
             '| J:'                    , /* add number for breaks     */
             '\ O:'                    , /* restart marker bit        */
             '| I: if take last 1'     , /* restart marker bit        */
             '| xlate 1 80 C0 00 40'   , /* marker & block number     */
             '| I:'                    ; /* write out if in use       */
      otherwise
      end
  otherwise
  end
return pipe
 
/*--------------------------------------------------------------------*/
/* Deblocker: return postprocessor to deblock and create records      */
/*--------------------------------------------------------------------*/
Deblocker: procedure expose ftp (variables)
pipe = ''
Select
  when mode = 'B'
    then do
      pipe = pipe                      , /* Handle RFC 959 blocking   */
        '| deblock rfc959'             , /* break into rdw & data     */
        '| spec number 1 1 c2b 12.4 4-* 17', /* block #, flags data   */
        '| A: locate 15 "1"'           , /* restart marker bit        */
        '| spec w3 1 w1 nw'            , /* marker & block number     */
 copies('| *.out.2:', markers?)        , /* write out if in use       */
        '\ A:'                         , /* non-restart blocks        */
        '| B: fanout'                  , /* Extra copy for suspects   */
        '| locate 14 "1"'              , /* suspect bit!  like wow!   */
        '| spec "Suspect data bit on for block" 1 w1 nw',
        '| cons'                       , /* get non suspect           */
        '\ B:'                         , /* non-restart blocks        */
        '| spec 12.2 1 17-* n'         , /* EoR, EoF flags EoF flags  */
        '| C: if frtarget locate 2 "1"', /* find EoF block            */
        '| take 1'                     , /* stop after it             */
        '| C:'                         , /* file before EoF here      */
        '| change 1.2 /01/11/'         , /* force <EoF> to <EoR><EoF> */
        '| D: fanout'                  , /* Extra copy for check EoF  */
        '| take last 1'                , /* last record in stream     */
        '| nlocate 2 "1"'              , /* if EoF is missing....     */
        '| spec "Final block does not contain <EoF> indicator" 1 write' ,
               '"possible premature end-of-file or naughty server" 1',
      , /* Never write this message: the VM FTP server is naughty     */
 copies('| cons', echo? & 0)           , /* write message             */
        '\ D:'                         ; /* non-restart upto <EoF>    */
      if structure = 'R'
        then pipe = pipe,
               '| spec 3-* 1 1 n',
               '| joincont trailing 0',
               '| strip trailing 1 1'
        else pipe = pipe '| not chop 2'
      end
  when mode = 'S' & structure = 'R'
    then pipe = pipe                   , /* Handle xFF escape seqs.   */
    '| change xFFFF xFF00'             , /* Not quite legal, but..    */
    '| change xFF03 xFF01FF02'         , /* Create <EoR><EoF> sequence*/
    '| deblock string xFF01 terminate' , /* Create records            */
    '| chop before string xFF02'       , /* Data up to end of file    */
    '| change xFF00 xFF'               ; /* Make xFFFF as should be FF*/
  when mode = 'S' & structure = 'F'
    then Select
      when type = 'A' then pipe = pipe '| deblock string x0D0A terminate'
      when type = 'E' then pipe = pipe '| deblock linend terminate'
      otherwise
      end
  otherwise
  end
return pipe
 
/*--------------------------------------------------------------------*/
/* Port parameter in format accepted by FTP Port command              */
/* Ipaddress must be fully specified, ie. 4 decimal octets            */
/*--------------------------------------------------------------------*/
PortParameter: procedure expose ftp (variables)
arg a, p
parse value d2c(p, 2) with h 2 l
return translate(a, ',', '.')','c2d(h)','c2d(l)
 
/*--------------------------------------------------------------------*/
/* Greeting                                                           */
/*                        1,3      ⁄ƒƒƒø                              */
/*                   ⁄ƒƒƒƒƒƒƒƒƒƒƒƒ>≥ E ≥                              */
/*                   ≥             ¿ƒƒƒŸ                              */
/*  ⁄ƒƒƒø          ⁄ƒÖƒø   2       ⁄ƒƒƒø                              */
/*  ≥ B ‰ƒƒƒƒƒƒƒƒƒ>≥ W ‰ƒƒƒƒƒƒƒƒƒƒ>≥ S ≥                              */
/*  ¿ƒƒƒŸ          ¿ƒ†ƒŸ           ¿ƒƒƒŸ                              */
/*                   ≥    4,5      ⁄ƒƒƒø                              */
/*                   ¿ƒƒƒƒƒƒƒƒƒƒƒƒ>≥ F ≥                              */
/*                                 ¿ƒƒƒŸ                              */
/*                                                                    */
/*--------------------------------------------------------------------*/
Greeting: procedure expose ftp (variables) RC
arg tolerate?, response?
if ^arg(1, 'E') then tolerate? = 0
if ^arg(2, 'E') then response? = responses?
RC = response()
ok? = x00?(RC, 200)
if ^ok? & ^tolerate? then call reject RC
return ok?
 
/*--------------------------------------------------------------------*/
/* Command implement the state diagrams in RFC 951 which are          */
/*         duplicated here                                            */
/*         B == begin, W == wait, E = error, F=failure, S= Success    */
/*         1,2,3,4,5 are the first digits of the reply codes          */
/*         Each state routine starts at B (the call to the routine)   */
/*         and returns when it reaches, E, F or S.                    */
/*--------------------------------------------------------------------*/
Command: procedure expose ftp (variables) RC
arg command, , tolerate?, response?
if wordpos(command, FTPCOMMANDS) = 0 then call rejectcommand command
if ^arg(3, 'E') then tolerate? = 0
if ^arg(4, 'E') then response? = responses?
parse arg , parameters
signal on syntax name SimpleCommand
signal value command
 
/*--------------------------------------------------------------------*/
/* Simple Commands                                                    */
/*                                                                    */
/*                        1,3      ⁄ƒƒƒø                              */
/*                   ⁄ƒƒƒƒƒƒƒƒƒƒƒƒ>≥ E ≥                              */
/*                   ≥             ¿ƒƒƒŸ                              */
/*  ⁄ƒƒƒø   cmd    ⁄ƒÖƒø   2       ⁄ƒƒƒø                              */
/*  ≥ B ‰ƒƒƒƒƒƒƒƒƒ>≥ W ‰ƒƒƒƒƒƒƒƒƒƒ>≥ S ≥                              */
/*  ¿ƒƒƒŸ          ¿ƒ†ƒŸ           ¿ƒƒƒŸ                              */
/*                   ≥    4,5      ⁄ƒƒƒø                              */
/*                   ¿ƒƒƒƒƒƒƒƒƒƒƒƒ>≥ F ≥                              */
/*                                 ¿ƒƒƒŸ                              */
/*                                                                    */
/* ABOR, ALLO, DELE, CWD, CDUP, SMNT, HELP, MODE, NOOP, PASV, QUIT,   */
/* SITE, PORT, SYST, STAT, RMD, MKD, PWD, STRU, TYPE (and also the    */
/* RNTO part of the RENAME sequence and the ACCT part of the USER     */
/* sequence).                                                         */
/* Note: some commands are handled separately, but many are handled   */
/* by this one routine via a syntax trap                              */
/*--------------------------------------------------------------------*/
SimpleCommand:
signal on syntax
RC = response(command, parameters)
ok? = x00?(RC, 200)
if ^ok? & ^tolerate? then CALL reject RC
return ok?
 
/*--------------------------------------------------------------------*/
/* TYPE, MODE and STRU must record the setting                        */
/*--------------------------------------------------------------------*/
TYPE:
signal on syntax
arg , t f
ok? = 0
Select
  when wordpos(t, 'A E I L') = 0 then say "Type '"t"' is not supported"
  when t = 'L'
    then if f ^= 8    then say "Local byte size '"f"' is not supported"
  when f ^= 'N' & f ^= ''      then say "Format '"f"' is not supported"
  otherwise
    RC = response(command, parameters)
    ok? = x00?(RC, 200)
    Select
      when ok? then type = t
      when tolerate? then nop
      otherwise CALL reject RC
      end
    end
return ok?
 
MODE:
signal on syntax
arg , m
ok? = 0
Select
  when wordpos(m, 'B S') = 0 then say "Mode '"m"' is not supported"
  otherwise
    RC = response(command, parameters)
    ok? = x00?(RC, 200)
    Select
      when ok? then mode = m
      when tolerate? then nop
      otherwise CALL reject RC
      end
    end
return ok?
 
STRU:
signal on syntax
arg , s
ok? = 0
Select
  when wordpos(s, 'F R') = 0 then say "Structure '"s"' is not supported"
  otherwise
    RC = response(command, parameters)
    ok? = x00?(RC, 200)
    Select
      when ok? then structure = s
      when tolerate? then nop
      otherwise CALL reject RC
      end
    end
return ok?
 
/*--------------------------------------------------------------------*/
/* Implemented separately because we are not fussy about how it goes  */
/*--------------------------------------------------------------------*/
QUIT:
signal on syntax
RC = response(command, parameters, 1)
connected? = ^x00?(RC, 200)
return ^connected?
 
/*--------------------------------------------------------------------*/
/* Implemented separately from SimpleCommand because we must set up   */
/* the data stream                                                    */
/*--------------------------------------------------------------------*/
PORT:
signal on syntax
signal off error
'SELECT BOTH data'
'SEVER INPUT'
'SEVER OUTPUT'
Select
  when proxy?
    then call  Listen 'data', 'data', address, proxyport-1, 0
  when external?
    then call rListen 'data', 'data', address, port /* ! */,,
      0, socksaddress, socksport
  otherwise           call  Listen 'data', 'data', address, port-1, 0
  end
ok? = result ^= '' & accept?
if ok? then parse var result . dataport . 1 . p a
Select
  when ok?
    then do
      RC = response(command, PortParameter(a, p))
      ok? = x00?(RC, 200)
      if ^ok? & ^tolerate? then CALL reject RC
      if ok? then pasv? = 0
      end
  when tolerate? then nop
  otherwise
    RC = 12
    signal TheEnd
  end
/*--------------------------------------------------------------------*/
/* Did we get a connection straight away?  If we did accept it        */
/*--------------------------------------------------------------------*/
if ok? & accept?
  then do
    'SELECT INPUT PORT'
    'STREAMSTATE INPUT'
    if RC = 0
      then do
        Select
          when proxy?
            then call  Accept 'data', 'data', proxyaddress, proxyport-1
          when external?
            then call rAccept 'data', 'data', address, port /* ! */,,
              , socksaddress, socksport
          otherwise          call  Accept 'data', 'data', address, port-1
          end
        ok? = result ^= ''
        end
    end
return ok?
 
/*--------------------------------------------------------------------*/
/* Implemented separately from SimpleCommand because we must set up   */
/* the data stream and the response must be scanned  for 227          */
/*--------------------------------------------------------------------*/
PASV:
signal on syntax
signal off error
'SELECT BOTH data'
'SEVER INPUT'
'SEVER OUTPUT'
RC = response(command, parameters)
Select
  when RC ^= 227 & ^tolerate? then call reject RC
  when RC ^= 227 then result = ''
  otherwise
    signal on error name Reject227       /* In case socka2ip objects  */
    signal on novalue name Reject227     /* in case no value found    */
    'CALLPIPE (name' ftp':Parse227 end \ listerr)' ,
          'stem response.'             , /* response from PASV        */
        '| strip leading string "227-"', /* discard message numbers   */
        '| strip leading string "227 "', /* discard message numbers   */
        '| tokenise /( )/'             , /* both RFC 959 forms        */
        '| locate w1'                  , /* discard blank lines       */
        '| verify "0123456789,"'       , /* i1,i2,i3,i4,p1,p2 line    */
        '| locate fs , f6'             , /* ensure its complete       */
        '| nlocate fs , f7'            , /* and not too long          */
        '| split at ,'                 , /* one byte per line         */
        '| spec 1-* d2c 1.1 right'     , /* convert to character      */
        '| join *'                     , /* six byte string           */
        '| spec pad 00 x0002 1 5.2 n 1.4 n.12', /* layout sockaddr_in */
        '| (nomsg 15) socka2ip'        , /* convert to text           */
        '| spec w3 1 w2 nw'            , /* IP address then port      */
        '| var result'                 ; /*                           */
  end
parse var result a p
Select
  when proxy?    then call  Connect 'data', 'data', a, p, dataport
  when external?
    then call rConnect 'data','data',a,p, dataport,socksaddress,socksport
  otherwise           call  Connect 'data', 'data', a, p, dataport
  end
ok? = result ^= ''
if ok? then parse var result . dataport .
Select
  when ok? then pasv? = 1
  when tolerate? then nop
  otherwise
    RC = 12
    signal TheEnd
  end
return ok?
 
/*--------------------------------------------------------------------*/
/* Reject227: could not parse the 227 response                        */
/*--------------------------------------------------------------------*/
Reject227:
say 'Unable to parse message 227 in response to PASV command'
if ^tolerate?
  then call Reject 227
  else return ''
 
/*--------------------------------------------------------------------*/
/* Implemented separately from SimpleCommand because we must set up   */
/* the data stream and the response must be scanned  for 229          */
/*--------------------------------------------------------------------*/
EPSV:
signal on syntax
signal off error
'SELECT BOTH data'
'SEVER INPUT'
'SEVER OUTPUT'
RC = response(command, parameters)
Select
  when RC ^= 229 & ^tolerate? then call reject RC
  when RC ^= 229 then result = ''
  otherwise
    signal on error name Reject229
    signal on novalue name Reject229     /* in case no value found    */
    'CALLPIPE (name' ftp':Parse229 end \ listerr)' ,
          'stem response.'             , /* response from EPSV        */
        '| tokenise "()"'              , /* Find the response w/port  */
        '| inside "(" ")"'             , /* Just the response         */
        '| spec fs 4F f4 1'            , /* Get the port field. 4F="|"*/
        '| verify "0123456789"'        , /* Must be a number          */
        '| var p'                      ; /* The port                  */
  end
Select
  when proxy?    then call  Connect 'data', 'data', address, p, dataport
  when external? then call rConnect 'data', 'data', address, p,,
       dataport, socksaddress, socksport
  otherwise           call  Connect 'data', 'data', address, p, dataport
  end
ok? = (result ^= '')
if ok? then parse var result . dataport .
Select
  when ok? then epsv? = 1
  when tolerate? then nop
  otherwise
    RC = 12
    signal TheEnd
  end
return ok?
 
/*--------------------------------------------------------------------*/
/* Reject229: could not parse the 229 response                        */
/*--------------------------------------------------------------------*/
Reject229:
say 'Unable to parse message 229 in response to EPSV command'
if ^tolerate?
  then call Reject 229
  else return ''
 
/*--------------------------------------------------------------------*/
/* commands expecting a 100 reply                                     */
/*                         3       ⁄ƒƒƒø                              */
/*                   ⁄ƒƒƒƒƒƒƒƒƒƒƒƒ>≥ E ≥                              */
/*                   ≥             ¿ƒƒƒŸ                              */
/*  ⁄ƒƒƒø   cmd    ⁄ƒÖƒø   2       ⁄ƒƒƒø                              */
/*  ≥ B ‰ƒƒƒƒƒƒƒƒƒ>≥ W ‰ƒƒƒƒƒƒƒƒƒƒ>≥ S ≥                              */
/*  ¿ƒƒƒŸ      ⁄ƒƒ>¿†ƒ†Ÿ           ¿ƒƒƒŸ                              */
/*            1≥    ≥ ≥   4,5      ⁄ƒƒƒø                              */
/*             ¿ƒƒƒƒŸ ¿ƒƒƒƒƒƒƒƒƒƒƒ>≥ F ≥                              */
/*                                 ¿ƒƒƒŸ                              */
/*                                                                    */
/* APPE, LIST, NLST, REIN, RETR, STOR, STOU                           */
/*--------------------------------------------------------------------*/
REIN:
signal on syntax
RC = response(command, parameters)       /* Initial 100 response      */
if x00?(RC, 100) then RC = response()    /* wait for 200 response     */
ok? = x00?(RC, 200)
if ^ok? & ^tolerate? then call reject RC
return ok?
 
RETR: LIST: NLST:
signal on syntax
signal off error                         /* handle errors manually    */
'SELECT OUTPUT 0'                        /* primary output stream     */
'STREAMSTATE OUTPUT'                     /* check if its at EoF       */
if RC = 12 then Signal TheEnd            /* terminate if so           */
ok? = DataStream(1, tolerate?)           /* ensure we've a data port  */
if type = '' | mode = '' | structure = ''
  then call DefaultTypeModeStructure
otype      = type                        /* save these settings       */
omode      = mode                        /*                           */
ostructure = structure                   /*                           */
if ok?                                   /* if we do                  */
  then do                                /*   then                    */
    if command ^= 'RETR'                 /* For NLST or LIST commands */
      then do                            /* don't use IMAGE but use   */
        Select
          when type = 'A' | type = 'E' then nop
          when ^use?.0EBCDIC then call Command 'TYPE', 'A', 1
          when Command('TYPE', 'E', 1) then nop
          otherwise
            use?.0EBCDIC = 0
            call Command 'TYPE', 'A', 1
          end
        if mode      ^= 'S' then call Command 'MODE', 'S', 1
        if structure ^= 'F' then call Command 'STRU', 'F', 1
        end
    RC = response(command, parameters)   /*     send the command      */
    ok? = x00?(RC, 100)                  /*     initial 100 response  */
    end                                  /*                           */
Select                                   /* Do we need to validate    */
  when ^accept? then nop                 /* the connection if it is   */
  when ok?                               /* via a socks bind?         */
    then do                              /* yes: get the record       */
      Select
        when proxy?
          then call  Accept 'data', 'data', proxyaddress, proxyport-1
        when external?
          then call rAccept 'data', 'data', address, port /* ! */,,
            , socksaddress, socksport
        otherwise           call  Accept 'data', 'data', address, port-1
        end
      ok? = result ^= ''
      end                                /*                           */
  otherwise accept? = 0                  /* there will be no response */
  end                                    /* sever the stream below    */
if ok?                                   /* We are happy, so get the  */
  then do                                /* data which is queueing up */
    call xlatestages (type = 'A')        /* translate for ASCII       */
    call time('R')                       /* in the data stream        */
    'CALLPIPE (name' ftp':'command 'end \ listerr)',
         'i: faninany'                 , /* pipestoppers here         */
       '| g: gate strict'              , /* first one terminates      */
       '\ *.in.data:'                  , /* data from server          */
       '| g:'                          , /* stop at EoF or async cmd  */
       '| m: fanout'                   , /* 2nd copy for count        */
       Deblocker()                     , /* Post-processor            */
       xlata2e                         , /* translate ASCII-EBCDIC?   */
       '| *.out.0:'                    , /* output data               */
       tabla2e                         , /* translate table input?    */
       '\ m:'                          , /* output data               */
       '| count bytes'                 , /* waits till EoF            */
       '| var n'                       , /* save byte count           */
       '| i:'                          , /* close gate to stop pipe   */
copies('\ m:'                          , /* postprocessed output copy */
       '| addrdw cms4'                 , /* bytes in this record      */
       '| spec 1-4 c2d 1'              , /* convert to decimal        */
       '| literal 0'                   , /* start the counter         */
       '| spec a: w1 .'                , /* show the byte counter     */
              'print #0+=a picture' copies('z',ndigits-1)'9 1',
              '"bytes received" nw'    ,
       '| j: juxtapose'                , /* write each t seconds      */
       '| cons'                        , /* only if noisy is on       */
       '\ literal +'max(1, timeout%3)  , /* counters 3/timeout        */
       '| dup *'                       , /* could run for ever        */
       '| delay'                       , /* wait for it               */
       '| chop 0'                      , /* trigger juxtapose count   */
       '| g:'                          , /*                           */
       '| j:'      , echo?)            ; /* inject into cmd stream    */
    if RC = 0                            /* did subroutine work?      */
      then do                            /* yes, handle the response  */
        if echo?                         /* type summary record       */
          then do
            if length(n)>11
              then b=n
              else b=right(n, 11)
            numeric digits ndigits
            say b 'bytes received in',
            format(time('E'), ,2) 'seconds',
            '('format(n/(1024*time('E')), ,2)'KB/s)'
            end
        /* In stream mode, we must close the port.  RFC 1123 says we  */
        /* must do this for PASV mode too                             */
        if mode = 'S' | pasv?            /* server has given EoF by   */
          then call Datastream 0         /* closing the data stream   */
          else do                        /* server may have closed    */
            signal off error             /* the data stream           */
            'SELECT BOTH data'           /* select the stream         */
            'STREAMSTATE INPUT'          /* see if its useless now    */
            if RC = 12 then call Datastream 0
            end                          /*                           */
        RC = response()                  /* return code               */
        ok? = x00?(RC, 200)              /* expect 226 or maybe 250   */
        end                              /*                           */
      else do                            /* Subroutine failed!        */
        ok? = 0                          /* flag this                 */
        call Datastream 0                /* assume a broken stream    */
        end                              /*                           */
    end                                  /*                           */
  else call Datastream 0                 /* assume stream is broken   */
if ^ok? & ^tolerate? then CALL reject RC /* terminate on error?       */
if otype      ^= type      then call Command 'TYPE', otype, 1
if omode      ^= mode      then call Command 'MODE', omode, 1
if ostructure ^= structure then call Command 'STRU', ostructure, 1
return ok?                               /* transfer complete (or not)*/
 
STOR: STOU: APPE:
signal on syntax
signal off error                         /* handle errors manually    */
'SELECT INPUT 0'                         /* primary input stream      */
'STREAMSTATE INPUT'                      /* check if its at EoF       */
if RC = 12 then Signal TheEnd            /* terminate if so           */
if type = '' | mode = '' | structure = ''
  then call DefaultTypeModeStructure
ok? = DataStream(1, tolerate?)           /* ensure we've a data port  */
'SUSPEND'
if ok?                                   /* if we do                  */
  then do                                /*   then                    */
    RC = response(command, parameters)   /*     send the command      */
    ok? = x00?(RC, 100)                  /*     initial 100 response  */
    end                                  /*                           */
Select                                   /* Do we need to validate    */
  when ^accept? then nop                 /* the connection if it is   */
  when ok?                               /* via a socks bind?         */
    then do                              /* yes: get the record       */
      Select
        when proxy?
          then call  Accept 'data', 'data', proxyaddress, proxyport-1
        when external?
          then call rAccept 'data', 'data', address, port /* ! */,,
            , socksaddress, socksport
        otherwise           call  Accept 'data', 'data', address, port-1
        end
      ok? = result ^= ''
      end                                /*                           */
  otherwise accept? = 0                  /* there will be no response */
  end                                    /* sever the stream below    */
if ok?
  then do
    call xlatestages (type = 'A')        /* translate for ASCII       */
    call time('R')
    'CALLPIPE (name' ftp':'command 'end \ listerr)',
copies('\ *.in.1:'                     , /* command stream if in use  */
       '| drop 1'          , commands?), /* discard STOR/STOU/APPE    */
       '| i: faninany'                 , /* EoF on 1y or rec on 2y    */
       '| g: gate'                     , /* first one terminates      */
       '\ *.in.0:'                     , /* input data                */
       '| g:'                          , /* stop at EoF or command    */
       xlate2a                         , /* translate EBCDIC-ASCII?   */
       Blocker()                       , /* Pre-processor             */
       '| m: fanout stop anyeof'       , /* slow fanout for count     */
       '| n: fanoutwo'                 , /* second copy for count     */
       '| *.out.data:'                 , /* send to server            */
       table2a                         , /* translate table input?    */
       '\ m:'                          , /* need EoF to close gate    */
       '| count bytes'                 , /* waits till EoF            */
       '| var m'                       , /* save byte count           */
       '\ n:'                          , /* need EoF to close gate    */
       '| o: fanout stop anyeof'       , /* second copy for count     */
       '| count bytes'                 , /* waits till EoF            */
       '| var n'                       , /* save byte count           */
       '| i:'                          , /* EoF also triggers gate    */
copies('\ o:'                          , /* postprocessed output copy */
       '| addrdw cms4'                 , /* bytes in this record      */
       '| spec 1-4 c2d 1'              , /* convert to decimal        */
       '| spec a: w1 .'                , /* show the byte counter     */
              'print #0+=a picture' copies('z',ndigits-1)'9 1',
              '"bytes sent" nw'        ,
       '| j: juxtapose'                , /* write each t seconds      */
       '| cons'                        , /* only if noisy is on       */
       '\ literal +'timeout            , /* announce count every t s  */
       '| dup *'                       , /* could run for ever        */
       '| delay'                       , /* wait for it               */
       '| chop 0'                      , /* purely a trigger record   */
       '| g:'                          , /* stop at EoF               */
       '| j:'      , echo?)            ; /* inject into cmd stream    */
    Select
      when RC ^= 0                       /* Subroutine failed!        */
        then do                          /* assume error message said */
          ok? = 0                        /* flag this                 */
          call Datastream 0              /* assume a broken stream    */
          end                            /*                           */
      when n < m                         /* we didn't send everything */
        then do                          /* assume error message said */
          ok? = 0                        /* flag this                 */
          say 'Send operation terminated prematurely between byte' n,
              'and byte' m
          call Datastream 0              /* assume a broken stream    */
          end                            /*                           */
      otherwise                          /* yes, handle the response  */
        if echo?                         /* type summary record       */
          then do
            if length(n)>11
              then b=n
              else b=right(n, 11)
            numeric digits ndigits
            say b 'bytes sent in' format(time('E'), ,2),
              'seconds ('format((n/1024)/time('E'), ,2)'KB/s)'
          end
        /* Always sever the stream even in block mode because the VM  */
        /* server does not recognise the EoF bit grumble...grumble... */
        /* and also because RFC 1123 says we must have a new PASV     */
        /* command when in PASVM mode                                 */
        if mode = 'S' | 1                /* Must indicate EOF by      */
          then call Datastream 0         /* closing the data stream   */
        RC = response()                  /* return code               */
        ok? = x00?(RC, 200)              /* expect 226 or maybe 250   */
        end                              /*                           */
    end                                  /*                           */
  else call Datastream 0                 /* assume stream is broken   */
if ^ok? & ^tolerate? then CALL reject RC /* terminate on error?       */
return RC=0
 
 
/*--------------------------------------------------------------------*/
/* Rename                                                             */
/*  ⁄ƒƒƒø  RNFR    ⁄ƒƒƒø  1,2      ⁄ƒƒƒø                              */
/*  ≥ B ‰ƒƒƒƒƒƒƒƒƒ>≥ W ‰ƒƒƒƒƒƒƒƒƒƒ>≥ E ≥                              */
/*  ¿ƒƒƒŸ          ¿†ƒ†Ÿ        ⁄ƒ>¿ƒƒƒŸ                              */
/*           3      ≥ ≥  4,5    ≥                                     */
/*    ⁄ƒƒƒƒƒƒƒƒƒƒƒƒƒŸ ¿ƒƒƒƒƒƒƒø ≥                                     */
/*    ≥             ⁄ƒƒƒƒƒƒƒƒƒ≥ƒŸ  ⁄ƒƒƒø                              */
/*    ≥             ≥ ⁄ƒƒƒƒƒƒƒ≥ƒƒƒ>≥ S ≥                              */
/*    ≥             ≥ ≥       ≥    ¿ƒƒƒŸ                              */
/*    ≥          1,3≥ ≥2      ≥                                       */
/*    ≥             ≥ ≥       ≥                                       */
/*  ⁄ƒÖƒø  RNTO    ⁄ÖƒÖø      ¿ƒƒƒ>⁄ƒƒƒø                              */
/*  ≥   ‰ƒƒƒƒƒƒƒƒƒ>≥ W ‰ƒƒƒƒƒƒƒƒƒƒ>≥ F ≥                              */
/*  ¿ƒƒƒŸ          ¿ƒƒƒŸ   4,5     ¿ƒƒƒŸ                              */
/* RNFR needs a subroutine because it uses 300 as normal, RNTO does   */
/* not                                                                */
/*--------------------------------------------------------------------*/
Rename: procedure expose ftp (variables)
parse arg files, tolerate?
parse value dstring(files) with old files
parse value dstring(files) with new files
if ^arg(2, 'E') then tolerate? = 0
if command('RNFR', x2c(old), tolerate?)
  then ok? = command('RNTO', x2c(new), tolerate?)
  else ok? = 0
return ok?
 
RNFR:
signal on syntax
RC = response(command, parameters)
ok? = x00?(RC, 300)
if ^ok? & ^tolerate? then call reject RC
return ok?
 
/*--------------------------------------------------------------------*/
/* Restart                                                            */
/*  ⁄ƒƒƒø  RSTR    ⁄ƒƒƒø  1,2      ⁄ƒƒƒø                              */
/*  ≥ B ‰ƒƒƒƒƒƒƒƒƒ>≥ W ‰ƒƒƒƒƒƒƒƒƒƒ>≥ E ≥                              */
/*  ¿ƒƒƒŸ          ¿†ƒ†Ÿ        ⁄ƒ>¿ƒƒƒŸ                              */
/*           3      ≥ ≥  4,5    ≥                                     */
/*    ⁄ƒƒƒƒƒƒƒƒƒƒƒƒƒŸ ¿ƒƒƒƒƒƒƒø ≥                                     */
/*    ≥             ⁄ƒƒƒƒƒƒƒƒƒ≥ƒŸ  ⁄ƒƒƒø                              */
/*    ≥             ≥ ⁄ƒƒƒƒƒƒƒ≥ƒƒƒ>≥ S ≥                              */
/*    ≥             ≥ ≥       ≥    ¿ƒƒƒŸ                              */
/*    ≥            3≥ ≥2      ≥                                       */
/*    ≥             ≥ ≥       ≥                                       */
/*  ⁄ƒÖƒø  cmd     ⁄ÖƒÖø      ¿ƒƒƒ>⁄ƒƒƒø                              */
/*  ≥   ‰ƒƒƒƒƒƒƒƒƒ>≥ W ‰ƒƒƒƒƒƒƒƒƒƒ>≥ F ≥                              */
/*  ¿ƒƒƒŸ      ⁄ƒƒ>¿†ƒƒŸ   4,5     ¿ƒƒƒŸ                              */
/*            1≥    ≥                                                 */
/*             ¿ƒƒƒƒŸ                                                 */
/* cmd is RETR, STOR or APPE                                          */
/*--------------------------------------------------------------------*/
Restart: procedure expose ftp (variables)
arg , command
parse arg marker , , parameters, tolerate?
if ^arg(4, 'E') then tolerate? = 0
if command('RSTR', marker, tolerate?)
  then ok? = command(command, parameters, tolerate?)
  else ok? = 0
 
RSTR:
signal on syntax
RC = response(command, parameters)
ok? = x00?(RC, 300)
if ^ok? & ^tolerate? then call reject RC
return ok?
 
/*--------------------------------------------------------------------*/
/* Login                                                              */
/*                                                                    */
/*                   ⁄ƒƒƒƒƒƒƒƒƒƒƒƒƒƒ>⁄ƒƒƒø                            */
/*                  1≥          ⁄ƒƒƒ>≥ E ≥                            */
/*  ⁄ƒƒƒø  USER    ⁄ƒÖƒø  2     ≥⁄ƒƒ>¿ƒƒƒŸ                            */
/*  ≥ B ‰ƒƒƒƒƒƒƒƒƒ>≥ W ‰ƒƒƒƒƒƒø ≥≥                                    */
/*  ¿ƒƒƒŸ          ¿†ƒ†Ÿ      ≥ ≥≥                                    */
/*           3      ≥ ≥ 4,5   ≥ ≥≥                                    */
/*    ⁄ƒƒƒƒƒƒƒƒƒƒƒƒƒŸ ¿ƒƒƒƒƒø ≥ ≥≥                                    */
/*    ≥              ⁄ƒƒƒƒƒƒ≥ƒ≥ƒŸ≥                                    */
/*    ≥              ≥      ≥ ≥  ≥                                    */
/*    ≥              ≥      ≥ ≥  ≥                                    */
/*    ≥             1≥      ≥ ≥  ≥                                    */
/*    ≥              ≥      ≥ ≥  ≥                                    */
/*  ⁄ƒÖƒø  PASS    ⁄ƒÖƒø 2  ≥ ¿ƒƒ≥ƒƒ>⁄ƒƒƒø                            */
/*  ≥   ‰ƒƒƒƒƒƒƒƒƒ>≥ W ‰ƒƒƒƒ≥ƒƒƒƒ≥ƒƒ>≥ S ≥                            */
/*  ¿ƒƒƒŸ          ¿†ƒ†Ÿ    ≥    ≥⁄ƒ>¿ƒƒƒŸ                            */
/*           3      ≥ ≥ 4,5 ≥    ≥≥                                   */
/*    ⁄ƒƒƒƒƒƒƒƒƒƒƒƒƒŸ ¿ƒƒƒø ≥    ≥≥                                   */
/*    ≥             ⁄ƒƒƒƒƒ≥ƒ≥ƒƒƒƒŸ≥                                   */
/*    ≥             ≥ ⁄ƒƒƒ≥ƒ≥ƒƒƒƒƒŸ                                   */
/*    ≥             ≥ ≥   ≥ ≥                                         */
/*    ≥          1,3≥ ≥2  ≥ ≥                                         */
/*    ≥             ≥ ≥   ≥ ¿ƒƒƒƒƒƒƒ>⁄ƒƒƒø                            */
/*  ⁄ƒÖƒø  ACCT    ⁄ÖƒÖø  ¿ƒƒƒƒƒƒƒƒƒ>≥ F ≥                            */
/*  ≥   ‰ƒƒƒƒƒƒƒƒƒ>≥ W ‰ƒƒƒƒƒƒƒƒƒƒƒƒ>¿ƒƒƒŸ                            */
/*  ¿ƒƒƒŸ          ¿ƒƒƒŸ                                              */
/*                                                                    */
/*--------------------------------------------------------------------*/
Login: procedure expose ftp (variables)
parse arg u, p, a, tolerate?
if ^arg(4, 'E') then tolerate? = 0
if command('USER', u, tolerate?)
  then if x00?(RC, 300)
    then do
      Select
        when arg(2, 'E') then nop
        when abbrev(translate(u), 'ANONYMOUS', 8) then p = email()
        when disc?() then ok? = 0
        otherwise
        /*------------------------------------------------------------*/
        /* Read password?  Prompt if it wasn't echoed already         */
        /*------------------------------------------------------------*/
          if ^echo?
            then 'CALLPIPE (name' ftp':Prompt) stem response.|cons'
          'CALLPIPE console dark|locate w1|take 1|var p'
        end
      if command('PASS', p, tolerate?)
        then if x00?(RC, 300)
          then ok? = command('ACCT', a, tolerate?)
          else ok? = 1
        else ok? = 0
      end
    else ok? = 1
  else ok? = 0
return ok?
 
USER: PASS:
signal on syntax
RC = response(command, parameters)
ok? = x00?(RC, 200) | x00?(RC, 300)
if ^ok? & ^tolerate? then call reject RC
return ok?
 
/*--------------------------------------------------------------------*/
/* Response: get the code & response text from a single FTP command   */
/*           Allow one interim 100 response where allowed             */
/*--------------------------------------------------------------------*/
Response: procedure expose ftp (variables) response. response?
signal on error name NoControl
arg command .
parse arg , parameters
'SELECT BOTH ctl'
if command ^= ''
  then do
    if parameters ^= ''
      then 'OUTPUT' command parameters
      else 'OUTPUT' command
    end
'CALLPIPE (name' ftp':ControlJunk end \ listerr)',
        'strliteral "+'timeout'"'      , /* the host: timeout secs    */
      '| delay'                        , /* wait for response         */
      '| g: gate strict'               , /* stop this pipe if nothing */
      '\ *.in.ctl:'                    , /* control stream            */
      '| g:'                           , /* timeout switch            */
      '| v: verify 1.3 "0123456789"'   , /* select valid numbered...  */
      '| p: pick 1.3 >>= "100"'        , /* response records only...  */
      '| q: pick 1.3 <<  "600"'        , /* by inspecting cols 1-3    */
      '| spec "*" 1 1-* n'             , /* prefix flag character     */
      '| i: faninany'                  , /* get back unnumbered       */
      '| strtolabel "*"'               , /* before response!  weird?  */
      '| *.out.1:'                     , /* output if needed          */
      '\ v:'                           , /* not numeric               */
      '| i:'                           , /* back with numbered        */
      '\ p:'                           , /* nnn < 100  (!)            */
      '| i:'                           , /* back with numbered        */
      '\ q:'                           , /* nnn ^< 600 (!)            */
      '| i:'                           ; /* back with numbered        */
 
/*--------------------------------------------------------------------*/
/* Did we actually get a record?                                      */
/*--------------------------------------------------------------------*/
signal off error                         /* Manual error handling     */
'STREAMSTATE INPUT'                      /* check control stream      */
Select                                   /*                           */
  when RC = 12 then signal NoControl     /* Control stream closed     */
  when RC ^= 0                           /* timeout occurred          */
    then do                              /* report it                 */
      say 'Remote host did not respond within' timeout,
          'second timeout period'
      if ^tolerant? then signal TheEnd   /* terminate on error        */
      end                                /*                           */
  otherwise                              /* Stream waiting no timeout */
    'EOFREPORT ANY'                      /* to catch EoF on *.out.1:  */
    'PEEKTO record'                      /* must set value of record  */
    Select                               /* test for EoF              */
      when RC = 0 then nop               /* no EoF                    */
      when ^responses? then nop          /* must have been *.out.0:   */
      otherwise                          /* could have been *.out.1:  */
        'SELECT OUTPUT 1'                /* choose that               */
        'STREAMSTATE OUTPUT'             /* test it                   */
        if RC = 12 then signal TheEnd    /* if EoF, propagate back    */
      end                                /*                           */
    parse var record nnn 4 x 5           /* known to be nnn record    */
    if x ^= '-'                          /* single line response      */
      then 'CALLPIPE (name' ftp':code'nnn ') *.in.ctl:',
                  '| take 1',
                  '| stem response.',
           copies('| *.out.1:', response?)
      else do
        'CALLPIPE (name' ftp':code'nnn'- end \ listerr)',
              'strliteral "+'timeout'"', /* the host: timeout secs    */
            '| delay'                  , /* wait for response         */
            '| g: gate strict'         , /* stop this pipe if nothing */
            '\ *.in.ctl:'              , /* control stream            */
            '| g:'                     , /* timeout switch            */
            '| s: strtolabel "'nnn '"' , /* up to "nnn " record       */
            '| i: faninany'            , /* get "nnn " record back    */
            '| stem response.'         , /* save a copy for errors    */
     copies('| *.out.1:', response?)   , /* output if needed          */
            '\ s:'                     , /* valid nnn response        */
            '| take 1'                 , /* only want the first one   */
            '| c: count lines'         , /* concert to record count   */
            '| i:'                     , /* with the rest of response */
            '\ c:'                     , /* did we get a last "nnn "? */
            '| var final?'             ; /* save as flag              */
        if ^final?
          then do
            say 'Remote host did not complete response within' timeout,
                'second timeout period'
            RC = 8
            if ^tolerant? then signal TheEnd
            end
        end
    if responses?                        /* Using secondary output    */
      then do                            /* yes, check if its at EoF  */
        'SELECT OUTPUT 1'                /* and if so propagate back  */
        'STREAMSTATE OUTPUT'             /* select the stream         */
        if RC = 12                       /* We have EoF: propagate it */
          then do                        /* back.  Switch off the     */
            responses? = 0               /* responses? flag so that   */
            if nnn // 100 ^= 21 then signal TheEnd /* don't do twice  */
            end                          /*                           */
        end                              /*                           */
    if nnn // 100 = 21                   /* For 221 and 421 responses */
      then call CloseControl             /* we close our stream to    */
      else do                            /* else we test it and if    */
        'SELECT OUTPUT ctl'              /* its at EoF (ie. abnormal) */
        'STREAMSTATE OUTPUT'             /*                           */
        if RC = 12 then Signal NoControl /* end if at EoF             */
        end                              /*                           */
  end
if RC ^= 0 then nnn = RC // 100          /* 0xx is unexpected error   */
return nnn
 
/*--------------------------------------------------------------------*/
/* NoControl: add error recovery here for loss of control connection  */
/*            signalled from Response:                                */
/*--------------------------------------------------------------------*/
NoControl:
say 'Unexpected loss of control connection, aborting transfer'
connected? = 0
if ^tolerant? then signal TheEnd
return 421 /* 421 is a reasonable transient error code for this        */
 
/*--------------------------------------------------------------------*/
/* reject: when FTP command ends in a bad Error or Failure condition  */
/*--------------------------------------------------------------------*/
Reject: procedure expose ftp (variables) response.
arg eRC
signal off error
if ^echo? then 'CALLPIPE (name' ftp':Reject) stem response.|cons'
'CALLPIPE var eRC|(nomsg 15) aggrc'
signal TheEnd
 
/*--------------------------------------------------------------------*/
/* reject: when FTP command ends in a bad Error or Failure condition  */
/*--------------------------------------------------------------------*/
RejectCommand: procedure expose ftp (variables)
arg result
say 'Unrecognised Command:' result
RC = 8
signal TheEnd
 
/*--------------------------------------------------------------------*/
/* x00?(xyz, x00) is an FTP return code in the desired range          */
/*--------------------------------------------------------------------*/
x00?: return arg(1) % 100 == arg(2) / 100
 
/* Parse a Pipeline delimited string from the front of a string       */
/* return the dstring in hex and the remainder in char                */
dstring: procedure expose ftp (variables)
parse arg string
string = strip(string)
Select
  when string = '' then call PipeErrorMsg 113
  when abbrev('STRING', translate(word(string, 1)), 3)
    then string = subword(string, 2)
  when verify(string, 'xXhH', 'Match') = 1  then return xstring(string)
  when verify(string, 'bB', 'Match')   = 1  then return bstring(string)
  otherwise
  end
parse value string with d 2 string (d) +0 c +1 rest
Select
  when d = ''  then call PipeErrorMsg 156
  when d ^== c then call PipeErrorMsg 60, , string
  when string == '' then return ' 'rest
  otherwise return c2x(string) rest
  end
 
/* Parse a word as a hexadecimal delimited string                     */
/* return the dstring in hex and the remainder in char                */
xstring: procedure expose ftp (variables)
parse arg x 2 string rest
Select
  when string = ''              then call PipeErrorMsg  64, , 'x'
  when ^datatype(string, 'X')   then call PipeErrorMsg  65, , string
  when length(string) // 2 ^= 0 then call PipeErrorMsg 335, , string
  otherwise return string rest
  end
 
/* Parse a word as a binary delimited string                     */
/* return the dstring in hex and the remainder in char                */
bstring: procedure expose ftp (variables)
parse arg b 2 string rest
Select
  when string = ''              then call PipeErrorMsg 337, , 'b'
  when ^datatype(string, 'B')   then call PipeErrorMsg 338, , string
  when length(string) // 8 ^= 0 then call PipeErrorMsg 336, , string
  otherwise return b2x(string) rest
  end
 
telnetcodes:
_EOR  = 'xEF'; _IAC_EOR  = 'xFFEF'      /* End of Record              */
_SE   = 'xF0'; _IAC_SE   = 'xFFF0'      /* Subnegotiation End         */
_NOP  = 'xF1'; _IAC_NOP  = 'xFFF1'      /* No Operation               */
_DM   = 'xF2'; _IAC_DM   = 'xFFF2'      /* Data Mark                  */
_BRK  = 'xF3'; _IAC_BRK  = 'xFFF3'      /* Break                      */
_IP   = 'xF4'; _IAC_IP   = 'xFFF4'      /* Interrupt Process          */
_AO   = 'xF5'; _IAC_AO   = 'xFFF5'      /* Abort output               */
_AYT  = 'xF6'; _IAC_AYT  = 'xFFF6'      /* Are You There              */
_EC   = 'xF7'; _IAC_EC   = 'xFFF7'      /* Erase character            */
_EL   = 'xF8'; _IAC_EL   = 'xFFF8'      /* Erase Line                 */
_GA   = 'xF9'; _IAC_GA   = 'xFFF9'      /* Go ahead                   */
_SB   = 'xFA'; _IAC_SB   = 'xFFFA'      /* Subnegotiation Begin (opt) */
_WILL = 'xFB'; _IAC_WILL = 'xFFFB'      /* WILL (option code)         */
_WONT = 'xFC'; _IAC_WONT = 'xFFFC'      /* WON'T (option code)        */
_DO   = 'xFD'; _IAC_DO   = 'xFFFD'      /* DO (option code)           */
_DONT = 'xFE'; _IAC_DONT = 'xFFFE'      /* DON'T (option code)        */
_IAC  = 'xFF'; _IAC_IAC  = 'xFFFF'      /* Interpret as Command       */
return
 
/*--------------------------------------------------------------------*/
/* email: what's my mailbox                                           */
/*--------------------------------------------------------------------*/
email: procedure expose ftp (variables)
signal off error
Address COMMAND 'IDENTIFY (LIFO'; pull me . here .
'CALLPIPE (name' ftp':NameFind end \)',
     'command NAMEFIND :userid' me ':node' here ':tcpaddr :csaddr',
   '| var tcpaddr',
   '| drop 1',
   '| var csaddr';
if RC ^= 0 then parse value '' with with tcpaddr csaddr
'CALLPIPE (name' ftp':TCPdata end \)',
     'state TCPIP DATA *'            /* "hostbyaddr" uses this        */
If RC = 0 then
  'CALLPIPE (name' ftp':DNSaddr end \)',
       'hostid',
     '| hostbyaddr',
     '| insert "'me'@"',
     '| append literal',
     '| var dnsaddr';
else dnsaddr = ''
Select
  when csaddr ^= '' & external? then return csaddr
  when tcpaddr ^= '' & ^external? then return tcpaddr
  when dnsaddr ^= '' then return dnsaddr
  otherwise return me'@'here
  end
 
/* disc?: return 1 if disconnected, 0 otherwise                       */
disc?: return substr(diag(24,-1),13,1) = 2
 
PipeErrorMsg: /* RC [, [number] [, dstring [, dstring...]]]           */
call trace 'o'
signal off error
signal off failure
result = ''                          /* result as a scratch variable  */
do RC = 3 to arg()                   /* so is RC                      */
  result = result 'x'||c2x(arg(RC))
  end
if arg(2, 'E')
  then 'ISSUEMSG' arg(2) 'PIPFTP' result
  else 'ISSUEMSG' arg(1) 'PIPFTP' result
RC = arg(1)
if RC ^= 0 & RC ^=4 then signal TheEnd /* Exit with fatal return code */
return
 
/*--------------------------------------------------------------------*/
/* Check that we don't have lead pipes                                */
/* hostbyname appeared in 1.0110x07 which is the minimum level        */
/*--------------------------------------------------------------------*/
CheckPlumbing:
trace o
signal off error
signal off failure
Address Command
'PIPE literal hostbyname|runpipe'
eSIGL = SIGL
Select
  when RC = 0 then return
  when RC = -2672
    then do
      say
      say 'You are running a level of CMS which has a version of CMS',
          'Pipelines which is'
      say 'too low for the TCP/IP functions needed by' ftp'. ',
          'Your Pipeline version is:'
      'PIPE query version'
      say
      say 'Your CMS level and release are:'
      'QUERY CMSLEVEL'
      'QUERY CMSREL'
      say
      say 'You should try to use the "field test" version by issuing',
          'this command:'
      say 'PICKPIPE Uplevel'
      say
      end
  when RC = -27 & pipelevel() << '110A'x
    then do
      say
      say 'You are running a level of the "field test" version of CMS',
          'Pipelines which is'
      say 'too low for the TCP/IP functions needed by' ftp'. ',
          'Your Pipeline version is:'
      'PIPE query version'
      say
      say 'Please contact your systems support staff for assistance'
      say
      end
  when RC = -27
    then do
      say
      say 'You are running a level of CMS Pipelines which is too low',
         'for the TCP/IP'
      say 'functions needed by' ftp'.  Your Pipeline version is:'
      'PIPE query version'
      say
      say 'Your CMS level and release are:'
      'QUERY CMSLEVEL'
      'QUERY CMSREL'
      say
      say 'You may find that loading the "field test" version will',
          'solve this'
      say 'problem.  Issue this command:'
      say 'PICKPIPE Uplevel'
      say
   end
   otherwise
   end
Address
'ISSUEMSG 27 PIPSJH "HOSTBYNA"'
exit -27
 
PipeLevel:
'PIPE query level|spec 1-* c2x 1.4|var result'
return result
 
/*--------------------------------------------------------------------*/
/* trace!: Common Trace Control Procedure for REXX EXECs              */
/*                                                                    */
/* To Enable  : Issue GLOBALV SELECT ft    SET fn  mode               */
/*    Tracing :    or GLOBALV SELECT TRACE SET fn  mode               */
/*                 or GLOBALV SELECT ft    SET key mode               */
/*                 or GLOBALV SELECT TRACE SET key mode               */
/*                where:  fn   - is the filename of the exec          */
/*                        ft   - is the filetype of the exec          */
/*                        mode - is the REXX trace mode desired       */
/* Returns    : a trace setting.                                      */
/* Invoke as  : CALL trace trace!() or CALL trace trace!(key)         */
/*--------------------------------------------------------------------*/
trace!: PROCEDURE
parse source . . fn ft .
arg key
if key = ''
  then parse upper value value(fn , ,'GLOBAL' ft) ,
                         value(fn , ,'GLOBAL TRACE') with tracer .
  else parse upper value value(key, ,'GLOBAL' ft) ,
                         value(key, ,'GLOBAL TRACE') with tracer .
Select
  when abbrev('OFF',  tracer,  1) then nop
  when cmsflag('EXECTRAC')      then tracer = strip(trace(),  'L',  '?')
  when tracer = ''              then tracer = 'N'
  otherwise
  end
Select
  when left(tracer, 1) = 'N' ,
     | left(tracer, 1) = 'O' then nop
  when key = ''              then say 'Running' fn ft
  otherwise                       say 'Running' fn ft '(trace' key')'
  end
RETURN tracer
 
error: say ftp': Unexpected error at' SIGL'. RC='RC 'from' condition('D')
RC = 10000 + RC
SIGNAL TheEnd
failure:
say ftp': command failure at' SIGL'. RC='RC 'from' condition('D')
SIGNAL TheEnd
novalue:
say ftp': undefined variable at line' SIGL':' condition('D')
RC = 20000
SIGNAL TraceBack
halt:
say ftp':' errortext(4) 'at line' SIGL
RC = 20004
SIGNAL TheEnd
syntax:
say ftp': Syntax error' RC 'at line' SIGL':' errortext(RC) condition('D')
RC = 20000 +RC
SIGNAL TraceBack
