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
// MurmurHash2, so it does roughly half the work on the identifier and type
// mangling strings that dominate the compiler's hashing. The result is folded
// down to 32 bits because that is what the string tables store per slot.
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
        // Assembled byte by byte so the result is endian independent and the
        // code stays @safe; optimizing compilers fuse this into one load.
        const b = data[0 .. 8];
        ulong k = cast(ulong) b[0]
                | cast(ulong) b[1] << 8
                | cast(ulong) b[2] << 16
                | cast(ulong) b[3] << 24
                | cast(ulong) b[4] << 32
                | cast(ulong) b[5] << 40
                | cast(ulong) b[6] << 48
                | cast(ulong) b[7] << 56;
        k *= m;
        k ^= k >> r;
        k *= m;
        h ^= k;
        h *= m;
        data = data[8 .. $];
    }
    // Handle the last few bytes of the input array
    switch (data.length & 7)
    {
    case 7:
        h ^= cast(ulong) data[6] << 48;
        goto case;
    case 6:
        h ^= cast(ulong) data[5] << 40;
        goto case;
    case 5:
        h ^= cast(ulong) data[4] << 32;
        goto case;
    case 4:
        h ^= cast(ulong) data[3] << 24;
        goto case;
    case 3:
        h ^= cast(ulong) data[2] << 16;
        goto case;
    case 2:
        h ^= cast(ulong) data[1] << 8;
        goto case;
    case 1:
        h ^= cast(ulong) data[0];
        h *= m;
        goto default;
    default:
        break;
    }
    // Do a few final mixes of the hash to ensure the last few
    // bytes are well-incorporated.
    h ^= h >> r;
    h *= m;
    h ^= h >> r;
    // Fold to 32 bits
    return cast(uint) h ^ cast(uint)(h >> 32);
}

unittest
{
    char[10] data = "0123456789";
    assert(calcHash(data[0..$]) == 1_874_127_986);
    assert(calcHash(data[1..$]) ==   403_704_370);
    assert(calcHash(data[2..$]) == 1_064_661_774);
    assert(calcHash(data[3..$]) == 1_913_381_665);
    // 8 and 16 byte inputs exercise the full-round path with no tail
    assert(calcHash(data[0..8]) == 3_655_457_200);
    assert(calcHash("0123456789abcdef") == 34_301_661);
    assert(calcHash("") == 0);
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
