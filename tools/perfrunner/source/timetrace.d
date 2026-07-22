module timetrace;


import std.file : readText;
import std.json : parseJSON;
import std.path : buildPath;
import std.process : execute;

// The top-level -ftime-trace spans grouped into frontend/backend. These names
// match main.d's generic phase spans; they don't overlap, so summing them
// partitions the compile without double-counting the nested per-symbol events.
// Sum the duration (microseconds) of the top-level spans in each bucket.
// Returns both coarse (frontend/backend) and fine (parse/sema/inline/codegen).
long[string] parseStages(string trace)
{
    long parse, sema, inline, codegen;
    foreach (e; parseJSON(trace)["traceEvents"].array)
    {
        if (e["ph"].str != "X")
            continue;
        auto name = e["name"].str;
        if (name == "Parsing")
            parse += e["dur"].integer;
        else if (name == "Semantic analysis")
            sema += e["dur"].integer;
        else if (name == "Inlining")
            inline += e["dur"].integer;
        else if (name == "Code generation")
            codegen += e["dur"].integer;
    }
    return [
        "stage_frontend_us": parse + sema,
        "stage_backend_us":  inline + codegen,
        "stage_parse_us":    parse,
        "stage_sema_us":     sema,
        "stage_inline_us":   inline,
        "stage_codegen_us":  codegen,
    ];
}

// Compile the workload with -ftime-trace and read the per-stage durations.
// Returns null if the compiler is too old to know the flag (older base side).
long[string] stages(string dmd, string[] dflags, string workload, string tmp, string tag)
{
    auto obj = buildPath(tmp, tag ~ "-tt.o");
    auto trace = buildPath(tmp, tag ~ ".time-trace");
    auto cmd = [dmd, "-c", "-ftime-trace", "-ftime-trace-file=" ~ trace]
        ~ dflags ~ [workload, "-of=" ~ obj];
    if (execute(cmd).status != 0)
        return null;
    return parseStages(readText(trace));
}

unittest
{
    auto sample = `{"traceEvents": [
        {"ph":"M","name":"process_name"},
        {"ph":"X","name":"Parsing","dur":100},
        {"ph":"X","name":"Parse: Module foo","dur":40},
        {"ph":"X","name":"Semantic analysis","dur":300},
        {"ph":"X","name":"Sema1: Function bar","dur":50},
        {"ph":"X","name":"Inlining","dur":20},
        {"ph":"X","name":"Code generation","dur":80},
        {"ph":"X","name":"Codegen: function bar","dur":30}
    ]}`;
    auto s = parseStages(sample);
    assert(s["stage_frontend_us"] == 400);
    assert(s["stage_backend_us"] == 100);
    assert(s["stage_parse_us"] == 100);
    assert(s["stage_sema_us"] == 300);
    assert(s["stage_inline_us"] == 20);
    assert(s["stage_codegen_us"] == 80);
}
