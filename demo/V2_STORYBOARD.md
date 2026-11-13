# DEFX Bridge demo V2: storyboard (as built)

**File:** `demo/DEFX_Bridge_Demo_V2.mp4`. 114.82 s, 1920×1080, 30 fps, H.264 + AAC (−16.4 LUFS), 9,436,485 bytes, SHA-256 `e423c86ff74caaa5eb2e3e22005e9f2889a243616a6aa852038526749f665c20`. **Not published.**

**How it was made:**

- **Real footage, real data.** `demo/v2/capture.py` deletes `artifacts/`, then records each terminal step as a real VHS bash session, with a real-time gate: every clip measured 0.96–1.08 of real time. It then extracts every table, cell and number shown from the files those same runs wrote: `scan.csv`, the diagnostics CSV, the exported `.xlsx` read with readxl, and the export report. It also screenshots the public GitHub Actions page.
- **Motion graphics around the real results.** `demo/v2/DefxWalk.tsx` (Remotion, the same style as the TrialProof walkthrough) frames those results.
- **Narration:** Kokoro `am_onyx` (an AI voice, not the author's), with every clip read back by Whisper.
- **Assembly:** `assemble.py` from the walkthrough kit (each scene is voice + 1.4 s), then audio-only loudness normalization (the video stream MD5 is unchanged).

| # | Time | Scene | Picture | Real evidence on screen |
|---|---|---|---|---|
| s01 | 0:00–0:13 | **The problem** | The headline "Every derivation is explained twice."; real `makeadae.sas` lines 27–32; a Methods cell labelled "(illustration)" being re-typed, which then turns green, "filled from the comments beside the code"; "What if the comment were the metadata?" | Real source lines. The right-hand panel is explicitly labelled as an illustration. |
| s02 | 0:13–0:28 | **One convention, two languages** | Credit line (Bartley & Hinger, PharmaSUG 2026, AP-220); real SAS lines 27–29 and R lines 20–22 side by side with the tag parts coloured; both feed one table | The two records come from `artifacts/scan.csv`: `makeadae.sas:27;28;29` and `makeadsl.R:20;21;22` |
| s03 | 0:28–0:45 | **Real extraction** | A real `scan` run in a terminal window ("REAL TERMINAL RECORDING · not sped up"), with the counts highlighted; then the terminal shrinks and 6 real records appear in a large table, with the SOURCE FILE : LINES column glowing | "48 tag lines → 40 records (SAS 15, R 25, 5 multi-line)", from the run itself and from `scan.csv` |
| s04 | 0:45–0:58 | **Validation catches a real problem** | A real `validate` run on `examples/invalid/unknown_variable.R`, with red highlights on the source line, the V002 line and `exit code: 2`; then a zoom card with a wavy underline under DOESNOTEXIST, the diagnostic and its fix, and "exit code 2" | The diagnostic text comes from an identical off-camera run's CSV (same command plus `--out`) |
| s05 | 0:58–1:08 | **The fix: one line** | A real `sed` correction into `artifacts/fixed.R`, a real `diff` (red/green), then the same `validate` command: PASSED, `exit code: 0` | Played at **1.2× speed** (labelled). The original fixture is unchanged (labelled). |
| s06 | 1:08–1:25 | **The generated workbook** | A spreadsheet-style **preview** with Methods and Variables tabs. The source lines link to the joined Description. AERELFL Origin flips from red "Assigned" (template) to green "Derived", and its Method and Comment light up. The hand-entered Expression Code and Developer Notes cells are outlined amber, "kept". | Every cell comes from `define_like_filled.xlsx` and the template, read with readxl. Labelled "preview rendered from … · not Microsoft Excel". "All 15 Method references resolve" is computed from the file. |
| s07 | 1:25–1:39 | **Verified, not assumed** | A real `export` run (sentinel PASS, Export OK highlighted). Then a real test run: typing, a labelled cut, then `[ FAIL 0 \| WARN 0 \| SKIP 0 \| PASS 273 ]`. Then a real screenshot of the public Actions page, with the newest green run outlined. Chips: "18 / 18 checks pass", "66 tests · 273 checks", "CI passing on GitHub". | 18/18 parsed from `define_like_filled_report.md`. The test result comes from the recording (~25 s of progress cut, labelled). The CI screenshot also shows an earlier red run; it's the real history. |
| s08 | 1:39–1:55 | **Closing** | "DEFX Bridge / Structured metadata across SAS and R / independent research prototype · synthetic data · read, never executed / Designed and developed by Param Madan", the repo and project-page URLs, full credits and a disclaimer | n/a |

**Edits:** fades between scenes; s05 at 1.2×; the s07 test run cut, both labelled on screen. Nothing else is accelerated, and no output is simulated.

## V2.1 (author intro + clearer credits): `demo/DEFX_Bridge_Demo_V2.1.mp4`

120.39 s, 1920×1080, H.264 + AAC (−16.6 LUFS), 9,774,633 bytes, SHA-256 `93713a7b6a49cce7d76d8ef595c17775ed732eab88f5648aef0993dce73ebdf5`. Captions: `V2.1_CAPTIONS.srt` (25 cues). **Not published.**

Only two scenes changed, and V2 stays untouched:

- **s00 (new, 0:00–0:05.5), on-screen text only, no voice:** "Hi, I'm Param Madan." / "I built DEFX Bridge, an independent R-based prototype inspired by the DEFX work presented at PharmaSUG 2026." / github.com/parammadan/defx-bridge
- **s08 closing credits (from 1:48.7),** headed "ORIGINAL DEFX WORK":
  - "Megan Hinger · creator of the original DEFX SAS macro and paper coauthor"
  - "Brendan Bartley · PharmaSUG 2026 paper coauthor (AP-220)"
  - "Scott Anderson · creator of the defxit Linux command-line utility"
  - then "Original program testing: Shawn Ward…" and the disclaimer

Scenes s01–s07 use the same rendered clips and audio as V2. Frames compared at six points (V2 *t* vs V2.1 *t* + 5.5 s) have SSIM 1.000.
