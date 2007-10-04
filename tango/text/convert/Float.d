/*******************************************************************************

        copyright:      Copyright (c) 2004 Kris Bell. All rights reserved

        license:        BSD style: $(LICENSE)
        
        version:        Initial release: Nov 2005

        author:         Kris

        A set of functions for converting between string and floating-
        point values.

        Applying the D "import alias" mechanism to this module is highly
        recommended, in order to limit namespace pollution:
        ---
        import Float = tango.text.convert.Float;

        auto f = Float.parse ("3.14159");
        ---
        
*******************************************************************************/

module tango.text.convert.Float;

private import tango.core.Exception;

private import Integer = tango.text.convert.Integer;

private alias real NumType;

private extern (C) NumType log10l(NumType x);

/******************************************************************************

        Convert a formatted string of digits to a floating-point
        number. Throws an exception where the input text is not
        parsable in its entirety.
        
******************************************************************************/

NumType toFloat(T) (T[] src)
{
        uint len;

        auto x = parse (src, &len);
        if (len < src.length)
            throw new IllegalArgumentException ("Float.toFloat :: invalid number");
        return x;
}

/******************************************************************************

        Template wrapper to make life simpler. Returns a text version
        of the provided value.

        See format() for details

******************************************************************************/

char[] toUtf8 (NumType d, uint decimals=2, bool scientific=false)
{
        char[64] tmp = void;
        
        return format (tmp, d, decimals, scientific).dup;
}
               
/******************************************************************************

        Template wrapper to make life simpler. Returns a text version
        of the provided value.

        See format() for details

******************************************************************************/

wchar[] toUtf16 (NumType d, uint decimals=2, bool scientific=false)
{
        wchar[64] tmp = void;
        
        return format (tmp, d, decimals, scientific).dup;
}
               
/******************************************************************************

        Template wrapper to make life simpler. Returns a text version
        of the provided value.

        See format() for details

******************************************************************************/

dchar[] toUtf32 (NumType d, uint decimals=2, bool scientific=false)
{
        dchar[64] tmp = void;
        
        return format (tmp, d, decimals, scientific).dup;
}
               
/******************************************************************************

        Convert a float to a string. This produces pretty good results
        for the most part, though one should use David Gay's dtoa package
        for best accuracy.

        Note that the approach first normalizes a base10 mantissa, then
        pulls digits from the left side whilst emitting them (rightward)
        to the output.

******************************************************************************/

T[] format(T, D=double, U=uint) (T[] dst, D x, U decimals = 2, bool scientific = false)
{return format!(T)(dst, x, decimals, scientific);}

T[] format(T) (T[] dst, NumType x, uint decimals = 2, bool scientific = false)
{
        static T[] inf = "-inf";
        static T[] nan = "-nan";

        // extract the sign bit
        static bool signed (NumType x)
        {
                static if (NumType.sizeof is 4) 
                           return ((*cast(uint *)&x) & 0x8000_0000) != 0;

                static if (NumType.sizeof is 8) 
                           return ((*cast(ulong *)&x) & 0x8000_0000_0000_0000) != 0;
                       else
                          {
                          auto pe = cast(ubyte *)&x;
                          return (pe[9] & 0x80) != 0;
                          }
        }

        // strip digits from the left of a normalized base-10 number
        static int toDigit (inout NumType v, inout int count)
        {
                int digit;

                // Don't exceed max digits storable in a real
                // (-1 because the last digit is not always storable)
                if (++count > NumType.dig-1)
                    digit = 0;
                else
                   {
                   // remove leading digit, and bump
                   digit = cast(int) v;
                   v = (v - digit) * 10.0;
                   }
                return digit + '0';
        }

        // sanity check
        assert (dst.length >= 32);

        // extract the sign
        bool sign = signed (x);
        if (sign)
            x = -x;

        if (x !<>= x)
            return sign ? nan : nan[1..$];

        if (x is x.infinity)
            return sign ? inf : inf[1..$];

        // assume no exponent
        int exp = 0;

        // don't scale if zero
        if (x > 0.0)
           {
           // round up a bit (should do even/odd test?)
           x += 0.5 / pow10 (decimals);

           // extract base10 exponent
           exp = cast(int) log10l (x);

           // normalize base10 mantissa (0 < m < 10)
           int len = exp;
           if (exp < 0)
               x *= pow10 (len = -exp);
           else
              x /= pow10 (exp);

           // switch to short display if not enough space
           if (len + 32 > dst.length)
               scientific = true;
           }

        T* p = dst.ptr;
        int count = 0;

        // emit sign
        if (sign)
            *p++ = '-';

        // are we doing +/-exp format?
        if (scientific)
           {
           // emit first digit, and decimal point
           *p++ = toDigit (x, count);
           *p++ = '.';

           // emit rest of mantissa
           while (decimals-- > 0)
                  *p++ = toDigit (x, count);

           // emit exponent, if non zero
           if (exp)
              {
              *p++ = 'e';
              *p++ = (exp < 0) ? '-' : '+';
              if (exp < 0)
                  exp = -exp;

              if (exp >= 100)
                 {
                 *p++ = (exp/100) + '0';
                 exp %= 100;
                 }

              *p++ = (exp/10) + '0';
              *p++ = (exp%10) + '0';
              }
           }
        else
           {
           // if fraction only, emit a leading zero
           if (exp < 0)
               *p++ = '0';
           else
              // emit all digits to the left of point
              for (; exp >= 0; --exp)
                     *p++ = toDigit (x, count);

           // emit point
           *p++ = '.';

           // emit leading fractional zeros?
           for (++exp; exp < 0 && decimals > 0; --decimals, ++exp)
                *p++ = '0';

           // output remaining digits, if any. Trailing
           // zeros are also returned from toDigit()
           while (decimals-- > 0)
                  *p++ = toDigit (x, count);
           }

        return dst [0..(p - dst.ptr)];
}


