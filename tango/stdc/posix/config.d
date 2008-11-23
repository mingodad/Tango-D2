/**
 * D header file for POSIX.
 *
 * Copyright: Public Domain
 * License:   Public Domain
 * Authors:   Sean Kelly
 * Standards: The Open Group Base Specifications Issue 6, IEEE Std 1003.1, 2004 Edition
 */
module tango.stdc.posix.config;

public import tango.stdc.config;

extern (C):

version( linux )
{
    //version( none /* X86_64 */ )
    version(SMALLFILE)
    {
      const bool  __USE_LARGEFILE64   = false;
    }
    else
    {
      const bool  __USE_LARGEFILE64   = true;
    }
    const bool  __USE_FILE_OFFSET64 = __USE_LARGEFILE64;
    const bool  __REDIRECT          = false;
}
