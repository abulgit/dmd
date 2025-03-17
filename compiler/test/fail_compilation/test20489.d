/*
REQUIRED_ARGS: -verrors=0
TEST_OUTPUT:
---
fail_compilation/test20489.d(20): Error: function `pure nothrow @nogc @safe int test20489.D.f(int delegate(int) pure nothrow @nogc @safe body)` does not override any function, did you mean to override `pure nothrow @nogc @safe int test20489.B.f(scope int delegate(int) pure nothrow @nogc @safe)`?
fail_compilation/test20489.d(20):        Did you intend to override:
fail_compilation/test20489.d(20):        `pure nothrow @nogc @safe int test20489.B.f(scope int delegate(int) pure nothrow @nogc @safe)`
fail_compilation/test20489.d(20):        Parameter 1 is missing `scope`
---
*/

// Test case for https://issues.dlang.org/show_bug.cgi?id=20489
// Improved error message for override mismatches

class B {
    pure nothrow @nogc @safe int f(scope int delegate(int) pure nothrow @nogc @safe) { return 0; }
}

class D : B {
    override pure nothrow @nogc @safe int f(int delegate(int) pure nothrow @nogc @safe body) { return 0; }
}
