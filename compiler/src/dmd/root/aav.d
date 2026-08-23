/**
 * Associative array implementation.
 *
 * Copyright: Copyright (C) 1999-2026 by The D Language Foundation, All Rights Reserved
 * Authors:   Walter Bright, https://www.digitalmars.com
 * License:   $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:    $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/root/aav.d, root/_aav.d)
 * Documentation:  https://dlang.org/phobos/dmd_root_aav.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/compiler/src/dmd/root/aav.d
 */
module dmd.root.aav;

import core.stdc.string;
import dmd.root.rmem;

nothrow:

private size_t hash(size_t a) pure nothrow @nogc @safe
{
    // multiplicative (Fibonacci) hashing: one multiply pushes the entropy
    // into the high bits, folded back down for masking with the table size
    static if (size_t.sizeof == 8)
    {
        a *= 0x9E3779B97F4A7C15UL;
        return a ^ (a >> 32);
    }
    else
    {
        a *= 0x9E3779B9U;
        return a ^ (a >> 16);
    }
}

private struct KeyValueTemplate(K,V)
{
    K key;
    V value;
}

alias Key = void*;
alias Value = void*;

alias KeyValue = KeyValueTemplate!(Key, Value);

private struct AA
{
private:
    KeyValue* slots;   // power-of-2 sized open-addressing table; empty slots have a null key
    size_t mask;       // number of slots - 1
    size_t nodes;      // number of used slots, excluding the out-of-band null key
    Value nullValue;   // the null key cannot live in the table, store it out of band
    bool hasNull;
    KeyValue[4] sinit; // initial table, spares tiny AAs a second allocation
}

/****************************************************
 * Determine number of entries in associative array.
 */
private size_t dmd_aaLen(const AA* aa) pure nothrow @nogc @safe
{
    return aa ? aa.nodes + (aa.hasNull ? 1 : 0) : 0;
}

/*************************************************
 * Get pointer to value in associative array indexed by key.
 * Add entry for key if it is not already there, returning a pointer to a null Value.
 * Create the associative array if it does not already exist.
 *
 * The returned pointer is only valid until the next insertion.
 */
private Value* dmd_aaGet(AA** paa, Key key) pure nothrow
{
    if (!*paa)
    {
        AA* a = cast(AA*)mem.xmalloc(AA.sizeof);
        a.slots = a.sinit.ptr;
        a.mask = a.sinit.length - 1;
        a.nodes = 0;
        a.nullValue = null;
        a.hasNull = false;
        foreach (ref kv; a.sinit)
        {
            kv.key = null;
            kv.value = null;
        }
        *paa = a;
    }
    AA* aa = *paa;
    if (!key)
    {
        aa.hasNull = true;
        return &aa.nullValue;
    }
    // grow before inserting so the returned pointer stays valid until the
    // next insertion
    if ((aa.nodes + 1) * 4 > (aa.mask + 1) * 3)
        dmd_aaRehash(aa);
    size_t i = hash(cast(size_t)key) & aa.mask;
    while (true)
    {
        KeyValue* kv = aa.slots + i;
        if (kv.key == key)
            return &kv.value;
        if (!kv.key)
        {
            aa.nodes++;
            kv.key = key;
            kv.value = null;
            return &kv.value;
        }
        i = (i + 1) & aa.mask;
    }
}

/*************************************************
 * Get value in associative array indexed by key.
 * Returns NULL if it is not already there.
 */
private Value dmd_aaGetRvalue(AA* aa, Key key) pure nothrow @nogc
{
    if (!aa)
        return null;
    if (!key)
        return aa.hasNull ? aa.nullValue : null;
    size_t i = hash(cast(size_t)key) & aa.mask;
    while (true)
    {
        KeyValue* kv = aa.slots + i;
        if (kv.key == key)
            return kv.value;
        if (!kv.key)
            return null;
        i = (i + 1) & aa.mask;
    }
}

/**
Gets a range of key/values for `aa`.

Returns: a range of key/values for `aa`.
*/
@property auto asRange(AA* aa) pure nothrow @nogc
{
    return AARange!(Key, Value)(aa);
}

private struct AARange(K,V)
{
    AA* aa;
    // current index into the slot table
    size_t bIndex;
    bool onNull;  // currently on the out-of-band null-key entry
    bool done = true;

    this(AA* aa) pure nothrow @nogc scope
    {
        if (aa)
        {
            this.aa = aa;
            done = false;
            if (aa.hasNull)
                onNull = true;
            else
                toNext();
        }
    }

