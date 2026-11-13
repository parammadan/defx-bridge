# DEFX Bridge: independent engineering audit and completion assessment

**Date:** 2026-11-12.

**How the audit was done:**

- An independent reviewer, a fresh agent with no access to the author's conclusions, read the code, tests, fixtures and workflows. It worked only on a scratch copy and was asked to reproduce every claim.
- Each defect it reported was then **re-run by hand** before being accepted, then fixed with a regression test.
- Each regression test was checked to **fail on the pre-fix code**: 12 of the 14 new tests fail there. The other 2 cover behaviour that was already correct but untested.
- Separately, the docs were checked against the code.

**Baseline before the audit:** 52 tests, 236 expectations, all passing, CI green.

**After:** 66 tests and 273 expectations, all passing locally and in CI (run 43340253913, commit `9bdd0c9`), 0 skipped. `R CMD check` Status OK (138 pass, 23 skip by design).

---

## 1. Executive findings

- **The passing test suite overstated the quality.** Twelve reproducible defects passed all 236 checks. Seven were data-loss or misleading-success problems in the workbook export and CLI, which is exactly the part the README called "verified".
- **The workbook preservation guarantee was weaker than documented.**
  - Export rewrote whole sheets, so in non-DEFX cells a formula became a static value, numbers became text and dates became serial-number text. All checks still said PASS.
  - The verifier only checked what was *not* targeted, never that the targeted cells held the tag values.
- **The mutation claims were true but cherry-picked.** Three of the auditor's six one-line mutations survived the whole suite. Among them: "verify_export always PASS" and "V013 never emitted".
- **What was solid:**
  - the tag grammar
  - the R extraction, which uses R's own parser
  - string and DATALINES handling in the common cases
  - provenance
  - deterministic output: byte-identical results under the C, en_US and da_DK locales
  - the end-to-end trace of ADAE.AERELFL into the workbook
  - CLI exit codes and piping
- **All P0 and P1 defects found have been fixed**, each with a regression test, and CI is green. What's left is documented below. None of it is a P0 within the prototype's supported scope.
- **Recommendation: freeze the code for the interview.** More features now would add risk without adding evidence.

## 2. Technical complexity (candid, 1–10)

| Component | Rating | Why |
|---|---|---|
| SAS comment lexer (`lex_sas_comments`) | **3–4** | A single-pass state machine: block and statement comments, quotes with doubled-quote escapes, DATALINES/DATALINES4. It isn't macro-aware. This is the part that earns its keep over grep. |
| R extraction | **1** | Delegates to `parse()` + `getParseData()`. That's the right call, and the work is trivial. |
| Tag grammar (`parse_defx_tag`) | **2** | Split on `\|`, branch on the number of fields, plus a few regexes. |
| Normalization | **2** | A group-by on (file, name, type) plus a `paste`. |
| Validation (V001–V014) | **3** | About 14 set-membership and group-by rules. The subtle part is ordering: consolidation runs before conflict detection. |
| Workbook export + verification | **4–5** | An openxlsx round-trip, cell-level writes, and a read-back with a second library comparing against the template and the intended values. Most of the care is defensive. |
| CLI | **2** | A hand-rolled argument parser, exit codes and output guards. |
| Tests | **3** | Example-based, with reasonable negative coverage. No property or fuzz tests. |
| **Overall** | **≈3/10** | A small, careful tool, not a hard algorithmic problem. |

**Could it be simpler?** Yes, by about half (~300 lines): regex extraction for R, `aggregate`/dplyr for consolidation, and anti-joins for V002/V003/V006. Two parts shouldn't be simplified:

1. the SAS lexer, because grep can't tell strings from comments
2. cell-level workbook writes, which are what make the preservation claim true

## 3. Verified strengths (evidence)

- **Same results from SAS and R:** equivalent SAS and R tags normalize to identical records (`test-parser.R`, "equivalent SAS and R tags…").
- **No code execution:** a test writes an R file containing `file.create(marker)` and `stop()`, scans it, and checks the marker was never created.
- **The ADAE.AERELFL trace is correct:** lines 27–29 in `makeadae.sas` become one Computation record (`makeadae.sas:27;28;29`). In the workbook:
  - Variables Origin goes from `Assigned` (template) to `Derived`, with Method = Comment = `ADAE.AERELFL`.
  - The Methods row's Description is the three lines joined, and its `Expression Code` (`DO_NOT_CHANGE`) is kept.
  - All 15 Method references resolve.
