/*
TEST_OUTPUT:
---
fail_compilation/fail20867.d(16): Error: cannot use `final switch` on enum `E` while it is being defined
---
*/

// Test case for verifying the error message when using a final switch
// on an enum while it's being defined.

enum E
{
    a = 3,
    b = () {
        E e;
        final switch (e)
        {
            case E.a: break;
            // Missing case E.b - but we should get an error about enum being defined
            // before we reach the check for missing cases
        }
        return 4;
    } ()
} 