# Storyboard

The measured timings are in [video_manifest.md](video_manifest.md). The caption text for each scene is in [captions.srt](captions.srt). Both are generated from the `SCENES` list in [build_video.py](build_video.py), which is the single source of truth.

| # | Time | Scene | On screen | Point the viewer should take away |
|---|---|---|---|---|
| s01 | 0:00–0:07 | Introduction | Title card: **DEFX Bridge**, the subtitle, two real tag lines (one SAS, one R), credit to Bartley & Hinger (PharmaSUG 2026, AP-220), and the non-affiliation note | What this is, and whose idea it builds on |
| s02 | 0:07–0:17 | SAS source | `makeadae.sas` lines 19–37: Predecessor tags, the three-line ADAE.AERELFL method next to its SAS code, a Comments tag, the AESAECAT tags | Documentation lives next to the code. Three lines make one method |
| s03 | 0:17–0:30 | R source | `makeadsl.R` lines 9–22 (the same syntax as `#` comments), then lines 47–49 (a DEFX-like string literal) | It works in R too, and code isn't mistaken for comments |
| s04 | 0:30–0:43 | Extraction | `scan`: 3 programs (SAS 1, R 2), 48 tag lines → 40 records. The table shows file:line, language, name, type, origin and text, e.g. `makeadae.sas:27;28;29` | One normalized table that records where every entry came from |
| s05 | 0:43–0:50 | Validation | `validate` on the valid set: `Validation PASSED: 0 error(s), 0 warning(s), 0 info` | Every target is checked against an explicit spec |
| s06 | 0:50–1:04 | Invalid input | `cat` of the invalid file, then `[ERROR V002] unknown_variable.R:2 ADAE.DOESNOTEXIST is not in the specification`, `exit code: 2` | Errors are reported with their location, never accepted silently |
| s07 | 1:04–1:15 | Workbook export | `export`: 14 preservation checks, all PASS; Methods 18, Comments 5, Variables updated 34, Datasets updated 3 | It writes a copy and verifies it, and keeps it only if everything else is unchanged |
| s08 | 1:15–1:32 | Workbook contents | Methods sheet read back from the `.xlsx` (AERELFL lines joined; `Expression Code` = `DO_NOT_CHANGE` kept); the PreserveMe sheet unchanged | The real file contains the generated documentation |
| s09 | 1:32–1:50 | Before/after | Template `ADAE.AERELFL` Origin `Assigned` → output `Derived` with its Method; untagged AESEQ keeps its hand-entered note | Intended cells change; unrelated content doesn't |
| s10 | 1:50–2:00 | Closing | The SAS→R adoption message, the closing line, `github.com/parammadan/defx-bridge`, full credits and disclaimers | Why it matters, where to find it, and who to credit |

Visual style: Catppuccin Mocha dark terminal, Menlo 22 px. Plain system-font cards and a two-line caption bar with a "LIVE TERMINAL RECORDING · real commands · real output · not sped up" label. Only fades; no other effects.
