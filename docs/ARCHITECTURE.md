# Architecture

```
 --source dirs/files
        │
        ▼
 discover_sources()      R/discovery.R   .sas / .R / .r, recursive, hidden dirs skipped,
        │                                sorted by relative path (C-locale radix) → deterministic
        ▼
 extract_tags_file()     R/parser.R      per file:
        │   SAS → lex_sas_comments()     character lexer, no evaluation
        │   R   → lex_r_comments()       parse() + getParseData(): R's own tokenizer, no evaluation
        │   → parse_defx_comments() → parse_defx_tag()   one SEGMENT per tag line
        ▼
 normalize_defx_metadata()  R/normalize.R  segments → RECORDS (consolidation + scope)
        ▼
 validate_defx_metadata()   R/validate.R   records + spec → diagnostics; apply_status()
        ▼
 export_defx_workbook()     R/workbook.R   records + template → temp .xlsx → verify_export() → rename
        ▼
 reports / CSV              R/reports.R    console tables, Markdown report, deterministic CSV
```

`run_pipeline()` wires discovery → extraction → normalization → validation. `R/cli.R` is a thin argument parser over those functions. It maps outcomes to exit codes (0 / 2 / 1) and catches every condition, so normal input errors print one `defxbridge: error: ...` line instead of a stack trace.

## Source discovery

Directories are listed recursively (`--no-recursive` for one level) and single files are accepted. Each file gets a provenance label: its path relative to the `--source` root, or `<root basename>/<path>` when several roots are given. Duplicate root basenames are rejected so labels stay unambiguous. Missing paths, and roots without any `.sas`/`.R`/`.r` file, are input errors (exit 1).

## Parsing

### R

`parse(text = lines, srcfile = srcfilecopy(...), keep.source = TRUE)` followed by `getParseData()` gives every `COMMENT` token with its line and column. That is R's own lexer, so strings (including raw strings `r"(...)"` and escaped quotes) are never confused with comments, and nothing is evaluated. If the file has a syntax error, the parser fails. The file then produces **no tags** and a V008 error with the parser's line number. This tool never falls back to a regex guess.

### SAS

`lex_sas_comments()` walks the characters once and tracks:

- `/* ... */` block comments (start/end line, column, exact raw text)
- quoted strings `'...'` and `"..."` with doubled-quote escapes, which are skipped
- statement comments `* ... ;` and `%* ... ;` when the `*` begins a statement (after `;`, start of file, whitespace or comments)
- `DATALINES;` / `CARDS;` / `LINES;` / `PARMCARDS;` blocks (skipped to the next `;`), plus the `...4;` variants (skipped to `;;;;`). The statement is recognised even when a comment precedes it, and a block that is never closed is a V008

An unterminated comment, string or statement comment stops lexing for that file with a V008 error. Tags before that point are kept. The lexer does **not** interpret macro quoting functions, macro-generated code, or `%include`.

### Tag grammar

A comment is a candidate only if its text (after the `#`/`#'` prefix or inside `/* */`) **starts with** `DEFX` followed by whitespace, `|`, or end of text. `DEFXIT ...` or `see DEFX | ...` are therefore ordinary comments. A candidate without any `|` gets a V010 warning. Otherwise it is split on `|`, keeping empty fields:

```
DEFX | <name> | <description>                → Computation (default), or Assigned if the text is "Assigned"
DEFX | <name> | <Type> | <description>       → Type ∈ Computation, Imputation, Predecessor, Comments
```

`<name>` forms are `<DS>`, `<VAR>`, `<DS>.<VAR>`, `<DS>.<VAR>.<VALUE>`, and `AVAL.<DS>.PARAMCD.EQ.<VALUE>`. Anything else, including more than three fields, an empty field or a comma, is a V001/V004/V005 diagnostic. **A malformed tag never becomes a computation description.**

## Normalization

A **segment** is one tag line. A **record** is one definition: all `ok` segments sharing `(source_file, name, type)` are merged. That is the published multi-line pattern. In the merge:

- `description` = the segments' trimmed descriptions joined by one space, in source order (line, then column)
- `source_line` = first line; `source_lines` = every contributing line (`27;28;29`); `segment_count`
- `raw_tag` = every contributing comment exactly as written, newline-separated
- `origin` = Derived (Computation/Imputation), Predecessor, Assigned, or empty (Comments)
- `predecessor` = the joined text for Predecessor records, so a two-line predecessor becomes `AE.X AE.Y` and fails V005 rather than silently picking one

Malformed segments become one-segment records with `status = error` so they stay visible in the scan output. Single-name tags are resolved with the specification: a name that is a spec dataset gets `scope = dataset`, otherwise `variable_all`. Without a specification the scope is `dataset_or_variable`, which is reported, never guessed. The remaining scopes are `dataset_variable` and `parameter`.

Record order is first appearance (file order, then line). `record_id` (`R0001`...) is assigned after sorting, so identical inputs produce identical record tables and byte-identical CSVs.

## Validation

See [VALIDATION.md](VALIDATION.md). The ownership rule (V003) groups records by `(name, kind)`, where kind is *origin* (Computation, Imputation, Predecessor, Assigned) or *comment*. A group spanning more than one `source_file` is a conflict. Because consolidation happens first, repeated lines in one file can never trigger it.

## Export

1. `load_template()` requires the sheets Datasets, Variables, Methods and Comments, each with its required columns. A bad template is an input error.
2. `build_workbook_data()`:
   - updates **only** the tag-owned columns of targeted rows: Datasets.Comment, and Variables Origin / Predecessor / Method / Comment
   - rebuilds Methods and Comments from the tags, keeping each matched row's other columns (Expression Context, Document, ...)
   - drops unmatched rows unless `--keep-unmatched`
   - sorts Methods and Comments by ID
   - flags V009 (target not in the template) and V013 (dangling references)
3. Writing: openxlsx `loadWorkbook()`. In Datasets/Variables, **only the owned cells of targeted rows** are cleared and written, cell by cell, so formulas, numbers and dates elsewhere are never rewritten. Methods/Comments are rebuilt (`deleteData()` + `writeData()`), so formulas, types and styles in those sheets are not preserved. Then `saveWorkbook()` to a temp file in the destination directory. Refused up front: `--out` that is a directory, an export with zero records, and output paths equal to an input.
4. `verify_export()` re-reads template and temp file with readxl, an independent reader (openxlsx is the fallback), as text. It checks:
   - sheet names and order
   - other sheets cell-for-cell
   - non-DEFX columns and untargeted rows of Datasets/Variables
   - headers of Methods/Comments, and matched rows' non-DEFX columns
   - **that every targeted cell holds the value its tag dictates** (Datasets/Variables owned columns; Methods/Comments rows equal the tag-built sheet)
   - the sentinel count, only where content must survive (rows legitimately dropped under KEEPTAGS=N don't count)
5. Only if every check passes: `file.rename()` into place, then the `_meta.csv` and report.

Errors at any stage leave no new workbook. A pre-existing file at `--out` is not deleted, and the CLI says it was not updated.

Repeatability is checked on **content** (`workbook_content()` / `compare`), not on file hashes, because .xlsx zip metadata differs between runs.
