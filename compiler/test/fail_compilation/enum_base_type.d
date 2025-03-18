/* TEST_OUTPUT:
---
fail_compilation/enum_base_type.d(16): Error: enum member `enum_base_type.A2.d` value cannot be automatically defined because the base type `A1` does not support increment
---
 */

enum A1 : int
{
    a,
    b,
}

enum A2 : A1
{
    c = A1.a, // explicitly set value OK
    d, // error: cannot auto-increment enum type
}
