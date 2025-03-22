#!/usr/bin/env rdmd
/**
 * Performance Regression Benchmark for DMD
 * 
 * This script runs benchmarks on DMD to measure compilation performance metrics.
 * It compares a baseline DMD (typically master) with a modified DMD.
 */
import std.stdio;
import std.process;
import std.array;
import std.conv;
import std.string;
import std.datetime;
import std.file;
import std.algorithm;
import std.json;

struct BenchmarkResult
{
    double compileSecs;
    size_t memoryMB;
    string command;
}

BenchmarkResult runBenchmark(string dmdPath, string testCase)
{
    BenchmarkResult result;
    
    // Capture the command for reference
    result.command = dmdPath ~ " " ~ testCase;
    
    // Run the actual benchmark with time command to capture resource usage
    auto timeCmd = "time -v " ~ dmdPath ~ " " ~ testCase ~ " 2>&1";
    writeln("Running: ", timeCmd);
    
    auto output = executeShell(timeCmd).output.splitLines();
    
    // Parse the output to extract metrics
    foreach (line; output)
    {
        if (line.canFind("User time (seconds):"))
            result.compileSecs = line.split(":")[1].strip().to!double;
        else if (line.canFind("Maximum resident set size (kbytes):"))
            result.memoryMB = line.split(":")[1].strip().to!size_t / 1024;
    }
    
    return result;
}

string formatResult(BenchmarkResult result)
{
    return format("Compile time: %.2f seconds | Memory usage: %d MB", 
                  result.compileSecs, result.memoryMB);
}

string formatComparison(BenchmarkResult baseline, BenchmarkResult modified)
{
    double timeDiff = modified.compileSecs - baseline.compileSecs;
    double timePercent = (timeDiff / baseline.compileSecs) * 100;
    
    double memDiff = modified.memoryMB - baseline.memoryMB;
    double memPercent = (memDiff / baseline.memoryMB) * 100;
    
    return format("Time: %+.2f seconds (%+.2f%%) | Memory: %+d MB (%+.2f%%)",
                  timeDiff, timePercent, cast(int)memDiff, memPercent);
}

void main(string[] args)
{
    if (args.length < 4)
    {
        writeln("Usage: ./perf_benchmark.d <baseline_dmd> <modified_dmd> <test_case>");
        writeln("Example: ./perf_benchmark.d ./dmdmaster/dmd ./dmdbranch/dmd '-i=std -c -unittest -version=StdUnittest -preview=dip1000 phobos/std/package.d'");
        return;
    }
    
    string baselineDmd = args[1];
    string modifiedDmd = args[2];
    string testCase = args[3];
    
    writeln("Running benchmark with:");
    writeln("  Baseline DMD: ", baselineDmd);
    writeln("  Modified DMD: ", modifiedDmd);
    writeln("  Test case: ", testCase);
    writeln();
    
    // Run benchmarks
    writeln("Running baseline benchmark...");
    auto baselineResult = runBenchmark(baselineDmd, testCase);
    
    writeln("\nRunning modified benchmark...");
    auto modifiedResult = runBenchmark(modifiedDmd, testCase);
    
    // Report results
    writeln("\n=== BENCHMARK RESULTS ===");
    writeln("Baseline: ", formatResult(baselineResult));
    writeln("Modified: ", formatResult(modifiedResult));
    writeln("\nDifference: ", formatComparison(baselineResult, modifiedResult));
    
    // Generate JSON output for GitHub Actions
    JSONValue json;
    json["baseline"] = JSONValue([
        "time": JSONValue(baselineResult.compileSecs),
        "memory": JSONValue(baselineResult.memoryMB),
        "command": JSONValue(baselineResult.command)
    ]);
    json["modified"] = JSONValue([
        "time": JSONValue(modifiedResult.compileSecs),
        "memory": JSONValue(modifiedResult.memoryMB),
        "command": JSONValue(modifiedResult.command)
    ]);
    
    // Calculate differences
    double timeDiff = modifiedResult.compileSecs - baselineResult.compileSecs;
    double timePercent = (timeDiff / baselineResult.compileSecs) * 100;
    double memDiff = modifiedResult.memoryMB - baselineResult.memoryMB;
    double memPercent = (memDiff / baselineResult.memoryMB) * 100;
    
    json["diff"] = JSONValue([
        "time": JSONValue(timeDiff),
        "timePercent": JSONValue(timePercent),
        "memory": JSONValue(memDiff),
        "memoryPercent": JSONValue(memPercent)
    ]);
    
    // Write JSON to stdout for GitHub Actions
    std.file.write("benchmark_results.json", json.toString(true));
    writeln("\nJSON results saved to benchmark_results.json");
} 