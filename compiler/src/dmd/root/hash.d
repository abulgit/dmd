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

uint calcHash(scope const(char)[] data) @nogc nothrow pure @safe
{
    return calcHash(cast(const(ubyte)[])data);
}

/// Multiplicative mixing over 4/8-byte chunks. Much cheaper per byte than
/// the per-4-byte MurmurHash2 loop used before: typical identifiers
/// (<= 16 bytes) take two multiplies plus the final avalanche. The tail
/// chunk overlaps the previous one instead of being processed bytewise.
uint calcHash(scope const(ubyte)[] data) @nogc nothrow pure @trusted
{
    // odd 64-bit mixing constants (golden ratio / xxhash primes)
    enum ulong m1 = 0x9E3779B97F4A7C15;
    enum ulong m2 = 0xC2B2AE3D27D4EB4F;

    const len = data.length;
    const p = data.ptr;
    // spread the length over the whole word so it cannot cancel out
    // against the first data byte in the short-string paths below
    ulong h = len * m2;
    if (len >= 8)
    {
        size_t i = 0;
        for (; i + 8 < len; i += 8)
            h = (h ^ load8(p + i)) * m1;
        h = (h ^ load8(p + len - 8)) * m1; // final chunk, overlaps when len % 8 != 0
    }
    else if (len >= 4)
    {
        // two overlapping 4-byte reads cover the whole string
        const ulong k = load4(p) | (cast(ulong)load4(p + len - 4) << 32);
        h = (h ^ k) * m1;
    }
    else if (len > 0)
    {
        const uint k = p[0] | (p[len >> 1] << 8) | (p[len - 1] << 16);
        h = (h ^ k) * m1;
    }
    // final avalanche; the table index uses the low bits, so fold the
    // well-mixed high bits down
    h ^= h >> 32;
    h *= m2;
    h ^= h >> 29;
    return cast(uint)h;
}

ulong load8(scope const(ubyte)* p) @nogc nothrow pure @trusted
{
    ulong v;
    (cast(ubyte*)&v)[0 .. 8] = p[0 .. 8];
    return v;
}

uint load4(scope const(ubyte)* p) @nogc nothrow pure @trusted
{
    uint v;
    (cast(ubyte*)&v)[0 .. 4] = p[0 .. 4];
    return v;
}

unittest
{
    char[10] data = "0123456789";
    // equal content, different memory locations hash equally
    char[10] copy = data;
    assert(calcHash(data[0 .. $]) == calcHash(copy[0 .. $]));
    // sample strings all hash differently
    static immutable string[] samples = [
        "", "a", "b", "ab", "ba", "abc", "abcd", "abcde", "abcdef",
        "abcdefg", "abcdefgh", "abcdefghi", "abcdefghij", "foo", "bar",
        "foreach", "foreach_reverse", "0123456789", "1234567890",
    ];
    foreach (i, s1; samples)
        foreach (s2; samples[i + 1 .. $])
            assert(calcHash(s1) != calcHash(s2));
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
