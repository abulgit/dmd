/*
TEST_OUTPUT:
---
fail_compilation/fix21166.d(11): Error: invalid array operation `"foo" + "bar"` (possible missing [])
fail_compilation/fix21166.d(11):        did you mean to concatenate (`"foo" ~ "bar"`) instead ?
---
*/

auto r =
	"foo"
	+
	"bar";
