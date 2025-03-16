/**
TEST_OUTPUT:
---
fail_compilation/test_missing_template_parameter.d(23): Error: template `test2` is not callable using argument types `!()(uint)`
fail_compilation/test_missing_template_parameter.d(23):        missing argument for template parameter #1: `C`
fail_compilation/test_missing_template_parameter.d(15):        Candidate is: `test2(C)(uint id)`
---
*/

void test1(uint id, uint __)
{
    int x = 0;
}

void test2(C)(uint id)
{
    int x = 0;
}

void main()
{
    uint a = 0;
    test2(a);
}