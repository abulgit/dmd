module cachegrind;

import std.algorithm : startsWith;
import std.array : split;
import std.conv : to;
import std.file : readText;
import std.path : buildPath;
import std.process : execute, Config;
import std.string : lineSplitter, strip;

long parseInstructions(string cgout)
{
    foreach (line; cgout.lineSplitter)
        if (line.startsWith("summary:"))
            return line["summary:".length .. $].strip.split[0].to!long;
    throw new Exception("could not find 'summary:' line in cachegrind output");
}

// Run `dmd args...` under cachegrind (optionally from `workDir`) and return
// the retired-instruction count.
long instructionsAt(string dmd, string[] args, string tmp, string tag, string workDir = null)
{
    auto cgOut = buildPath(tmp, tag ~ ".cgout");
    auto cmd = ["valgrind", "--tool=cachegrind", "--cachegrind-out-file=" ~ cgOut, dmd] ~ args;
    auto r = execute(cmd, null, Config.none, size_t.max, workDir);
    if (r.status != 0)
        throw new Exception("cachegrind failed:\n" ~ r.output);
    return parseInstructions(readText(cgOut));
}

// Compile the workload under cachegrind
long instructions(string dmd, string[] dflags, string workload, string tmp, string tag)
{
    auto obj = buildPath(tmp, tag ~ ".o");
    return instructionsAt(dmd, ["-c"] ~ dflags ~ [workload, "-of=" ~ obj], tmp, tag);
}

unittest
{
    auto sample = "events: Ir\nfn=(1) main\n5 100\nsummary: 1234500000\n";
    assert(parseInstructions(sample) == 1_234_500_000);
}
