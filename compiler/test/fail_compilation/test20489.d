/*
TEST_OUTPUT:
---
fail_compilation/test20489.d(23): Error: function `pure nothrow @nogc @safe int test20489.D1.f(int delegate(int) pure nothrow @nogc @safe body)` does not override any function, did you mean to override `pure nothrow @nogc @safe int test20489.B1.f(scope int delegate(int) pure nothrow @nogc @safe)`?
fail_compilation/test20489.d(23):        Did you intend to override:
fail_compilation/test20489.d(23):        `pure nothrow @nogc @safe int test20489.B1.f(scope int delegate(int) pure nothrow @nogc @safe)`
fail_compilation/test20489.d(23):        Parameter 1 is missing `scope`
fail_compilation/test20489.d(32): Error: function `test20489.D2.nonExistentMethod` does not override any function
fail_compilation/test20489.d(41): Error: function `test20489.D3.finalMethod` cannot override `final` function `test20489.B3.finalMethod`
fail_compilation/test20489.d(41): Error: function `void test20489.D3.finalMethod()` does not override any function, did you mean to override `void test20489.B3.finalMethod()`?
fail_compilation/test20489.d(41):        Did you intend to override:
fail_compilation/test20489.d(41):        `void test20489.B3.finalMethod()`
---
*/


// Case 1: Signature mismatch (parameter attributes)
class B1 {
    pure nothrow @nogc @safe int f(scope int delegate(int) pure nothrow @nogc @safe) { return 0; }
}

class D1 : B1 {
    override pure nothrow @nogc @safe int f(int delegate(int) pure nothrow @nogc @safe body) { return 0; }
}

// Case 2: No base class method with the given name exists
class B2 {
    void existingMethod() {}
}

class D2 : B2 {
    override void nonExistentMethod() {}
}

// Case 3: Base class method is final
class B3 {
    final void finalMethod() {}
}

class D3 : B3 {
    override void finalMethod() {}
}
