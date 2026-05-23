/**/
'CALLPIPE (end ?)',
    '*:',
    '| stem line.'
Do l=0 To line.0
  work=line.l
  'CALLPIPE (end ?)',
      'var work',
      '| split',
      '| cons'
End l
