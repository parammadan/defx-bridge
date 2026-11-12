# Validation

Every diagnostic is one row with `code, severity, source_file, source_line, name, message, suggestion, related`. Rows are sorted by file, line and code, and written by `validate --out` as CSV plus a Markdown report. Any `error` makes `validate`/`scan` exit 2 and stops `export` from writing a workbook. Warnings and info never change the exit code.

## Codes

| Code | Severity | Raised when | Example |
|---|---|---|---|
| V001 | error | Text before the first `\|` other than `DEFX`; missing or empty name/description; more than 3 fields; comma or non-identifier characters in the name; unsupported name form; a DEFX line inside a multi-line `/* */` comment | `/* DEFX \| \| no name */` |
| V002 | error | `DS.VAR` not in spec; single name that is neither a spec dataset nor a variable; parameter method whose `DS.VAR` is not in spec | `# DEFX \| ADAE.DOESNOTEXIST \| x` |
| V003 | error | Same name + kind (origin or comment) in more than one source file. One row per location, each listing the others in `related` | `first.sas` and `second.R` both define `ADAE.AERELFL` |
| V004 | error | Unknown type; `Assigned` followed by text; a non-Comments tag on a dataset name; Predecessor/Assigned/Comments on a parameter-level name | `\| Derivation \|` |
| V005 | error | Predecessor missing, not exactly one `DS.VAR`, refers to itself, or its dataset is in the spec but the variable is not | `\| Predecessor \| AE AETERM` |
| V006 | error | One program gives one target more than one origin type (e.g. Computation + Assigned, or a continuation line that forgot `Imputation`); a variable-only tag and a dataset-specific tag both set the same Variables row | `ADAE.TRTEMFL` computed and Assigned in one file |
| V007 | exit 1 | Spec missing, unreadable, without Dataset/Variable columns, with no rows, or with blank/invalid identifiers | `--spec missing.csv` |
| V008 | error | File unreadable, R syntax error (no tags taken from that file), or unterminated SAS comment/string (tags before it are kept) | `x <- (` |
| V009 | error (export) | A tagged target has no Datasets/Variables row in the template | `DM.AGE` is in the spec but not in the define-like template |
| V010 | warning | A comment starts with DEFX but has no `\|`. Ignored | `/* DEFX ADAE.ASTDT missing delimiters */` |
| V011 | info | Predecessor dataset is outside the spec, so only its structure was checked | `\| Predecessor \| MEDDRA.SOC` |
| V012 | warning | DEFX tag in a SAS `* ... ;` statement comment. Ignored | `* DEFX \| ADAE.ASTDY \| x ;` |
| V013 | warning (export) | A Variables/Datasets cell references a Method/Comment ID that is not in the output | manual method dropped with KEEPTAGS-style default |
| V014 | warning | No usable DEFX tags found | empty programs |

Not errors by design:

- Repeated lines for one name + type in one program. That is the published multi-line pattern, consolidated into one record.
- A Comments tag next to a Computation/Imputation/Predecessor/Assigned tag for the same target.
- DEFX-like text inside strings, DATALINES, or comments that don't start with DEFX.
- Variable names mentioned inside free-text descriptions. Those are not validated.

## What the checks establish, and what they don't

**Deterministic, checked by the tool:** tag structure; that each target appears in the spec; single-program ownership; one origin per target; predecessor structure, plus existence when its dataset is in scope; that every target has a row in the template; preservation of everything else in the workbook; identical output for identical input.

**Still needs a human reviewer:** whether the description matches what the code does; whether the derivation is clinically and statistically right; whether the spec is complete and correct; whether the chosen origin is right; anything that define.xml/CDISC/Pinnacle 21 conformance rules require. The paper notes that at CBAR the comments are reviewed and validated by a person before the final run. This tool supports that review and does not replace it.

## What the automated tests establish

`tests/testthat` has 4 files covering the 25 required categories plus extras. Each test names the behaviour it checks. Last full run (R 4.6.1, macOS 26.4): **50 tests, 226 expectations, 0 failed, 0 skipped** (`Rscript -e 'testthat::test_local(".")'`). Under `R CMD check` the 13 tests that need `examples/` and `bin/` skip: Status OK, 123 passed.

| Area | File | Examples |
|---|---|---|
| Extraction & normalization | `test-parser.R` | SAS/R extraction, SAS↔R equivalence, all tag types, multi-line consolidation and order, file/line provenance, strings/raw strings/DATALINES ignored, case/whitespace, long and Unicode descriptions intact, no code execution, V008, stable file order |
| Validation | `test-validate.R` | V001–V007, V010–V012, V014; no false duplicate; Computation+Comments coexist; variable-only and parameter-level tags; spec casing; empty and missing directories; paths with spaces |
| Workbook | `test-workbook.R` | Mapping for every tag type; template unchanged (md5); sheets, columns, untagged rows and sentinel preserved; KEEPTAGS-style switch; repeatable content (and `compare` detects a real difference); V009 leaves no file or temp file |
| CLI | `test-cli.R` | Real `bin/defxbridge` runs: help, exit codes 0/1/2, no stack traces, export refuses on errors and never overwrites the template, runs from another cwd with spaces in paths, `--opt=value`, `compare` |

To check that the tests actually detect faults, three single-line mutations were applied to a scratch copy, and each made the matching tests fail. Disabling SAS string skipping failed 9 tests. Splitting consolidation by line failed 12. Changing one cell on the PreserveMe sheet during export failed 7.

Passing tests show that the tool does what this document says on the synthetic fixtures. **They are not evidence of CDISC compliance, Pinnacle 21 compatibility, or equivalence with the original DEFX macro.**
