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
// Keys shorter than 8 bytes take the 32-bit MurmurHash2 path. About 80% of the
// identifier and keyword tokens the lexer interns are that short, and for them
// at most one 4 byte round with a 32-bit multiply is the cheapest thing there
// is. Longer keys (type mangles, symbol names) take the 64-bit variant, which
// consumes 8 bytes per round and so does roughly half the work on them. The
// 64-bit result is folded down to 32 bits because that is what the string
// tables store per slot.
uint calcHash(scope const(char)[] data) @nogc nothrow pure @safe
{
    return calcHash(cast(const(ubyte)[])data);
}

/// ditto
uint calcHash(scope const(ubyte)[] data) @nogc nothrow pure @safe
{
    return data.length < 8 ? hashShort(data) : hashLong(data);
}

// MurmurHash2 for inputs of 0 .. 7 bytes
pragma(inline, true)
private uint hashShort(scope const(ubyte)[] data) @nogc nothrow pure @safe
{
    // 'm' and 'r' are mixing constants generated offline.
    // They're not really 'magic', they just happen to work well.
    enum uint m = 0x5bd1e995;
    enum int r = 24;
    // Initialize the hash to a 'random' value
    uint h = cast(uint) data.length;
    // Mix 4 bytes into the hash
    if (data.length >= 4)
    {
        uint k = load4(data[0 .. 4]);
        k *= m;
        k ^= k >> r;
        h = (h * m) ^ (k * m);
        data = data[4 .. $];
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

// MurmurHash64A for inputs of 8 or more bytes, folded to 32 bits.
// The tail (the 0 .. 7 bytes left after the 8 byte rounds) departs from the
// reference implementation: instead of one step per byte it uses a constant
// number of overlapping loads.
pragma(inline, true)
private uint hashLong(scope const(ubyte)[] data) @nogc nothrow pure @safe
{
    enum ulong m = 0xc6a4_a793_5bd1_e995UL;
    enum int r = 47;
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
    // Handle the last few bytes of the input array
    if (data.length >= 4)
    {
        // first and last 4 bytes; they overlap when fewer than 8 remain
        h ^= (cast(ulong) load4(data[0 .. 4]) << 32) | load4(data[$ - 4 .. $]);
        h *= m;
    }
    else if (data.length)
    {
        // first, middle and last byte; some coincide for 1 or 2 bytes
        h ^= (cast(ulong) data[0] << 16) | (cast(ulong) data[data.length >> 1] << 8) | data[data.length - 1];
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

// Little endian loads assembled byte by byte, so the result is the same on
// every host and the code stays @safe; optimizing compilers fuse each into a
// single load once the slice length is known.
pragma(inline, true)
private uint load4(scope const(ubyte)[] b) @nogc nothrow pure @safe
{
    return b[0] | b[1] << 8 | b[2] << 16 | b[3] << 24;
}

/// ditto
pragma(inline, true)
private ulong load8(scope const(ubyte)[] b) @nogc nothrow pure @safe
{
    return load4(b[0 .. 4]) | cast(ulong) load4(b[4 .. 8]) << 32;
}

unittest
{
    char[10] data = "0123456789";
    // 8 bytes and longer: 64-bit rounds
    assert(calcHash(data[0..$]) == 692_409_444);
    assert(calcHash(data[1..$]) == 1_096_716_255);
    assert(calcHash(data[2..$]) == 1_064_661_774);
    assert(calcHash(data[0..8]) == 3_655_457_200);
    assert(calcHash("0123456789abcdef") == 34_301_661);
    assert(calcHash("abcdefghijk") == 1_749_481_894);
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
