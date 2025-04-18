/*
TEST_OUTPUT:
---
fail_compilation/fix21167.d(13): Error: function `f` is not callable using argument types `(int, string, int)`
fail_compilation/fix21167.d(15):        cannot pass argument `"foo"` of type `string` to parameter `int __param_1`
fail_compilation/fix21167.d(9):        `fix21167.f(int __param_0, int __param_1, int __param_2)` declared here
---
*/
void f(int, int, int){}

void main()
{
	f(
		1,
		"foo",
		3
	);

}
