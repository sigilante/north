::  /mar/fs/hoon — mark for North/Forth source files (.fs)
::  Stored and treated as plain text (wain); identical semantics to %txt.
::
/?    310
=,  clay
=,  differ
=,  format
=,  mimes:html
|_  txt=wain
++  grab
  |%
  ++  mime  |=((pair mite octs) (to-wain q.q))
  ++  noun  wain
  --
++  grow
  =>  v=.
  |%
  ++  mime  =>  v  [/text/plain (as-octs (of-wain txt))]
  --
++  grad  %txt
--
