/*
TEST_OUTPUT:
---
fail_compilation/fix20075.d(15): Error: none of the overloads of `this` can construct a `immutable` object with argument types `(int*)`
fail_compilation/fix20075.d(11):        Candidate is: `fix20075.Foo.this(immutable(int*) a) immutable`
---
*/

// Test for issue #20075 - "none of the overloads of __ctor are callable using a immutable object" error message is backwards

struct Foo {
	@disable this();
	immutable this(immutable int* a) {}
}

immutable(Foo) getFoo(int* a) {
	return immutable Foo(a);
}

void main() {
	int x;
	auto foo = getFoo(&x);
}
