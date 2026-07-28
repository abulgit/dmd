/*
TEST_OUTPUT:
---
fail_compilation/issue23470.d(14): Error: function `issue23470.A.foo` `final` function requires a body in interface `A`
---
*/

// https://github.com/dlang/dmd/issues/23470

final:

interface A
{
    void foo();
}

class B : A
{
    void foo() { }
}

// exempt, the definition can come from the other language
extern (C++) interface C
{
    void bar();
}

extern (C) interface D
{
    void baz();
}
