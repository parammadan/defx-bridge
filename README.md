# DEFX Bridge

An independent R prototype that reads **DEFX documentation tags** from **SAS and R** programs, normalizes them into one provenance-preserving metadata table, validates them against an explicit specification, and fills a **synthetic, define-like Excel workbook**.

> DEFX Bridge is an independently developed prototype exploring R-compatible metadata extraction inspired by the published DEFX approach. It is not affiliated with or endorsed by CBAR or PharmaSUG.

It is **not** an implementation of the original DEFX macro, **not** a reproduction of any production workflow, and **not** a clinically validated or regulatory-certified tool. All data in this repository is synthetic.

## Why

The published DEFX concept (Bartley & Hinger, PharmaSUG 2026, AP-220) turns the comments programmers already write into define.xml content. A `/* DEFX | ADAE.AERELFL | Y if AE.AEREL="RELATED" */` comment documents the code for review *and* fills the Methods/Variables sheets of the define workbook. Teams moving some derivations from SAS to R would need the same tags to work in both languages, so one study's metadata can come from mixed SAS/R programs. DEFX Bridge explores that idea:

```sas
/* DEFX | ADAE.AERELFL | Y if AE.AEREL="RELATED" */        <- makeadae.sas
```
```r
# DEFX | ADSL.SAFFL | Y if the participant received any dose  <- makeadsl.R
```

Both become rows in the same normalized table with `file:line` provenance, pass the same validation rules, and land in the same workbook.

## Install

Requirements: R ≥ 4.1 (developed on R 4.6.1, macOS arm64), plus:

```bash
Rscript -e 'install.packages(c("openxlsx", "readxl", "testthat", "withr"))'
```

`openxlsx` is required at runtime. `readxl` is optional at runtime: it is used as an independent reader when verifying the exported workbook, with a fallback to openxlsx. `testthat` and `withr` are only needed for tests. No SAS installation, network, server, database or API key is needed.

You don't have to install the package. `bin/defxbridge` sources `R/*.R` straight from the checkout:

```bash
./bin/defxbridge --help
```

## Commands

```bash
# 1. Extract + normalize tags (syntax checks only)
./bin/defxbridge scan --source examples/valid --out artifacts/scan.csv

# 2. Validate against the specification
./bin/defxbridge validate --source examples/valid --spec examples/spec.csv --out artifacts/validation.csv

# 3. Validate, then fill a COPY of the define-like template
./bin/defxbridge export --source examples/valid --spec examples/spec.csv \
  --template examples/define_like_template.xlsx --out artifacts/define_like_filled.xlsx

# Intentionally invalid input (exits 2)
./bin/defxbridge validate --source examples/invalid --spec examples/spec.csv

# Content comparison of two workbooks (repeatability)
./bin/defxbridge compare artifacts/a.xlsx artifacts/b.xlsx
```

| Exit code | Meaning |
|---|---|
| 0 | success (warnings and info are allowed) |
| 2 | validation found at least one error. `export` writes no workbook |
| 1 | usage or runtime error (bad option, missing file, invalid spec or template) |

`--source` can be repeated and accepts directories (searched recursively by default; `--no-recursive` limits the search to one level) or single files. Relative paths resolve against your current directory, and the script works from any directory. Run `defxbridge <command> --help` for every option.

## Supported syntax

The same syntax works in a SAS `/* ... */` comment or an R `#` comment:

| Pattern | Example |
|---|---|
| Computation (default type) | `DEFX \| ADAE.AERELFL \| Y if AE.AEREL="RELATED"` |
| Imputation | `DEFX \| ADAE.ASTDT \| Imputation \| day 1 imputed when missing` |
| Predecessor | `DEFX \| ADAE.AETERM \| Predecessor \| AE.AETERM` |
| Assigned | `DEFX \| ADAE.PARAMCD \| Assigned` |
| Variable comment | `DEFX \| ADAE.AERELFL \| Comments \| text` |
| Dataset comment | `DEFX \| ADAE \| Comments \| text` |
| Variable in every dataset | `DEFX \| STUDYID \| Assigned` |
| Parameter-level method (Methods only) | `DEFX \| AVAL.ADVS.PARAMCD.EQ.SYSBP \| text` or `DEFX \| ADVS.AVAL.PULSE \| text` |
| Multi-line description | repeat the same name **and type** on consecutive tag lines |

Keywords, types and identifiers are case-insensitive, and identifiers are upper-cased. Whitespace around `|` is ignored. The description text is kept as written: quotes, punctuation and Unicode are preserved, inner spacing is preserved, and nothing is truncated. A description cannot contain `|`, so that case is reported instead of guessed at.

**What is read as a comment.** R files go through R's own tokenizer (`parse()` + `getParseData()`), which never runs the code, so `"# DEFX | ..."` inside a string is ignored. SAS files go through a small conservative lexer that skips `'...'` and `"..."` strings (with doubled-quote escapes) and DATALINES/CARDS blocks. In SAS, only **single-line `/* DEFX | ... */`** comments are tags. A DEFX line inside a multi-line `/* */` comment is reported as V001. A DEFX tag in a `* ... ;` statement comment gets a V012 warning and is ignored. This is not a full SAS parser. Macro quoting (`%str`, `%nrstr`, ...) is not interpreted. Details are in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Validation

