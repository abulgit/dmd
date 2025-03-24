/*
TEST_OUTPUT:
---
fail_compilation/template_named_args_test.d(14): Error: no parameter named `x`
fail_compilation/template_named_args_test.d(14): Error: template `gun` is not callable using argument types `!()(int)`
fail_compilation/template_named_args_test.d(10):        Candidate is: `gun(T)(T a)`
---
*/

void gun(T)(T a) {}

void main()
{
	gun(x: 1); // (no explanation)
}
