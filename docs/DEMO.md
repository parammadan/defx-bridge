# Demo guide

**Recorded demo video:** [YouTube (unlisted, AI-narrated)](https://youtu.be/h273icslijc), with a backup [MP4 on the v0.1.0 release](https://github.com/parammadan/defx-bridge/releases/download/v0.1.0/DEFX_Bridge_Demo_voiced.mp4). Its build and provenance are described in [demo/video_manifest.md](../demo/video_manifest.md).

Everything below was run on this machine (R 4.6.1, macOS 26.4, arm64). The quoted outputs are copied from those runs. Each command takes about 0.4–1 s.

**Before the call:** run `./scripts/demo.sh` once (with `DEMO_NO_PAUSE=1`) so `artifacts/` exists. Enlarge the terminal font. Have `examples/valid/makeadae.sas` open in an editor, and keep Excel/Numbers closed until the last step.

## A. 60–90 second live script

Run from the repository root (`cd ~/defx-bridge`).

**0–15 s: the published concept, in SAS**

```bash
sed -n '27,33p' examples/valid/makeadae.sas
```
You'll see three `/* DEFX | ADAE.AERELFL | ... */` lines followed by the SAS code they describe, then a `Comments` tag.

> "This is the DEFX tag syntax from Brendan and Megan's PharmaSUG paper. The comment that documents the code for review is also the define.xml method. Three lines here are one method, not three duplicates."

**15–30 s: the same syntax in R**

```bash
grep -n "DEFX |" examples/valid/makeadsl.R | head -8
```
You'll see `# DEFX | ADSL | Comments | ...`, `# DEFX | STUDYID | Assigned`, and the `Predecessor | DM.*` lines.

> "Same syntax as an R comment. The goal is that a study whose derivations move from SAS to R can keep one documentation system."

**30–45 s: scan both languages with provenance**

```bash
./bin/defxbridge scan --source examples/valid --spec examples/spec.csv --out artifacts/scan.csv
```
Expected header:
```
Programs scanned : 3 (SAS 1, R 2)
Tag lines found  : 48
Records          : 40 (SAS 15, R 25; 5 multi-line)
```
Point at the row `makeadae.sas:27;28;29  SAS  ADAE.AERELFL  Computation  Derived  Y if AE.AEREL="RELATED" N if …`. It ends with `Scan OK: 0 error(s), 0 warning(s), 0 info`.

> "48 tag lines become 40 definitions. Every record keeps its file and every contributing line. R is read with R's own tokenizer and nothing is executed, so the decoy `"# DEFX | ..."` strings in both files are ignored."

**45–60 s: validate against an explicit spec**

```bash
./bin/defxbridge validate --source examples/valid --spec examples/spec.csv
```
Expected: `Validation PASSED: 0 error(s), 0 warning(s), 0 info` (exit 0).

**60–75 s: a deliberately invalid reference**

```bash
./bin/defxbridge validate --source examples/invalid/unknown_variable.R --spec examples/spec.csv; echo "exit $?"
```
Expected:
```
  [ERROR V002] unknown_variable.R:2  ADAE.DOESNOTEXIST is not in the specification
      fix: check the variable name; ADAE is a known dataset

Validation FAILED: 1 error(s), 0 warning(s), 0 info
exit 2
```
Backup if asked about duplicates:

```bash
./bin/defxbridge validate --source examples/invalid/conflicting_definitions --spec examples/spec.csv
```
This shows `[ERROR V003] first.sas:2 ... also at: second.R:2`, and the reverse.

**75–90 s: workbook**

```bash
./bin/defxbridge export --source examples/valid --spec examples/spec.csv \
  --template examples/define_like_template.xlsx --out artifacts/define_like_filled.xlsx
open artifacts/define_like_filled.xlsx
```
Expected: 18 checks, all `PASS`, ending with `sentinel 'DO_NOT_CHANGE' count unchanged  PASS  template 5, output 5`. Then:
```
Workbook         : artifacts/define_like_filled.xlsx
  Methods rows 18, Comments rows 5, Variables rows updated 34, Datasets rows updated 3
Export OK: 0 error(s), 0 warning(s), 0 info
```
In Excel, show the **Methods** sheet: the `ADAE.AERELFL` description is the three lines joined, while `Expression Code` still reads `DO_NOT_CHANGE`. On the **Variables** sheet, `ADAE.AERELFL` Origin changed from the stale `Assigned` to `Derived`, and the hand-entered `ADSL.SEX` row is untouched.

> "It writes to a copy, re-reads the result, and only keeps it if everything outside the DEFX columns is identical. That's how SAS and R programs could feed one define workbook during an incremental move to R. The workbook here is synthetic, not a Pinnacle 21 template."

If time is short, skip the 45–60 s step: validation also runs inside `export`.

## B. Recording plan (local, no upload)

1. **Setup.** 1920×1080, terminal font around 18 pt, dark theme, clean prompt (`PS1='$ '`). Close notifications. `cd ~/defx-bridge && DEMO_NO_PAUSE=1 ./scripts/demo.sh >/dev/null`.
2. **Shot 1 (editor, 10 s).** `examples/valid/makeadae.sas` lines 27–33. Slowly highlight the three AERELFL tags.
3. **Shot 2 (editor, 10 s).** `examples/valid/makeadsl.R` lines 9–22, including the decoy string on line 49.
4. **Shot 3 (terminal, 15 s).** `scan` command. Pause on the header and the `27;28;29` row.
5. **Shot 4 (terminal, 10 s).** `validate` on valid → PASSED.
6. **Shot 5 (terminal, 15 s).** `validate` on `unknown_variable.R` → V002 and `exit 2`. Optionally the V003 conflict.
7. **Shot 6 (terminal, 10 s).** `export` → preservation table.
8. **Shot 7 (Excel, 15 s).** Methods sheet (AERELFL row), Variables sheet (AERELFL, STUDYID ×3, SEX), PreserveMe sheet.
9. **End card (5 s).** "Independent prototype inspired by Bartley & Hinger, PharmaSUG 2026 AP-220. Synthetic data. Not affiliated with or endorsed by CBAR or PharmaSUG."

Record with QuickTime (File → New Screen Recording) and keep the file local.

## C. Likely technical questions

**1. Why R instead of reimplementing the full SAS macro?**
The macro already works for SAS-only studies, and the published appendix is intentionally shortened. Copying it would add nothing. The gap I wanted to explore is mixed-language studies: the same tags in R comments, normalized into one table with the SAS ones. I wrote it from the published description and did not port the code. Base R plus openxlsx keeps dependencies small, and no SAS licence is needed to run it.

**2. How are duplicates distinguished from multi-line documentation?**
Consolidation runs before conflict detection. Lines sharing *(program, name, type)* are merged in source order into one record, as the macro groups by Program/Name/Type. The ownership check (V003) then looks for one name in *more than one program*. Repeated lines in one file can't trigger it, and a test asserts exactly that. If a continuation line forgets its type (`Imputation` on line 1 but not line 2), the lines become two origin types in one program, and V006 says "repeat the same type on every line".

**3. How is provenance preserved?**
Every segment keeps its file, line, column and exact raw comment. A record keeps `source_line` (first), `source_lines` (all, e.g. `27;28;29`), `segment_count` and all raw comments. Diagnostics carry file:line, plus `related` locations for conflicts. Export writes `<out>_meta.csv` with all of it, which plays the role of the macro's METALIB metadata dataset.

**4. How do we know the export didn't corrupt unrelated metadata?**
It never writes the template. The output goes to a temp file, which is re-read with readxl, a different library from the writer, and compared with the template on sheet names and order, other sheets cell-for-cell, non-DEFX columns, untargeted rows, Methods rows' extra columns, and the sentinel count. Only then is it renamed into place. Tests also check the template's md5 before and after. A mutation that changed one cell on the PreserveMe sheet made 7 tests fail. Limits: cell values and structure are tested, but formulas, macros and every style detail are not promised.

**5. How could this support incremental SAS-to-R migration?**
When one ADaM program is rewritten in R, its tags move with it unchanged. The SAS and R programs are scanned together, and V003 catches the transition mistake of both versions documenting the same variable. The workbook doesn't care which language a tag came from, and the equivalence test shows that identical SAS and R tags normalize to identical records.

**6. What still needs CBAR's original code or environment?**
- Running both tools on the same real programs and comparing outputs.
- A real Pinnacle 21 define.xlsx (sheet and column names, extra sheets, styles).
- The production KEEPTAGS semantics: the paper's prose and Table 2 read slightly differently.
- The parameter checks removed from the published appendix.
- `defxit`'s real interface.

All of these are listed in docs/COMPATIBILITY.md section E.

**7. What is deterministic, and what still needs human review?**
Deterministic: tag syntax, targets against the spec, single-program ownership, one origin per target, predecessor structure (and existence when in scope), template coverage, workbook preservation, and repeatable output. Human review: whether the description matches the code, whether the derivation is right, and whether the spec itself is right. The paper says these comments are reviewed and validated by a person before the final run, and this tool doesn't change that.

**8. How would it evolve if researchers wanted to adopt it?**
1. Run it next to the SAS macro on real studies and reconcile any differences.
2. Point it at real P21 workbooks and read the spec straight from the Variables tab.
3. Package it with an internal repo or renv lockfile and add CI.
4. Optionally add value-level metadata and Rmd/qmd scanning.
5. Keep the conservative defaults (refuse on errors, never overwrite) unless the team decides otherwise.
