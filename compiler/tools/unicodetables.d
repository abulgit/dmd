/**
Generates the  Unicode tables and associated Identifier tables for dmd-fe.

These tables are stored in ``dmd.common.identifiertables``.
They are C99, C11, UAX31 and a least restrictive set (All).

You can run this via ``rdmd unicodetables.d``.

You will likely only need to run this program whenever the Unicode standard updates.
It does not need to be run automatically as part of CI, as long as its kept in a working condition when committed, it only needs non-fancy features so it is unlikely to break long term.

Place the updated files from the $(LINK2 https://www.unicode.org/Public/, Unicode database) into the a directory ``UCD-<version>/``, update the ``UCDDirectory`` variable.
Make sure to commit the updated ``UCDDirectory`` variable into the repository so we can keep track of what the latest version it has been updated to.

The update procedure is similar to Phobos's Unicode table generator for ``std.uni``.
If you know one, you can do the other fairly easily.

Copyright:   Copyright (C) 1999-2025 by The D Language Foundation, All Rights Reserved
Authors:     $(LINK2 https://cattermole.co.nz, Richard (Rikki) Andrew Cattermole)
License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
*/
module unicodetables;
import unicode_tables.util;
import unicode_tables.fixedtables;
import std.stdio : File, writeln;

enum {
    // don't forget to update me when you commit new tables!
    UCDDirectory = "UCD-15.1.0/",
    UnicodeDataFile = UCDDirectory ~ "UnicodeData.txt",
    DerivedCorePropertiesFile = UCDDirectory ~ "DerivedCoreProperties.txt",

    UnicodeTableFile = "../src/dmd/common/identifiertables.d",
}

// Will disable the ASCII ranges in the generated tables.
// Disable if you are not handling elsewhere.
version = IgnoreASCIIRanges;

File tableFile;

int main(string[] args)
{
    import std.file : exists;

    if (!exists(UnicodeDataFile)) {
        writeln("Missing UCD table UnicodeData.txt");
        return 1;
    } else if (!exists(DerivedCorePropertiesFile)) {
        writeln("Missing UCD table DerivedCoreProperties.txt");
        return 2;
    }

    {
        tableFile = File(UnicodeTableFile, "w+");
        tableFile.writeln("// Generated by compiler/tools/unicode_tables.d DO NOT MODIFY!!!");
        tableFile.writeln("module dmd.common.identifiertables;");
        tableFile.writeln();
    }

    {
        import unicode_tables.unicodeData;
        import unicode_tables.derivedCoreProperties;

        parseUnicodeData(UnicodeDataFile);
        parseProperties(DerivedCorePropertiesFile);
    }

    write_XID_Start;
    tableFile.writeln;

    write_XID_Continue;
    tableFile.writeln;

    write_other_tables;
    tableFile.writeln;

    write_least_restrictive_table;

    return 0;
}

void writeTable(string name, const ValueRanges vr)
{
    tableFile.writeln("static immutable dchar[2][] ", name, " = [");

    foreach (entry; vr.ranges)
    {
        tableFile.writefln!"    [0x%X, 0x%X],"(entry.start, entry.end);
    }

    tableFile.writeln("];");
}

void write_XID_Start()
{
    import unicode_tables.derivedCoreProperties;
    import std.algorithm : sort;

    ValueRanges start = ValueRanges(propertyXID_StartRanges.ranges.dup);

    version(IgnoreASCIIRanges)
    {
        // Remove ASCII ranges as its always a waste of time, since its handles elsewhere.
        start = start.not(ASCII_Table);
    }
    else
    {
        // This may be not needed, as we'll handle ASCII elsewhere in lexer,
        //  but if we don't in some place we'll want this instead.
        start.add(ValueRange(0x5F)); // add _
        start.ranges.sort!((a, b) => a.start < b.start);
    }

    tableFile.writeln("/**");
    tableFile.writeln("UAX31 profile Start");
    tableFile.writeln("Entries: ", start.count);
    tableFile.writeln("*/");
    writeTable("UAX31_Start", start);
}

void write_XID_Continue()
{
    import unicode_tables.derivedCoreProperties;

    ValueRanges cont = ValueRanges(propertyXID_ContinueRanges.ranges.dup);

    version(IgnoreASCIIRanges)
    {
        // Remove ASCII ranges as its always a waste of time, since its handles elsewhere.
        cont = cont.not(ASCII_Table);
    }

    tableFile.writeln("/**");
    tableFile.writeln("UAX31 profile Continue");
    tableFile.writeln("Entries: ", cont.count);
    tableFile.writeln("*/");
    writeTable("UAX31_Continue", cont);
}

void write_other_tables()
{
    tableFile.writeln("/**");
    tableFile.writeln("C99 Start");
    tableFile.writeln("Entries: ", c99_Table.count);
    tableFile.writeln("*/");
    tableFile.writeln("alias FixedTable_C99_Start = FixedTable_C99_Continue;");
    tableFile.writeln;

    tableFile.writeln("/**");
    tableFile.writeln("C99 Continue");
    tableFile.writeln("Entries: ", c99_Table.count);
    tableFile.writeln("*/");
    writeTable("FixedTable_C99_Continue", c99_Table);
    tableFile.writeln;

    tableFile.writeln("/**");
    tableFile.writeln("C11 Start");
    tableFile.writeln("Entries: ", c11_Table.count);
    tableFile.writeln("*/");
    tableFile.writeln("alias FixedTable_C11_Start = FixedTable_C11_Continue;");
    tableFile.writeln;

    tableFile.writeln("/**");
    tableFile.writeln("C11 Continue");
    tableFile.writeln("Entries: ", c11_Table.count);
    tableFile.writeln("*/");
    writeTable("FixedTable_C11_Continue", c11_Table);
}

void write_least_restrictive_table() {
    import unicode_tables.derivedCoreProperties;

    ValueRanges toMerge = c99_Table.merge(c11_Table);
    ValueRanges lrs = propertyXID_StartRanges.merge(toMerge);
    ValueRanges lrc = propertyXID_ContinueRanges.merge(toMerge);
    ValueRanges lr = lrs.merge(lrc);

    version(IgnoreASCIIRanges)
    {
        // Remove ASCII ranges as its always a waste of time, since its handles elsewhere.
        lrs = lrs.not(ASCII_Table);
        lrc = lrc.not(ASCII_Table);
        lr = lr.not(ASCII_Table);
    }

    tableFile.writeln("/**");
    tableFile.writeln("Least restrictive with both Start and Continue");
    tableFile.writeln("Entries: ", lr.count);
    tableFile.writeln("*/");
    writeTable("LeastRestrictive_OfAll", lr);
    tableFile.writeln;

    tableFile.writeln("/**");
    tableFile.writeln("Least restrictive Start");
    tableFile.writeln("Entries: ", lrs.count);
    tableFile.writeln("*/");
    writeTable("LeastRestrictive_Start", lrs);
    tableFile.writeln;

    tableFile.writeln("/**");
    tableFile.writeln("Least restrictive Continue");
    tableFile.writeln("Entries: ", lrc.count);
    tableFile.writeln("*/");
    writeTable("LeastRestrictive_Continue", lrc);
}
