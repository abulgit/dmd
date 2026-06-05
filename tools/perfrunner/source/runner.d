module runner;

import std.process : execute;

// Outcome
struct RunResult
{
    int status;     // process exit code
    string output;  // combined stdout + stderr
}

// Run `cmd` and capture its exit code and output
RunResult run(string[] cmd)
{
    auto r = execute(cmd);
    return RunResult(r.status, r.output);
}
