module timetrace;

import std.algorithm : sort, startsWith;
import std.file : exists, readText;
import std.json : JSONValue, parseJSON;
import std.path : buildPath;
import std.process : execute;

// Ordered phase buckets we report. Frontend = parse..ctfe, backend = inline+codegen.
immutable string[] phaseIds = ["parse", "sema1", "sema2", "sema3", "ctfe", "inline", "codegen"];

// Per-phase self-time (microseconds) aggregated from one -ftime-trace run.
// `available` is false when the compiler doesn't support -ftime-trace (old base).
struct Trace
{
    bool available;
    long[string] selfUs;

    long phase(string id) const { return selfUs.get(id, 0); }
    long frontend() const { return phase("parse") + phase("sema1") + phase("sema2") + phase("sema3") + phase("ctfe"); }
    long backend() const { return phase("inline") + phase("codegen"); }
    long total() const { return frontend + backend; }
}

// Compile the workload with -ftime-trace and aggregate the trace into phases.
Trace collectTrace(string dmd, string[] dflags, string workload, string tmp, string tag)
{
    auto obj = buildPath(tmp, tag ~ "-tt.o");
    auto tracePath = buildPath(tmp, tag ~ ".trace");
    auto cmd = [dmd, "-ftime-trace", "-ftime-trace-file=" ~ tracePath, "-c"]
        ~ dflags ~ [workload, "-of=" ~ obj];
    auto r = execute(cmd);
    if (r.status != 0 || !exists(tracePath))
        return Trace(false);
    return parseTrace(readText(tracePath));
}

// Map a trace event name to its phase bucket, or null to ignore it.
private string phaseOf(string name)
{
    if (name.startsWith("Pars"))     return "parse";
    if (name.startsWith("Sema1"))    return "sema1";
    if (name.startsWith("Sema2"))    return "sema2";
    if (name.startsWith("Sema3"))    return "sema3";
    if (name.startsWith("Ctfe"))     return "ctfe";
    if (name.startsWith("Import"))   return "sema1";
    if (name.startsWith("Semantic")) return "sema1";
    if (name.startsWith("Inlin"))    return "inline";
    if (name.startsWith("Codegen") || name.startsWith("Code generation")) return "codegen";
    if (name.startsWith("DFA"))      return "codegen";
    return null;
}

// Parse a chrome-trace JSON string into per-phase self-times.
Trace parseTrace(string json)
{
    struct Ev { string name; long ts; long dur; }
    Ev[] evs;
    foreach (e; parseJSON(json)["traceEvents"].array)
    {
        if (e["ph"].str != "X")
            continue;
        evs ~= Ev(e["name"].str, e["ts"].integer, e["dur"].integer);
    }

    // Reconstruct nesting (single-threaded, so intervals nest cleanly) and
    // subtract each event's direct children to get its self-time.
    sort!((a, b) => a.ts != b.ts ? a.ts < b.ts : a.dur > b.dur)(evs);
    auto childUs = new long[evs.length];
    size_t[] stack;
    foreach (i, e; evs)
    {
        while (stack.length && evs[stack[$ - 1]].ts + evs[stack[$ - 1]].dur <= e.ts)
            stack = stack[0 .. $ - 1];
        if (stack.length)
            childUs[stack[$ - 1]] += e.dur;
        stack ~= i;
    }

    Trace t = { available: true };
    foreach (i, e; evs)
        if (auto ph = phaseOf(e.name))
            t.selfUs[ph] += e.dur - childUs[i];
    return t;
}

unittest
{
    auto sample = `{
"beginningOfTime":0,
"traceEvents": [
{"ph":"M","name":"process_name"},
{"ph":"X","name": "Parsing","ts":0,"dur":100},
{"ph":"X","name": "Semantic analysis","ts":100,"dur":80},
{"ph":"X","name": "Sema1: Function add","ts":100,"dur":50},
{"ph":"X","name": "Code generation","ts":200,"dur":40}
]
}`;
    auto t = parseTrace(sample);
    assert(t.available);
    assert(t.phase("parse") == 100);
    assert(t.phase("sema1") == 80); // 30 self of container + 50 of the function
    assert(t.phase("codegen") == 40);
    assert(t.frontend == 180);
    assert(t.backend == 40);
    assert(t.total == 220);
}
