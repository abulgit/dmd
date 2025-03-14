/*
TEST_OUTPUT:
---
fail_compilation/fix20075.d(13): Error: none of the overloads of `this` are callable using argument types `(int*)`
fail_compilation/fix20075.d(18):        Candidate is: `fix20075.Foo.this(immutable(int*) a) immutable`
fail_compilation/fix20075.d(13):        Note: Constructor expects immutable argument(s), but mutable was supplied
---
*/

// Test for issue #20075 - "none of the overloads of __ctor are callable using a immutable object" error message is backwards

immutable(Foo) getFoo(int* a) {
	return immutable Foo(a);
}

struct Foo {
	@disable this();
	immutable this(immutable int* a) {}
}
