/*
TEST_OUTPUT:
---
fail_compilation\test18262.d(19): Error: cannot check `test18262.A2.d` value for overflow
fail_compilation\test18262.d(19): Error: cannot auto-increment value for enum member `A2.d` because base type `A1` does not support increment
fail_compilation\test18262.d(19): Error: enum member with enum base type must have an explicit initializer
---
*/

enum A1 : int
{
    a,
    b,
}

enum A2 : A1
{
    c, // does not require +1
    d, // requires + 1 (now produces better error message)
}
