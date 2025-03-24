/*
TEST_OUTPUT:
---
fail_compilation/named_arguments_template.d(14): Error: no parameter named `x`
fail_compilation/named_arguments_template.d(14): Error: template `gun` is not callable using argument types `!()(int)`
fail_compilation/named_arguments_template.d(10):        Candidate is: `gun(T)(T a)`
---
*/

void gun(T)(T a) {}

void main()
{
    gun(x: 1); // Should show "no parameter named `x`"
}