- **Determinism:** outputs are byte-identical across three locales, and the CSV md5 matches across runs.
- **CLI:** exit codes 0/2/1, no stack traces on bad input, paths with spaces, symlinked `bin/`, a missing Rscript, and `| head` with 6,000 records (still exits 0 and writes its CSV).
- **Lexer:** CRLF, BOM, tabs, a missing final newline, a 200 KB line, doubled quotes, `/*` inside strings, `*` used as multiplication, `%*` comments and `cards4` all handled correctly.

## 4. Confirmed defects (each reproduced, then fixed)

| ID | Sev | Defect (repro) | Fix | Regression test |
|---|---|---|---|---|
| D1 | P1 | A comment before `datalines;` meant the data block wasn't recognised. Result: a false V008 "unterminated ' string" on `O'Brien`, every later tag lost, exit 2. (`/* raw names follow */` then `datalines;`) | Strip block comments from the statement text before matching (`(?s)/\*.*?\*/`) | D1 |
| D2 | P1 | One non-UTF-8 (Latin-1) byte crashed the **whole run** (`runtime error: missing value where TRUE/FALSE needed`, exit 1), with no file named and nothing scanned. | Check with `validUTF8()`: V008 for that file, naming the first bad line, and every other file still scans | D2 |
| D3 | **P0** | `--out` set to an existing directory: the rename failed, the temp file was copied *into* the directory, and the tool printed "Export OK", exit 0. | Input error "--out is a directory" | D3 |
| D4 | **P0** | Whole-sheet `deleteData` + `writeData` changed non-DEFX cells: formula `=C2*2` became the text "16", numbers became text, and a date became the text "46037". All checks PASSed. | Datasets/Variables are now written **cell by cell, owned cells of targeted rows only**. Every other cell is never rewritten. | D4 (formula + number survive) |
| D5 | **P0** | `verify_export` never checked that targeted cells held the tag values. Sabotaging every Methods Description still passed. | 4 new checks: "tagged cells hold the tag values" (Datasets, Variables) and "rows equal the tag-built sheet" (Methods, Comments) | D5 ×2 (detection, refusal branch) |
| D6 | **P0** | Pointing `--source` at a folder with no tags exported exit 0 with empty Methods/Comments, wiping manual rows. It was only refused by accident, by the fixture's sentinel. | Export refuses (exit 1) when there are zero records | D6/D10 |
| D7 | P1 | The sentinel count included Methods rows that KEEPTAGS=N is *supposed* to drop, so a legitimate export failed. On real templates the check was always a vacuous 0 = 0. | Count only where content must survive: other sheets, Datasets, Variables, and Methods/Comments rows present in both files | D7 |
| D8 | P1 | `AVAL.ADVS.PARAMCD.EQ.SYSBP` (a.sas) and `ADVS.AVAL.SYSBP` (b.R) describe the same parameter. There was no V003, and two Methods rows were produced. | V003/V006 group parameter tags by (dataset, variable, value) | D8 |
| D9 | P1 | With `--keep-unmatched`, a Methods note row with a blank ID was silently deleted, and checks PASSed. | Unmatched rows are kept even when the ID is blank | D9 |
| D10 | **P0** | `validate --out spec.csv` or `scan --out makeadsl.R` overwrote the spec or the source program with CSV, exit 0. | `guard_outputs()`: no output may overwrite the spec, the template or a scanned program (case-insensitive) | D6/D10 |
| D11 | P1 | An unterminated `datalines4;` swallowed the rest of the file: 0 tags and **no diagnostic**. | V008 "never closed with ;;;;" (and the same for plain DATALINES) | D11 |
| D13 | P2 | An unnamed warning (V010) on the same line marked a *different*, valid record as "warning". | Status matches diagnostics by name | D13 |
| D16 | P2 | `ADSL.1AGE` was accepted. | Dataset/variable parts must be SAS-style names; only a trailing parameter value may start with a digit | D16 |