/******************************************************************************

        Convert a formatted string of digits to a floating-point number.
        Good for general use, but use David Gay's dtoa package if serious
        rounding adjustments should be applied.

******************************************************************************/

NumType parse(T) (T[] src, uint* ate=null)
{
        T               c;
        T*              p;
        int             exp;
        bool            sign;
        uint            radix;
        NumType         value = 0.0;

        // remove leading space, and sign
        c = *(p = src.ptr + Integer.trim (src, sign, radix));

        // handle non-decimal representations
        if (radix != 10)
           {
           long v = Integer.parse (src, radix, ate); 
           return *cast(NumType*) &v;
           }

        // set begin and end checks
        auto begin = p;
        auto end = src.ptr + src.length;

        // read leading digits; note that leading
        // zeros are simply multiplied away
        while (c >= '0' && c <= '9' && p < end)
              {
              value = value * 10 + (c - '0');
              c = *++p;
              }

        // gobble up the point
        if (c is '.' && p < end)
            c = *++p;

        // read fractional digits; note that we accumulate
        // all digits ... very long numbers impact accuracy
        // to a degree, but perhaps not as much as one might
        // expect. A prior version limited the digit count,
        // but did not show marked improvement. For maximum
        // accuracy when reading and writing, use David Gay's
        // dtoa package instead
        while (c >= '0' && c <= '9' && p < end)
              {
              value = value * 10 + (c - '0');
              c = *++p;
              --exp;
              } 

        // did we get something?
        if (value)
           {
           // parse base10 exponent?
           if ((c is 'e' || c is 'E') && p < end )
              {
              uint eaten;
              exp += Integer.parse (src[(++p-src.ptr) .. $], 0, &eaten);
              p += eaten;
              }

           // adjust mantissa; note that the exponent has
           // already been adjusted for fractional digits
           if (exp < 0)
               value /= pow10 (-exp);
           else
              value *= pow10 (exp);
           }
        else
           // was it was nan instead?
           if (p is begin)
               if (p[0..3] == "inf")
                   p += 3, value = value.infinity;
               else
                  if (p[0..3] == "nan")
                      p += 3, value = value.nan;

        // set parse length, and return value
        if (ate)
            *ate = p - src.ptr;

        if (sign)
            value = -value;
        return value;
}


/******************************************************************************

        Internal function to convert an exponent specifier to a floating
        point value.

******************************************************************************/

private NumType pow10 (uint exp)
{
        static  NumType[] Powers = 
                [
                1.0e1L,
                1.0e2L,
                1.0e4L,
                1.0e8L,
                1.0e16L,
                1.0e32L,
                1.0e64L,
                1.0e128L,
                1.0e256L,
                ];

        if (exp >= 512)
            throw new IllegalArgumentException ("Float.pow10 :: exponent too large");

        NumType mult = 1.0;
        foreach (NumType power; Powers)
                {
                if (exp & 1)
                    mult *= power;
                if ((exp >>= 1) is 0)
                     break;
                }
        return mult;
}


/******************************************************************************

******************************************************************************/

debug (UnitTest)
{
        // void main() {}

        unittest
        {
                char[64] tmp;

                auto f = parse ("nan");
                assert (format(tmp, f) == "nan");
                f = parse ("inf");
                assert (format(tmp, f) == "inf");
                f = parse ("-nan");
                assert (format(tmp, f) == "-nan");
                f = parse (" -inf");
                assert (format(tmp, f) == "-inf");

                assert (format (tmp, 3.14159, 6) == "3.141590");
                assert (format (tmp, 3.14159, 4) == "3.1416");
                assert (parse ("3.5") == 3.5);
                assert (format(tmp, parse ("3.14159"), 6) == "3.141590");
        }
}


