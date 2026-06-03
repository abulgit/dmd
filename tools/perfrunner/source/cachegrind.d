module cachegrind;

import std.array : replace;
import std.conv : to;
import std.path : buildPath;
import std.regex : ctRegex, matchFirst;

import runner : run;

private enum iRefsRe = ctRegex!(`I\s+refs:\s+([\d,]+)`);

/// Parse the "I refs:" instruction count out of cachegrind's output.
long parseIRefs(string output)
{
    auto m = matchFirst(output, iRefsRe);
    if (m.empty)
        throw new Exception("could not parse cachegrind 'I refs:'");
    return m[1].replace(",", "").to!long;
}

/// Compile the workload under cachegrind and return the instruction count.
long instructions(string dmd, string[] dflags, string workload, string tmp, string tag)
{
    auto obj = buildPath(tmp, tag ~ ".o");
    auto cgOut = buildPath(tmp, tag ~ ".cgout");
    auto cmd = ["valgrind", "--tool=cachegrind", "--cachegrind-out-file=" ~ cgOut,
        dmd, "-c"] ~ dflags ~ [workload, "-of=" ~ obj];
    auto r = run(cmd);
    if (r.status != 0)
        throw new Exception("cachegrind failed:\n" ~ r.output);
    return parseIRefs(r.output);
}

unittest
{
    auto sample = "==42== I   refs:      1,234,500,000\n";
    assert(parseIRefs(sample) == 1_234_500_000);
}