**Found while fixing:**

- My own new output guard crashed every CLI call that had no output paths (`normalizePath(NULL)`). The existing CLI tests caught it before commit.
- A codoc WARNING in `R CMD check`: the Rd page was stale after `verify_export()` gained an argument. CI caught that one, and the Rd was regenerated.

## 5. Not fixed (documented, by severity)

| ID | Sev | Issue | Why left |
|---|---|---|---|
| WB-M | P1 (Level 2) | Methods/Comments are still **rebuilt** because rows are re-sorted. Cell types of their non-DEFX columns are written back as read, formulas there are lost, and styles stay at the old row positions. | It would need a row-mapping writer. The tag-owned columns *are* verified, and so are matched rows' non-DEFX text. Documented. |
| D14 | P2 | If one line of a multi-line tag is malformed (V004), the other lines still form an "ok" record with a partial description. Export is still blocked by the error. | Export can't go ahead anyway. A UX issue only. |
| D15 | P2 | A variable-only Predecessor that refers to itself through a dataset (`AETERM` → `ADAE.AETERM`) isn't flagged. | An edge of an edge. |
| D12 | P2 | A Variables column with no header gives a misleading "same rows, columns and header FAIL". | Safe (it refuses), just unclear. |
| D17 | P2 | A read-only `--out` file is replaced, and its permissions become 644. | Arguably correct, but undocumented. |
| SAS-1 | P1 (Level 2/3, speculative) | A `*` comment right after a macro call with no `;` is probably lexed as code. `/*` inside a `*…;` comment isn't honoured. Macro quoting and `%include` aren't handled. | Needs real macro-heavy programs to judge. Not reproduced on shipped fixtures. |
| CI-1 | P2 | CI runs on Ubuntu only, while development was on macOS. | Cost and benefit before the interview. |

## 6. Test coverage

**Gaps closed by this audit:**

- non-UTF-8 input
- DATALINES after a comment, and unterminated DATALINES4
- formulas and numbers in non-DEFX cells
- `--out` as a directory, or equal to the spec or source
- zero-tag export
- blank-ID rows with keep-unmatched
- alias parameter names
- **the refusal branch when verification fails**
- **V013 actually being emitted**
- a vacuous V003 assertion (`all(logical(0))` is TRUE), now an exact equality

**Still not covered:**

- property or fuzz tests of the lexer
- Windows
- large repositories (performance)
- real Pinnacle 21 workbooks
- real production SAS programs
- styles and data validation in workbooks
- a "same name and type far apart in one program" duplicate-hiding test. Merging them is a design choice, not a bug.

**What the tests mean now:** example-based checks that each documented rule and each audited defect behaves as stated, on synthetic fixtures. They are not evidence of CDISC conformance or Pinnacle 21 compatibility.

## 7. Architectural trade-offs

- **Lexing vs grep.** Lexing costs about 110 lines and buys correctness on strings, DATALINES and R syntax. The original macro's grep is simpler and fine for disciplined SAS shops.
- **Explicit spec CSV vs the define.xlsx Variables tab.** The CSV gives a separate validation source, so explicit predecessors such as SDTM variables can be checked. The cost is one more artifact to maintain, whereas the paper validates against the workbook itself.
- **Refusing the whole export on any error vs the macro's skip-and-continue.** Refusing means a "successful" workbook can't be silently missing definitions. Skip-and-continue is friendlier in a reviewed, mature workflow.
- **Rebuilding Methods/Comments vs editing rows in place.** Rebuilding is simpler and matches KEEPTAGS=N semantics, but it loses formatting in those sheets. That's the main remaining integrity trade-off.
- **Verifying after write.** The verifier exists partly to make up for the rewrite strategy. With cell-level writes for Datasets/Variables, it is now a second line of defence rather than the only one.

## 8. Production adoption gaps

**Compatibility with real DEFX workflows:**

- It has never been run against the original macro or `defxit` on the same programs.
- The KEEPTAGS semantics are ambiguous between the paper's prose and its Table 2.
- The Variables merge rules intentionally differ.

**SAS parsing:**

