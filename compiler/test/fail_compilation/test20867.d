/*
TEST_OUTPUT:
---
fail_compilation/test20867.d(14): Error: cannot use `final switch` on enum `E` while it is being defined
---
*/
// Test case to verify fix for ICE when using final switch on an enum that's being defined

enum E
{
    a = 3,
    b = () {
        E e;
        final switch (e)  // This should error out instead of segfaulting
        {
            case E.a: break;
        }
        return 4;
    } ()
}
