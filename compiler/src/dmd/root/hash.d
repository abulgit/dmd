/**
 * Hash functions for arbitrary binary data.
 *
 * Copyright: Copyright (C) 1999-2026 by The D Language Foundation, All Rights Reserved
 * Authors:   Martin Nowak, Walter Bright, https://www.digitalmars.com
 * License:   $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:    $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/root/hash.d, root/_hash.d)
 * Documentation:  https://dlang.org/phobos/dmd_root_hash.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/compiler/src/dmd/root/hash.d
 */

module dmd.root.hash;

nothrow:
@safe:

// MurmurHash2 and MurmurHash64A were written by Austin Appleby, and are placed
// in the public domain. The author hereby disclaims copyright to this source
// code. https://github.com/aappleby/smhasher/
//
// Keys shorter than 8 bytes take the 32-bit MurmurHash2 path, inlined into the
// caller. About 80% of the identifier and keyword tokens the lexer interns are
// that short, and for them one 4 byte round with a 32-bit multiply by an
// immediate is the cheapest thing there is. Longer keys (type mangles, symbol
// names) take the 64-bit variant out of line; it consumes 8 bytes per round
// and so does roughly half the work on them. Its result is folded down to
// 32 bits because that is what the string tables store per slot.
uint calcHash(scope const(char)[] data) @nogc nothrow pure @safe
{
    return calcHash(cast(const(ubyte)[])data);
}

/// ditto
uint calcHash(scope const(ubyte)[] data) @nogc nothrow pure @safe
{
    return data.length < 8 ? hashShort(data) : hashLong(data);
}

// MurmurHash2, for inputs of 0 .. 7 bytes
private uint hashShort(scope const(ubyte)[] data) @nogc nothrow pure @safe
{
    // 'm' and 'r' are mixing constants generated offline.
    // They're not really 'magic', they just happen to work well.
    enum uint m = 0x5bd1e995;
    enum int r = 24;
    // Initialize the hash to a 'random' value
    uint h = cast(uint) data.length;
    // Mix 4 bytes at a time into the hash
    while (data.length >= 4)
    {
        uint k = data[3] << 24 | data[2] << 16 | data[1] << 8 | data[0];
        k *= m;
        k ^= k >> r;
        h = (h * m) ^ (k * m);
        data = data[4..$];
    }
    // Handle the last few bytes of the input array
    switch (data.length & 3)
    {
    case 3:
        h ^= data[2] << 16;
        goto case;
    case 2:
        h ^= data[1] << 8;
        goto case;
    case 1:
        h ^= data[0];
        h *= m;
        goto default;
    default:
        break;
    }
    // Do a few final mixes of the hash to ensure the last few
    // bytes are well-incorporated.
    h ^= h >> 13;
    h *= m;
    h ^= h >> 15;
    return h;
}

// MurmurHash64A, for inputs of 8 or more bytes, folded to 32 bits.
// Kept out of line so that only the short path gets inlined into callers.
pragma(inline, false)
private uint hashLong(scope const(ubyte)[] data) @nogc nothrow pure @safe
{
    enum ulong m = 0xc6a4_a793_5bd1_e995UL;
    enum int r = 47;
    const whole = data;
    ulong h = cast(ulong) data.length * m;
    // Mix 8 bytes at a time into the hash
    do
    {
        ulong k = load8(data[0 .. 8]);
        k *= m;
        k ^= k >> r;
        k *= m;
        h ^= k;
        h *= m;
        data = data[8 .. $];
    } while (data.length >= 8);
    // Handle the last few bytes of the input array. Unlike the reference
    // implementation, which takes them one byte at a time, mix in the last 8
    // bytes as a whole; they overlap with what the final round already
    // consumed, which is harmless for a hash and keeps this a single load.
    if (data.length)
    {
        h ^= load8(whole[$ - 8 .. $]);
        h *= m;
    }
    // Do a few final mixes of the hash to ensure the last few
    // bytes are well-incorporated.
    h ^= h >> r;
    h *= m;
    h ^= h >> r;
    // Fold to 32 bits
    return cast(uint) h ^ cast(uint)(h >> 32);
}

// Little endian 8 byte load assembled byte by byte, so the result is the same
// on every host and the code stays @safe; optimizing compilers fuse it into a
// single load once the slice length is known.
private ulong load8(scope const(ubyte)[] b) @nogc nothrow pure @safe
{
    return cast(ulong) b[0]
         | cast(ulong) b[1] << 8
         | cast(ulong) b[2] << 16
         | cast(ulong) b[3] << 24
         | cast(ulong) b[4] << 32
         | cast(ulong) b[5] << 40
         | cast(ulong) b[6] << 48
         | cast(ulong) b[7] << 56;
}

unittest
{
    char[10] data = "0123456789";
    // 8 bytes and longer: 64-bit rounds, last 8 bytes as the tail
    assert(calcHash(data[0..$]) == 3_371_045_939);
    assert(calcHash(data[1..$]) == 2_024_886_120);
    assert(calcHash(data[2..$]) == 1_064_661_774);
    assert(calcHash(data[0..8]) == 3_655_457_200);
    assert(calcHash("0123456789abcdef") == 34_301_661);
    assert(calcHash("abcdefghijk") == 1_979_916_221);
    assert(calcHash("0123456789abcdefg") == 3_926_020_247);
    // shorter than 8 bytes: identical to plain MurmurHash2
    assert(calcHash(data[3..$]) == 3_631_432_225);
    assert(calcHash("") == 0);
    assert(calcHash("a") == 2_456_313_694);
    assert(calcHash("ab") == 446_775_395);
    assert(calcHash("abc") == 324_500_635);
    assert(calcHash("abcd") == 646_393_889);
    assert(calcHash("abcdefg") == 4_188_131_059);
}

// combine and mix two words (boost::hash_combine)
size_t mixHash(size_t h, size_t k) @nogc nothrow pure @safe
{
    return h ^ (k + 0x9e3779b9 + (h << 6) + (h >> 2));
}

unittest
{
    // & uint.max because mixHash output is truncated on 32-bit targets
    assert((mixHash(0xDE00_1540, 0xF571_1A47) & uint.max) == 0x952D_FC10);
}