- Macro-heavy code, `%include`, macro quoting and macro-generated comments aren't handled.
- WLATIN1 programs now produce a clear V008 asking for conversion; there is no transcoding.

**Real workbook schemas:**

- It hasn't been tested on a Pinnacle 21-generated define.xlsx: sheet and column names, ValueLevel/WhereClauses, Codelists, Documents.
- Formatting in Methods/Comments isn't preserved.

**Error recovery:** all-or-nothing export. There's no partial export with a report, which a team might prefer.

**Metadata ownership:**

- "One program per target" is enforced, but there's no notion of an approved owner, a review status, or a change history per method.
- A same-name, same-type duplicate within one program is merged silently.

**Scale:** a single-threaded character loop in R. Fine for dozens of programs; unmeasured at hundreds or thousands.

**Documentation:** there is no vignette or user guide on a real study layout, and no SOP-style instructions.

**Researcher usability:**

- It needs a hand-built spec.
- There's no RStudio addin or Shiny review page.
- Installation is a git checkout, not an internal repository or renv lockfile.

**Review and approval:** there's no sign-off record, no diff-against-last-define report, and no reviewer workflow. The paper's process has a human validate the comments.

**Scientific and regulatory validation:**

- no IQ/OQ/PQ
- no validation plan or traceability matrix
- no 21 CFR Part 11 considerations (audit trail, e-signature)
- no independent double programming of the output

## 9. Comparison with the published DEFX approach

| Aspect | Published DEFX | DEFX Bridge |
|---|---|---|
| Languages | SAS | SAS and R (identical normalization) |
| Discovery | `grep` for DEFX and `\|` | A lexer: strings, DATALINES and R syntax are respected |
| Validation source | The define.xlsx Variables tab | An explicit spec CSV, plus a template-coverage check |
| Duplicates | Same name in more than one program: flagged and skipped | V003 with every location; the parameter spellings are unified (D8) |
| Errors | Skip the flagged tags, write the rest | Refuse the whole export |
| Output | Overwrites DEFXLSX by default | Never overwrites the template; writes cell by cell; verified read-back |
| Maturity | In production use at CBAR, reviewed by people | A prototype on synthetic fixtures |

DEFX Bridge is a companion that explores the R side. It is not a replacement, and it has never been compared with the original.

## 10. Completion assessment

### Level 1: portfolio prototype

| Criterion | Evidence | Status |
|---|---|---|
| Functionally complete vs the agreed MVP | Every MVP item plus the optional patterns: variable-only and AVAL/PARAMCD | ✓ |
| Reliable within its supported scope | 12 audited defects fixed with regression tests; CI green | ✓ |
| Reproducible | Deterministic outputs; `scripts/demo.sh`; the video rebuilds from scripts | ✓ |
| Tested | 66 tests, 273 expectations, 0 skipped (local + CI); R CMD check OK | ✓ |
| Documented | README, ARCHITECTURE, COMPATIBILITY, VALIDATION, DEMO, this audit | ✓ (claims corrected in this pass) |
| Demonstrable | Live demo script; V1 video and AI-voiced video published; V2 built for review | ✓ |

### Level 2: credible research-programming tool

| Gap | Class |
|---|---|
| Methods/Comments rebuilt (formulas, types and styles there not preserved) | P1 |
| Never run on real public study programs (e.g. the CDISC pilot) or on a real Pinnacle 21 define.xlsx | P1 |
| SAS macro-heavy code (speculative lexer edges, `%include`) | P1 |
| Spec must be hand-maintained; it isn't read from the define.xlsx | P2 |
| No transcoding of WLATIN1 (it gets a clear diagnostic instead) | P2 |
| Partial-description status (D14), self-reference edge (D15), header message (D12) | P2 |
| No vignette or user guide; git-checkout install | P2 |

### Level 3: production CBAR integration

| Requirement | Class |
|---|---|
| Side-by-side comparison with the DEFX macro / `defxit` on real CBAR programs, and reconciling the differences | P1 for any adoption |
| Real Pinnacle 21 templates and schema mapping (ValueLevel, Codelists, Documents) | P1 |
| Decisions on KEEPTAGS semantics, error policy and ownership rules with the team | P1 |
| Review/sign-off workflow, change history, diff against the previous define | P1 |
| Validation package (plan, IQ/OQ, traceability matrix), SOP, controlled install | P1 (institutional) |
| Windows/SAS-server environments, encodings, performance at scale | P2 |
| Rewriting CBAR's SAS tooling | OUT OF SCOPE |

