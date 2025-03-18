// REQUIRED_ARGS:
// PERMUTE_ARGS:

// This test ensures that after fixing ICE #20867,
// valid enum usages with final switch work properly.

// Define an enum
enum E
{
    a = 3,
    b = 4
}

// Use the enum in a valid final switch
void testValidSwitch()
{
    E e = E.a;
    final switch (e)
    {
        case E.a: break;
        case E.b: break;
    }
}

void main()
{
    // Test that there's no ICE
    testValidSwitch();
} 