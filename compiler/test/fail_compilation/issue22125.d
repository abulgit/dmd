// https://issues.dlang.org/show_bug.cgi?id=22125

/*
REQUIRED_ARGS: -verrors=context
TEST_OUTPUT:
---
fail_compilation/issue22125.d(37): Error: mutable method `issue22125.S.doStuff` is not callable using a `const` object
    s.doStuff();
             ^
fail_compilation/issue22125.d(30):        Consider adding `const` or `inout` here
    void doStuff() { }
                 ^
fail_compilation/issue22125.d(38): Error: mutable method `issue22125.S.doStuffWithArgs` is not callable using a `const` object
    s.doStuffWithArgs(1);
                     ^
fail_compilation/issue22125.d(31):        Consider adding `const` or `inout` here
    void doStuffWithArgs(int a) { }
                              ^
fail_compilation/issue22125.d(40): Error: non-shared method `issue22125.S.doStuff` is not callable using a `shared` object
    ss.doStuff();
              ^
fail_compilation/issue22125.d(30):        Consider adding `shared` here
    void doStuff() { }
                 ^
---
*/

struct S
{
    void doStuff() { }
    void doStuffWithArgs(int a) { }
}

void test()
{
    const S s;
    s.doStuff();
    s.doStuffWithArgs(1);
    shared S ss;
    ss.doStuff();
}

