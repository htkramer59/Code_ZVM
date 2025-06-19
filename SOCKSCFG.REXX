/*--------------------------------------------------------------------*/
/* (c) Copyright International Business Machines Corporation 1997.    */
/* All rights reserved.                                               */
/*                                                                    */
/* SOCKSCFG REXX -- return a socks server for an IP address           */
/*                                                                    */
nop /*----------------------------------------------------------------*/
/*                                                                    */
/* SOCKSGFG reads the SOCKS CONFIG file by default                    */
/* The config file is searched using slightly different rules from    */
/* the OS/2 equivalent: rather than testing against each statement    */
/* in order, for the direct and sockd sections, each section is       */
/* searched on a "longest match is best basis".  SOCKSCFG still       */
/* supports non-contiguous masks: the actual order is numerical in    */
/* unsigned 32-bit arithmetic, which equates to longest when masks    */
/* are contiguous. This might result in minor differences in the case */
/* where there are many sockd lines but is highly unlikely for any    */
/* realistic configuration.  Otherwise SOCKS CONFIG follows the OS/2  */
/* rules except that it also treats lines starting # as comment       */
/* lines to tolerate a UNIX flavour config with # directives and      */
/* ignores blank lines.  Otherwise the file must consist solely of a  */
/* series of direct statements then a series of sockd statements      */
/*                                                                    */
/* You will need a suitable SOCKS CONFIG file. This can be taken from */
/* an UNIX socks.conf file or similar                                 */
/*                                                                    */
/* Socks support must be enabled by setting the variable SOCKS_FLAG   */
/* to ON in GLOBALV group SOCKS                                       */
/*                                                                    */
/* The TCPIP DATA file should contain the IP address of a name server */
/* which can resolve external names as the first NSINTERADDR entry.   */
/* This IP address is often the same as the address of the socks      */
/* server. Most VM systems behind firewalls will use a name server    */
/* limited to internal names. The system-wide TCPIP DATA is normally  */
/* on TCPMAINT's 592 disk. You may need to copy this to your A-disk   */
/* and modify it.                                                     */
/*                                                                    */
/* Input stream:  IP addresses in dotted decimal (or host names if    */
/*                pipelines are at 1.0110 x07)                        */
/* Output stream: sockd address (name or IP address) if any or null   */
/*                otherwise.                                          */
/* Record delay:  SOCKSCFG does not delay the record.                 */
/*                                                                    */
/*--------------------------------------------------------------------*/
/* Steve Hayes, IBM Global Services NS EMEA SNA I&S      TSGSH@GFORD1 */
/* Release: 0.99   SJH Beta version                        1997-03-20 */
/*--------------------------------------------------------------------*/
Signal on Novalue                        /* No uninitialised varibles */
Signal on Failure                        /* Allow RC > 0 for a moment */
'MAXSTREAM INPUT'                        /* Check only one stream     */
Signal On Error                          /* now stop for any error    */
if RC ^= 0 then 'ISSUEMSG 264 PIPSJH'    /* too many streams: crash   */
parse source . . !fn .                   /* for name of pipe          */
parse arg fn ft fm                       /* config file passed as arg */
if fn = '' then fn = 'SOCKS'             /* default is SOCKS CONFIG   */
if ft = '' then ft = 'CONFIG'            /* filemode defaults to ''   */
'CALLPIPE (name' !fn 'end \)'          , /* One subroutine            */
       '*:'                            , /* input records             */
     '| (nomsg 15) tcpdots'            , /* convert to character      */
     '| a: fanout'                     , /* 3 copies                  */
     '| spec "*" 1 1-* 2'              , /* dummy record for no match */
     '| b: faninany'                   , /* get matches worst to best */
     '| c: juxtapose'                  , /* keep the best one         */
     '| d: strfind "*"'                , /* no direct found try sockd */
     '| not chop 1'                    , /* remove * marking failure  */
     '| e: fanout'                     , /* 3 copies                  */
     '| chop 0'                        , /* no sockd if not found     */
     '| f: faninany'                   , /* get matches worst to best */
     '| g: juxtapose'                  , /* keep the best one         */
     '| h: faninany'                   , /* get matches worst to best */
     '| *:'                            , /* output socks record       */
     '\ d:'                            , /* did get a direct, skip    */
     '| h:'                            , /* sockd lookup              */
     '\ a:'                            , /* 2nd copy for lookup       */
     '| spec 1-* c2b 1 " " n'          , /* convert to binary + blank */
     '| s: sync'                       , /* in step with direct masks */
     '| j: juxtapose'                  , /* one per address/mask pair */
     '| split'                         , /* split address and mask    */
     '| combine and'                   , /* wipe out host bits        */
     '| xlate 00 40'                   , /* convert them to blanks    */
     '| l: lookup 1-32 master'         , /* find direct for each mask */
     '| not chop 32'                   , /* get direct value only     */
     '| b:'                            , /* replace last match        */
     '\ a:'                            , /* 3rd copy for end of record*/
     '| chop 0'                        , /* convert to null trigger   */
     '| c:'                            , /* fire juxtapose            */
     '\ e:'                            , /* 2nd copy for lookup       */
     '| spec 1-* c2b 1 " " n'          , /* convert to binary + blank */
     '| t: sync'                       , /* in step with sockd masks  */
     '| k: juxtapose'                  , /* one per address/mask pair */
     '| split'                         , /* split address and mask    */
     '| combine and'                   , /* wipe out host bits        */
     '| xlate 00 40'                   , /* convert to blanks         */
     '| m: lookup 1-32 master'         , /* find sockd for each mask  */
     '| not chop 32'                   , /* get sockd value only      */
     '| f:'                            , /* replace last match        */
     '\ e:'                            , /* 3rd copy for end of record*/
     '| chop 0'                        , /* convert to null trigger   */
     '| g:'                            , /* fire juxtapose            */
     '\ <' fn ft fm                    , /* read config               */
     '| strnfind "#"'                  , /* discard # directives...   */
     '| locate w1'                     , /* ...and blank lines        */
     '| v: not strwhilelabel anycase "direct "' , /* block of directs */
     '| w: not strwhilelabel anycase "sockd "'  , /* block of sockds  */
     '\ v:'                            , /* direct lines from config  */
     '| buffer'                        , /* avoid stall               */
     '| o: fanout'                     , /* extra copy for mask list  */
     '| spec w2 1 write w3 1'          , /* write net then mask       */
     '| tcpdots'                       , /* convert to character      */
     '| spec 1-* c2b 1'                , /* convert to binary         */
     '| join " "'                      , /* join net & mask           */
     '| xlate w2 1 FF 0 00'            , /* convert mask to FF/00     */
     '| split'                         , /* separate again            */
     '| combine and'                   , /* wipe out host bits        */
     '| xlate 00 40'                   , /* convert to spaces         */
     '| l:'                            , /* for lookup                */
     '\ o:'                            , /* all direct entries        */
     '| spec w-1 1'                    , /* just the masks            */
     '| tcpdots'                       , /* convert to character      */
     '| sort unique'                   , /* "shortest" to "longest"   */
     '| spec 1-* c2b 1'                , /* convert to binary         */
     '| xlate *-* 1 FF 0 00'           , /* mask for binary string    */
     '| join * " "'                    , /* complete set in one go    */
     '| dup *'                         , /* generate infinite supply  */
     '| s:'                            , /* one set per address       */
     '| split'                         , /* one record per combo      */
     '| j:'                            , /* create address/mask pairs */
     '\ w:'                            , /* sockd lines from config   */
     '| buffer'                        , /* avoid stall               */
     '| p: fanout'                     , /* two extra copies needed   */
     '| spec w3 1 write w4 1'          , /* write net then mask       */
     '| tcpdots'                       , /* convert to character      */
     '| spec 1-* c2b 1'                , /* convert to binary         */
     '| join " "'                      , /* join net & mask           */
     '| xlate w2 1 FF 0 00'            , /* convert mask to FF/00     */
     '| split'                         , /* separate again            */
     '| combine and'                   , /* wipe out host bits        */
     '| xlate 00 40'                   , /* convert to spaces         */
     '| q: juxtapose'                  , /* append socks server       */
     '| m:'                            , /* to lookup                 */
     '\ p:'                            , /* all sockd lines           */
     '| not chop after string "@="'    , /* discard "sockd @="        */
     '| chop before blank'             , /* just sockd address        */
     '| q:'                            , /* append to net & mask      */
     '\ p:'                            , /* all direct entries        */
     '| spec w-1 1'                    , /* just the masks            */
     '| tcpdots'                       , /* convert to character      */
     '| sort unique'                   , /* "shortest" to "longest"   */
     '| spec 1-* c2b 1'                , /* convert to binary         */
     '| xlate *-* 1 FF 0 00'           , /* mask for binary string    */
     '| join * " "'                    , /* complete set in one go    */
     '| dup *'                         , /* generate infinite supply  */
     '| t:'                            , /* one set per address       */
     '| split'                         , /* one record per combo      */
     '| k:'                            ; /* create address/mask pairs */
Failure:
Error:
exit RC
