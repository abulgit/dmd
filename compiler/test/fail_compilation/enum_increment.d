/* TEST_OUTPUT:
---
fail_compilation/enum_increment.d(18): Error: enum member `enum_increment.A2.d` value cannot be automatically set because the base type `A1` does not support increment
---
 */

// Test for issue #18262: Bad diagnostic for an enum member in an enum that uses another enum as base type

enum A1 : int
{
    a,
    b,
}

enum A2 : A1
{
    c = A1.a, // explicitly initialized, OK
    d,        // cannot be automatically incremented - should fail with clear message
} 