### Answers to the ten questions

1. **Meaningful problem or a simple comment parser?** A real but modest problem: one documentation convention across SAS and R during a migration. Most of the code is simple, as the ≈3/10 rating says. The value is in the conservative handling: lexing, provenance, refusing on errors, and verified writes. It isn't an algorithmic achievement.
2. **Architecture appropriate?** Yes for the scope: small pipeline stages with fixed data contracts. The verification layer was compensating for a whole-sheet rewrite. Now that writes are cell-level, it's proportionate.
3. **Core MVP functionality missing?** No.
4. **Significant untested edge cases?** There were 12 reproducible ones, and all now have regression tests. What remains untested is macro-heavy SAS, real workbooks, Windows and scale.
5. **Is workbook integrity guaranteed within the supported scope?**
   - *Within the checks, on each run*, yes. Every other sheet is compared cell by cell. Datasets/Variables are written cell by cell and verified, and targeted cells are verified against the tag values; a formula and a number survive in the tests.
   - In Methods/Comments, formulas, cell types and styles are not preserved.
   - It's verification, not a universal guarantee.
6. **Were the 52 tests / 236 checks meaningful?** Partly. They checked documented behaviour on the happy paths and many negative paths, but they missed 12 reproducible defects, and 3 of 6 mutations survived. The 66 tests / 273 checks are better, but still example-based.
7. **What prevents real adoption?** The Level 3 list above: no comparison with the macro, no real P21 schema, SAS macro code, no review workflow, no validation package, git-checkout installation.
8. **Any P0/P1 to fix before the interview?** Yes, and they were fixed: D3, D4, D5, D6 and D10 (P0); D1, D2, D7, D8, D9 and D11 (P1). Each was re-run and given a regression test, and the full suite and CI are green. No P0 remains open in the supported scope.
9. **More functionality?** No. Freeze the code now. New features before the interview add risk and no evidence.
10. **Most technically substantial part?** The SAS lexer's state machine, and the safe-write design: owned-cell writes, a temp file, a read-back with an independent library, targeted-value checks, then rename. Both are moderate (3–5/10), not hard.

### Verdict

**PORTFOLIO COMPLETE: YES**: functional, tested (66/273, CI green), documented, reproducible and demonstrable, with honest limits.

**RESEARCH PROTOTYPE COMPLETE: NO**: usable on controlled UTF-8 SAS/R projects, but it has never been run on a real study's programs or a real Pinnacle 21 define.xlsx. Formatting in Methods/Comments isn't preserved, and macro-heavy SAS is unproven.

**PRODUCTION READY: NO**: there's no comparison with the original DEFX workflow, no real schema support, no review workflow and no validation package.

**Recommendation: freeze the code for the interview.** Present it as a careful portfolio prototype with a documented path to research use.

## 11. Technical interview questions this audit raises

1. Your tests passed, yet an audit found 12 defects. What does that say about example-based testing, and what would you add? *(Mutation testing on the core branches, property tests for the lexer, and "the check actually fails" tests for every safety check.)*
2. Why did whole-sheet rewriting break formulas, and why did the verifier miss it? *(It compared cell text, and a formula's cached value equals its text. The fix was to stop rewriting cells we don't own.)*
3. How do you test the branch that refuses to write the workbook? *(Mock `verify_export` to FAIL and assert that no file and no temp file exist.)*
4. Two spellings of the same parameter are allowed. How do you make conflict detection see them as one? *(Normalize to a canonical key before grouping.)*
5. A Latin-1 SAS file crashed the whole run. Which is better: transcode, or refuse with a diagnostic? *(Refuse unless the encoding is declared. Guessing an encoding can silently corrupt text.)*
6. What would you need to compare DEFX Bridge with CBAR's macro on real data, and how would you reconcile differences?
7. Which of your design choices would you change if the team preferred the macro's skip-and-continue behaviour?
