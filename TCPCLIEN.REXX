/*--------------------------------------------------------------------*/
/* (c) Copyright International Business Machines Corporation 1997.    */
/* All rights reserved.                                               */
/*                                                                    */
/* TCPCLIENt REXX -- Socksified, DNS and services aware front-end to  */
/*                   TCPCLIENT                                        */
/*                                                                    */
nop /*----------------------------------------------------------------*/
/*                                                                    */
/* Socks configuration follows the standard Unix, OS/2 etc. model     */
/*                                                                    */
/* SOCKS.CONF/CFG on VM is SOCKS CONFIG * and follows the same rules  */
/* The SOCKS.ENV file from OS/2 is replaced by GLOBALV group SOCKS    */
/* and the following variables are inspected as needed:               */
/*    SOCKS_FLAG     ON or OFF                                        */
/*    SOCKS_USER     userid     (default is userid())                 */
/*    SOCKS_SERVER   userid     (if SOCKSCFG does not exist)          */
/* Because TCP/IP/RXSOCKET/Pipelines DNS support does not support a   */
/* split DNS for SOCKS: the name server in TCPIP DATA must be able to */
/* resolve external names and the following SOCKS.ENV variables are   */
/* ignored.                                                           */
/*    SOCKS_DOMAIN                                                    */
/*    SOCKS_NS                                                        */
/*                                                                    */
/* Socks-connect code was originally John H's                         */
/*                                                                    */
/* Note:                                                              */
/* Note: SOCKS must be manually enabled for each userid using         */
/* Note:                                                              */
/* Note:   GLOBALV SELECT SOCKS SETP SOCKS_FLAG ON                    */
/* Note:                                                              */
/* Note: and either creating a SOCKS CONFIG file, or using            */
/* Note:                                                              */
/* Note:   GLOBALV SELECT SOCKS SETP SOCKS_SERVER hostname_or_IPaddr  */
/* Note:                                                              */
/*                                                                    */
/*--------------------------------------------------------------------*/
/* Steve Hayes, IBM Global Services NS EMEA SNA I&S      TSGSH@GFORD1 */
/* Release: 0.99   SJH Beta version                        1997-03-07 */
/*--------------------------------------------------------------------*/
Signal on Novalue                        /* No uninitialised varibles */
Signal on Failure                        /* Allow RC > 0 for a moment */
'MAXSTREAM OUTPUT'                       /* Check only one stream     */
Signal On Error                          /* now stop for any error    */
Select
  when RC = 0 then secondary? = 0        /*                           */
  when RC > 1 then 'ISSUEMSG 264 PIPSJH' /* too many streams: crash   */
  otherwise
    'STREAMSTATE INPUT 1'
    if RC ^= 12 then 'ISSUEMSG 539 PIPSJH "INPUT" "1"'
    secondary? = 1
  end
parse arg server port options
if port = '' then 'ISSUEMSG 113 PIPESJH'  
parse source . . fn .  
 
services? = ^datatype(port, 'W')
if services?
  then do  
    socketset = left(fn, 8)
    socketactive? = words(socket('socketsetlist')) > 1
    if ^socketactive? then call socket 'initialise', socketset
    parse value socket('getservbyname', port, 'TCP') with RC . port . 1 . errortext
    if RC > 0 
      then do  
        say errortext
        signal error
        end
    if ^socketactive? then call socket 'terminate', socketset
    end
if translate(value('SOCKS_FLAG',, 'GLOBAL SOCKS') = 'ON')    
  then if stream('SOCKS CONFIG *', 'c', 'query exists') ^= ''
    then 'CALLPIPE var server|sockscfg|var socks'
    else socks = value('SOCKS_SERVER',, 'GLOBAL SOCKS')
  else socks = ''
if socks ^= ''                              /* hostname or IP address */
  then 'callpipe (end \ name' fn':socks)' , /* Socksified tcpclient   */
          '|  *..0:'                      , /* send stream            */
          '| f: fanin 1 0'                , /* preface socks header   */
          '| t: tcpclient' socks 1080 options, /* TCP client          */
          '| d: drop 8 bytes'             , /* socks server response  */
          '| *..0:'                       , /* receive stream         */
          '\ d:'                          , /* socks response         */
          '| spec 1-2 c2x 1'              , /* to hex                 */
          '| l: lookup 1.4 master'        , /* code to message        */
          '| strnfind "005A"'             , /* discard if OK          */
          '| c: chop after blank'         , /* split into code & text */
          '| spec w1  x2d'                , /* convert to return code */
          '| (nomsg 15) aggrc'            , /* and set                */
          '\ c:'                          , /* ^zero code from server */
          '| cons'                        , /* write out if not       */
          '\ literal 005A SOCKS request OK.',
          '| literal 005B SOCKS request rejected or failed.',
          '| literal 005C SOCKS request rejected because server cannot connect to identd on the client.',
          '| literal 005D SOCKS request rejected because the client program and identd report different user-ids.',
          '| l:'                          ,
          '| insert "Unexpected SOCKS server reply: 0x"',
          '| cons'                        ,
          '\ strliteral "AF_INET' port server'"',
          '| ip2socka'                    ,
          '| spec x0401 1 3.6 n "'word(value('SOCKS_USER', , 'GLOBAL SOCKS') userid(), 1)'" n x00 n',
          '| f:'                          ,
   copies('\ t: | *..1:', secondary?)     ; /* secondary stream used? */
  else 'callpipe (end \ name' fn':direct)', /* direct tcpclient       */
          '| *..0:'                       , /* send stream            */
          '| t: tcpclient' server port options, /* TCP client         */
          '| *..0:'                       , /* receive stream         */
   copies('\ t: | *..1:', secondary?)     ; /* secondary stream used? */
Failure:
Error:
Exit RC
