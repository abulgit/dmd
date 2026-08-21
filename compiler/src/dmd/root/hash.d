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

// MurmurHash64A was written by Austin Appleby, and is placed in the public
// domain. The author hereby disclaims copyright to this source code.
// https://github.com/aappleby/smhasher/
//
// The 64-bit variant consumes 8 bytes per round instead of the 4 bytes of
// MurmurHash2, so it does roughly half the work on the long type mangling and
// symbol name strings. The result is folded down to 32 bits because that is
// what the string tables store per slot.
//
// The tail (the 0 .. 7 bytes left after the 8 byte rounds) deliberately
// departs from the reference implementation: instead of one step per byte it
// uses a constant number of overlapping loads. Most D identifiers are shorter
// than 8 bytes, so for the identifier table the tail is the whole hash.
uint calcHash(scope const(char)[] data) @nogc nothrow pure @safe
{
    return calcHash(cast(const(ubyte)[])data);
}

/// ditto
uint calcHash(scope const(ubyte)[] data) @nogc nothrow pure @safe
{
    // 'm' and 'r' are mixing constants generated offline.
    // They're not really 'magic', they just happen to work well.
    enum ulong m = 0xc6a4_a793_5bd1_e995UL;
    enum int r = 47;
    // Initialize the hash to a 'random' value
    ulong h = cast(ulong) data.length * m;
    // Mix 8 bytes at a time into the hash
    while (data.length >= 8)
    {
        ulong k = load8(data[0 .. 8]);
        k *= m;
        k ^= k >> r;
        k *= m;
        h ^= k;
        h *= m;
        data = data[8 .. $];
    }
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
private uint load4(scope const(ubyte)[] b) @nogc nothrow pure @safe
{
    return b[0] | b[1] << 8 | b[2] << 16 | b[3] << 24;
}

/// ditto
private ulong load8(scope const(ubyte)[] b) @nogc nothrow pure @safe
{
    return load4(b[0 .. 4]) | cast(ulong) load4(b[4 .. 8]) << 32;
}

unittest
{
    char[10] data = "0123456789";
    assert(calcHash(data[0..$]) == 692_409_444);
    assert(calcHash(data[1..$]) == 1_096_716_255);
    assert(calcHash(data[2..$]) == 1_064_661_774);
    assert(calcHash(data[3..$]) == 3_337_566_304);
    // 8 and 16 bytes: full rounds, no tail; 1..3 and 4..7 bytes: each tail path
    assert(calcHash(data[0..8]) == 3_655_457_200);
    assert(calcHash("0123456789abcdef") == 34_301_661);
    assert(calcHash("") == 0);
    assert(calcHash("a") == 4_283_311_127);
    assert(calcHash("ab") == 3_443_246_331);
    assert(calcHash("abc") == 1_305_305_146);
    assert(calcHash("abcd") == 267_587_814);
    assert(calcHash("abcdefg") == 2_657_271_624);
    assert(calcHash("abcdefghijk") == 1_749_481_894);
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