| Code | Severity | Check |
|---|---|---|
| V001 | error | Malformed tag: no name, empty field, extra `\|`, comma or invalid identifier, unsupported name form, tag inside a multi-line block comment |
| V002 | error | Target (dataset.variable, variable, or parameter method's dataset.variable) not in the specification |
| V003 | error | The same target defined (or commented) in more than one program. Every location is reported |
| V004 | error | Unsupported type, `Assigned` with a description, a non-Comments tag on a dataset, or Predecessor/Assigned/Comments on a parameter-level name |
| V005 | error | Predecessor is not one `Dataset.Variable`, refers to itself, or is missing from an in-scope dataset |
| V006 | error | Conflicting origins for one target in one program, or a variable-only tag overlapping a dataset-specific tag |
| V007 | exit 1 | Specification missing, unreadable, without Dataset/Variable columns, empty, or with blank/invalid identifiers |
| V008 | error | File unreadable, R syntax error, or unterminated SAS comment/string |
| V009 | error | (export) Tagged target has no row in the template |
| V010 / V012 | warning | DEFX-like comment without `\|`, or in a SAS statement comment. Ignored |
| V011 | info | Predecessor dataset outside the specification: structure checked, existence not verified |
| V013 | warning | (export) Variables/Datasets reference a Method/Comment ID that is not in the output |
| V014 | warning | No DEFX tags found |

Repeated description lines in **one** program are consolidated into a single definition, so they are never flagged as duplicates. Comments tags coexist with a variable's computation or origin tag. The specification only establishes which targets exist. **Nothing here checks that a derivation is clinically or mathematically correct, and a passing run is not evidence of CDISC or Pinnacle 21 conformance.** See [docs/VALIDATION.md](docs/VALIDATION.md).

## Workbook mapping

| Tag | Variables | Methods | Comments | Datasets |
|---|---|---|---|---|
| Computation / Imputation | Origin=`Derived`, Method=`<name>` | ID=Name=`<name>`, Type, Description | | |
| Predecessor | Origin=`Predecessor`, Predecessor=`<ref>` | | | |
| Assigned | Origin=`Assigned` | | | |
| Variable Comments | Comment=`<name>` | | ID=`<name>`, Description | |
| Dataset Comments | | | ID=`<dataset>`, Description | Comment=`<dataset>` |
| Variable-only tag | applied to that variable in every dataset | as above | as above | |
| Parameter-level method | (unchanged) | ID=Name=`<name>` | | |

As in the paper, method and comment IDs are the tag name. Only those tag-owned columns change, and only on rows that a tag targets. All other sheets, columns, rows and values are left alone. Methods/Comments rows from the template that match no tag are dropped by default, which is analogous to the paper's `KEEPTAGS=N`. Pass `--keep-unmatched` to keep them. Matched rows keep their non-DEFX columns (e.g. `Expression Code`).

Export never overwrites the template. It writes a temporary file next to `--out`, re-opens it, and checks the following against the template:

- sheet names and order
- identical cell text on non-DEFX sheets
- unchanged non-DEFX columns and untargeted rows
- unchanged headers
- the count of the `DO_NOT_CHANGE` sentinel

Only if every check passes is the file renamed into place. It also writes `<out>_meta.csv`, a traceability table of every record used, which plays the role of the paper's metadata dataset, and `<out>_report.md`.

The template `examples/define_like_template.xlsx` is synthetic and only imitates the general shape of a define.xlsx. It is **not** a Pinnacle 21 template. Preservation is tested for cell values and sheet structure. Formulas, macros, data validation, conditional formatting and every style detail are **not** promised.

## Synthetic data

`examples/` contains made-up programs (`makeadae.sas`, `makeadsl.R`, `makeadvs.R`), a 71-row specification (ADaM-like ADSL/ADAE/ADVS plus SDTM-like DM/AE/VS/EX, so explicit predecessors can be verified), the template, and invalid examples. No real study or participant data is used. Regenerate the spec and template with `Rscript scripts/create_fixtures.R`.

## Tests and demo

```bash
Rscript -e 'testthat::test_local(".")'     # parser, validation, workbook, real CLI runs
./scripts/demo.sh                          # interview walkthrough (DEMO_NO_PAUSE=1 to run straight through)
```

The CLI tests run `bin/defxbridge` and need the repository layout. Under `R CMD check` (which ignores `examples/` and `bin/`) those tests skip.

## Limitations

- Lexical, not semantic: SAS support covers the comment forms listed above. Macro-generated comments, `%include`d files, macro quoting and SAS line-length/encoding quirks are not handled.
- `.Rmd`/`.qmd` files are not scanned.
- The specification is a flat Dataset/Variable list. Value-level metadata and codelists are not validated.
- The Variables-sheet update rules intentionally differ from the paper's macro in a few places (see [docs/COMPATIBILITY.md](docs/COMPATIBILITY.md)), and nothing has been compared against the original macro's output on the same inputs.
- Compatibility with real Pinnacle 21 define.xlsx files is unverified.

## Attribution

- Brendan Bartley and Megan Hinger, *Do One Task, Get Another Done for Free: Use DEFX Tags in Comments to Fill Out Your define.xml*, PharmaSUG 2026, Paper AP-220. <https://pharmasug.org/proceedings/2026/AP/PharmaSUG-2026-AP-220.pdf>
- Per the paper's acknowledgments, Megan Hinger created the DEFX macro, Scott Anderson created the `defxit` command-line script, and Shawn Ward heavily tested the original program.

DEFX Bridge is a separate implementation written from the published description. No code from the paper's appendix was copied, and no internal repository or code was used. The tag syntax follows the paper so that the same comments can be read by both tools.

## Layout

```
R/            discovery, parser (SAS lexer + R tokenizer), normalize, validate, workbook, reports, cli
bin/          defxbridge (bash entry point) -> inst/cli/run.R
examples/     valid/, invalid/, spec.csv, define_like_template.xlsx (all synthetic)
scripts/      demo.sh, create_fixtures.R
tests/        testthat suites
docs/         ARCHITECTURE, COMPATIBILITY, VALIDATION, DEMO
artifacts/    generated outputs (git-ignored)
```