    @property bool empty() const pure nothrow @nogc @safe
    {
        return done;
    }

    @property auto front() const pure nothrow @nogc
    {
        if (onNull)
            return KeyValueTemplate!(K,V)(cast(K)null, cast(V)aa.nullValue);
        return cast(KeyValueTemplate!(K,V))aa.slots[bIndex];
    }

    void popFront() pure nothrow @nogc
    {
        if (onNull)
        {
            onNull = false;
            bIndex = 0;
        }
        else
            bIndex++;
        toNext();
    }

    private void toNext() pure nothrow @nogc
    {
        for (; bIndex <= aa.mask; bIndex++)
        {
            if (aa.slots[bIndex].key !is null)
                return;
        }
        done = true;
    }
}

unittest
{
    AA* aa = null;
    foreach(keyValue; aa.asRange)
        assert(0);

    enum totalKeyLength = 50;
    foreach (i; 1 .. totalKeyLength + 1)
    {
        auto key = cast(void*)i;
        {
            auto valuePtr = dmd_aaGet(&aa, key);
            assert(valuePtr);
            *valuePtr = key;
        }
        bool[totalKeyLength] found;
        size_t rangeCount = 0;
        foreach (keyValue; aa.asRange)
        {
            assert(keyValue.key <= key);
            assert(keyValue.key == keyValue.value);
            rangeCount++;
            assert(!found[cast(size_t)keyValue.key - 1]);
            found[cast(size_t)keyValue.key - 1] = true;
        }
        assert(rangeCount == i);
    }
}

/********************************************
 * Rehash an array.
 */
private void dmd_aaRehash(AA* aa) pure nothrow
{
    const oldCap = aa.mask + 1;
    KeyValue* old = aa.slots;
    const newCap = oldCap == aa.sinit.length ? 16 : oldCap * 2;
    KeyValue* nslots = cast(KeyValue*)mem.xcalloc(newCap, KeyValue.sizeof);
    const nmask = newCap - 1;
    foreach (j; 0 .. oldCap)
    {
        if (old[j].key is null)
            continue;
        size_t i = hash(cast(size_t)old[j].key) & nmask;
        while (nslots[i].key !is null)
            i = (i + 1) & nmask;
        nslots[i] = old[j];
    }
    if (old !is aa.sinit.ptr)
        mem.xfree(old);
    aa.slots = nslots;
    aa.mask = nmask;
}

unittest
{
    AA* aa = null;
    Value v = dmd_aaGetRvalue(aa, null);
    assert(!v);
    Value* pv = dmd_aaGet(&aa, null);
    assert(pv);
    *pv = cast(void*)3;
    v = dmd_aaGetRvalue(aa, null);
    assert(v == cast(void*)3);
}

struct AssocArray(K,V)
{
    private AA* aa;

    /**
    Returns: The number of key/value pairs.
    */
    @property size_t length() const pure nothrow @nogc @safe
    {
        return dmd_aaLen(aa);
    }

    /**
    Lookup value associated with `key` and return the address to it. If the `key`
    has not been added, it adds it and returns the address to the new value.

    The returned pointer is only valid until the next insertion.

    Params:
        key = key to lookup the value for

    Returns: the address to the value associated with `key`. If `key` does not exist, it
             is added and the address to the new value is returned.
    */
    V* getLvalue(const(K) key) pure nothrow
    {
        return cast(V*)dmd_aaGet(&aa, cast(void*)key);
    }

    /**
    Lookup and return the value associated with `key`, if the `key` has not been
    added, it returns null.

    Params:
        key = key to lookup the value for

    Returns: the value associated with `key` if present, otherwise, null.
    */
    V opIndex(const(K) key) pure nothrow @nogc
    {
        return cast(V)dmd_aaGetRvalue(aa, cast(void*)key);
    }

    /**
    Gets a range of key/values for `aa`.

    Returns: a range of key/values for `aa`.
    */
    @property auto asRange() pure nothrow @nogc
    {
        return AARange!(K,V)(aa);
    }
}

///
unittest
{
    auto foo = new Object();
    auto bar = new Object();

    AssocArray!(Object, Object) aa;

    assert(aa[foo] is null);
    assert(aa.length == 0);

    auto fooValuePtr = aa.getLvalue(foo);
    *fooValuePtr = bar;

    assert(aa[foo] is bar);
    assert(aa.length == 1);
}
