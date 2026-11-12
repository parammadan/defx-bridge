# Compatibility with the published DEFX approach

Source: Bartley & Hinger, PharmaSUG 2026 AP-220, all 21 pages including Appendix A. The appendix itself notes that it was shortened: parameter checks and some `%local` statements were removed, and the CBAR helper macros `%maxlength`, `%nobs` and `%trimlen` are only described. The `defxit` script is mentioned but not published. Nothing below has been compared against the original macro's output on the same inputs.

Legend: **Implemented** = built and tested here · **Partial** = the idea is covered but behaves differently · **Not implemented** · **Needs the original environment** = cannot be confirmed without the original code, data or tools.

## A. Features described in the paper

| Paper feature | DEFX Bridge | Notes |
|---|---|---|
| `/* DEFX \| DS.VAR \| desc */` computation (type defaults to Computation) | Implemented | SAS and R |
| Multi-line descriptions concatenated in order (paper groups by Program/Name/Type) | Implemented | Grouped the same way, joined with a single space. The macro uses `catx('',...)`. Whether its exact spacing matches ours is not verified |
| Imputation, Predecessor, Assigned tags | Implemented | Assigned is recognised when the text is `Assigned` (case-insensitive), as in the macro's `propcase` test |
| Comments for a variable / for a dataset | Implemented | Comment ID = tag name, as in the macro (`Comment = Name`) |
| Method that applies to a variable in all datasets (`DEFX \| VAR \| desc`) | Implemented | The macro resolves dataset-vs-variable from the Datasets tab. DEFX Bridge uses the spec's datasets |
| `AVAL.<DS>.PARAMCD.EQ.<VALUE>`: Methods only, Variables untouched | Implemented | Also accepts the `<DS>.<VAR>.<VALUE>` form shown in the paper's examples (`ADILB.AVAL.ALT`, `ADQOL.AVAL.TOTSC`). Other names with more than one `.` are rejected (V001) where the macro would accept them |
| Check: a DS.VAR is created in only one program | Implemented (V003) | The macro flags duplicates by Type+Name after Predecessor/Assigned types are blanked. DEFX Bridge groups all origin types together and Comments separately |
| Check: DS.VAR / VAR must exist in the Variables tab | Implemented (V002 vs spec, V009 vs template) | The paper validates against the define.xlsx Variables tab. DEFX Bridge uses an explicit spec CSV plus a template check |
| Check: comma in a tag name | Implemented (V001) | |
| Error when a directory has no SAS files / no tags found | Implemented | No programs → exit 1. No tags → V014 warning (the macro stops with an error) |
| Flagged tags are not written; others are | **Different** | DEFX Bridge writes **no** workbook if any error exists. This is a deliberate conservative choice for the prototype |
| `METALIB` metadata dataset for traceability | Partial | `<out>_meta.csv` with file, all line numbers and raw tag text. Not a SAS dataset |
| `DEFXLSX` input / `OUTXLSX` output (default: overwrite input) | Partial | `--template` / `--out`. DEFX Bridge **never** overwrites the template, and `--out` is required |
| `TAGLOC`: one or more directories, `*.sas` in each | Partial | Repeatable `--source`, `.sas`/`.R`/`.r`. Recursive by default (`--no-recursive` matches the paper's one-level search) |
| `KEEPTAGS=N` (default) / `Y` | Partial | `--keep-unmatched` keeps unmatched Methods/Comments rows, as in the paper's Table 2. The paper's prose says Y "favors the information already in the define.xlsx". In DEFX Bridge, tag text always wins for matched rows. Which reading production uses **needs the original environment** |
| Spreadsheet column order preserved | Implemented | Columns are written in template order. Variables/Datasets row order is preserved. Methods/Comments are sorted by ID (the macro sorts by Name) |
| Variables tab merge | **Different** | The macro's merge sets Origin/Method/Predecessor/Comment from the tag rows for matched variables, which can blank a hand-entered Comment. DEFX Bridge changes only the fields a tag owns: an origin tag sets Origin/Method/Predecessor, and a Comments tag sets Comment |
| Tag discovery with `grep -i 'DEFX'` + `\|` on every line | **Different (stricter)** | DEFX Bridge is lexical. It ignores DEFX text in strings and DATALINES, and requires the comment to *start* with DEFX. It rejects tags inside multi-line `/* */` comments (V001) and ignores `* ... ;` statement comments (V012). A program the macro accepts can therefore produce diagnostics here |
| Unknown third field treated as a Type | **Different** | DEFX Bridge rejects unknown types (V004) instead of passing them through |
| Field lengths (`Name $40`, `Description $1000`, `Predecessor $20` in the appendix) | Not replicated | No length limits here. The original's behaviour at those limits was not examined |
| `defxit` command-line script (Scott Anderson) | Not implemented | `bin/defxbridge` is an independent CLI. defxit's interface and behaviour are not published |
| `p21zip`, `/p21` directory conventions | Not implemented | Out of scope |
| CBAR helper macros `%maxlength`, `%nobs`, `%trimlen` | Not needed | R data frames have no fixed lengths |

## B. Added independently in DEFX Bridge

- The same tag syntax in **R** comments (`#`, `#'`), read with R's own tokenizer
- Lexical SAS comment extraction (strings, DATALINES, statement comments)
- Per-line provenance for consolidated records (`source_lines`, `raw_tag`, `segment_count`)
- Explicit spec CSV, separate from the workbook. SDTM-like datasets in the spec put explicit predecessors in scope (V005), and out-of-scope predecessors get V011
- Diagnostics with codes, severity, location, related locations and suggested fixes. Machine-readable CSV and a Markdown report
- V006 (conflicting origins in one program; variable-only vs dataset-specific overlap), V013 (dangling references)
- Atomic export with read-back preservation checks; content-level `compare`; exit codes 0/2/1

## C. Partially implemented

- SAS lexing: only the comment forms above. No macro-quoting, `%include` or macro-generated comments
- Parameter-level methods: Methods sheet only. There is no value-level metadata (ValueLevel/WhereClauses sheets)

## D. Not supported

- `.Rmd`/`.qmd`, SAS Enterprise Guide projects, `.sas7bdat` inputs
- A description containing `|` (reported as V001/V004, never guessed)
- define.xml generation, CDISC conformance checking, Pinnacle 21 rules

## E. Needs the original environment to verify

- Equivalence of outputs with the DEFX macro / `defxit` on the same programs
- Behaviour against a real Pinnacle 21-generated define.xlsx (sheet and column names, extra sheets, styles)
- The production KEEPTAGS semantics and any checks removed from the published appendix
- Real-world SAS coding patterns in production programs (macro-heavy code, unusual comment styles)
