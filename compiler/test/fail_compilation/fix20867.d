/*
TEST_OUTPUT:
---
fail_compilation/fix20867.d(14): Error: cannot use `final switch` on enum `E` while it is being defined
---
*/

// Test for issue 20867 - ICE on final switch forward referencing its enum
enum E
{
    a = 3,
    b = () {
        E e;
        final switch (e)
        {
            case E.a: break;
        }
        return 4;
    } ()
} 