/* NTPQ     REXX     Get raw time from NTPD (RFC-5905)               */
/*                   Author: Rob van der Heij, 25 Apr 2014           */
 
arg stack .                           /* The TCPIP stack to use      */
parse value stack 'TCPIP' with stack .
 
'callpipe (end \ name NTPQ.REXX:7)',  /* Use TOD as unsigned 64-bit  */
   '\ literal :tod u64 u 1.8',
   '| literal :tod4 t1 u 1.8 t2 u 9.8 t3 u 17.8 t4 u 25.8',
   '| literal :time secs u 1.4 frac u 5.4',
   '| structure add'
 
'callpipe (end \ name NTPQ.REXX:7)',
   '\ *:',                            /* NTPD server address         */
   '| p: fanout',
   '| copy',
   '| pad 16',
   '| x: spec 1-* 1 select 1 1-* n',
   '| *:',
   '\ p:',
   '| spec ,AF_INET 123, 1 w1 nw ',   /* UDP port 123                */
   '| ip2socka ',                     /* Build socket descriptor     */
   '| spec pad 00 x05 4 1-* 9',
        'xe30006ec 25 x494e4954 37',  /* INIT                        */
        'tod 65',
   '| spec 1-* 1 qual tod 65',
          'print ((u64%4096)%1000000)  u2c 65.4',         /* Seconds */
          'print (((u64%4096)//1000000)*4294.967296%1)',
                'u2c 69.4',        /* Fraction */
   '| udp 0 userid' stack,
   '| z: locate',                     /* Discard null timeout        */
   '| spec 41.24 1',
   '| fblock 8',
   '| spec qual time print d2c((secs+frac/4294967296)*4096e6%1) 1',
   '| join 2',                        /* Keep 3 TOD clocks           */
   '| spec 1-* 1 tod n',              /* Plus our own clock          */
   '| o: fanout',
   '| copy',
   '| spec 17.8 c2t(*) 2.23',         /* NTP transmit time           */
   '| s: gather | join',
   '| i: faninany',
   '| x:',
   '\ o:',
   '| spec qual tod4',
            ', Off:, 1',
          'print (t2-t1+t3-t4)/8192e6   pic ---9.999 nw ,s, nw',
          ',RTT:, nw print (t4-t1)/8192e3 pic zzz9.9 nw ,ms, nw',
   '| s:',
   '\ z: | spec ,-, | i:',
 
return
