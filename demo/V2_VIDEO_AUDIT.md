# DEFX Bridge video audit: V1 vs V2

**Inputs inspected:**

- V1: `demo/DEFX_Bridge_Demo.mp4` (120.03 s, captioned, silent) and the voiced copy with the same picture. I looked at frames from all 10 scenes.
- The TrialProof Studio reference: `~/Desktop/videos/trialproof-studio/TrialProof_Studio_Live_Demo.mp4` (150.7 s, 1080p, narrated), plus its `storyboard.md` and the `script.json` it was built from. I looked at 12 frames across its length.
- V2: `demo/DEFX_Bridge_Demo_V2.mp4`, two frames per scene from the final file, plus the full Whisper transcript.

## 1. V1, rated honestly (1–10)

| Area | V1 | Why |
|---|---|---|
| Visual design | 4 | One look throughout: a flat full-width terminal plus a caption bar. No hierarchy. |
| Storytelling | 3 | A sequence of commands. There's no problem, tension or resolution, and the failure is just another command. |
| Opening hook | 3 | A static title card with a disclaimer-heavy subtitle. It never says why anyone should care. |
| Pacing | 5 | Even, but every scene has the same weight, including the dull ones. |
| Readability | 5 | 22 px terminal text across 1920 px, a 40-row table, a 14-row check table. The viewer has to hunt. |
| Composition | 4 | Text fills the top half and leaves dead space below. No focal point. |
| Terminal presentation | 5 | Real and honest, but unframed and un-highlighted. |
| Workbook visualization | 3 | Printed cell text in a terminal. It never looks like a workbook, and before/after is hard to see. |
| Transitions | 4 | Fades only. |
| Captions | 6 | Clear, burned in, and accurate. |
| Technical credibility | 8 | Everything is real, labelled and not sped up, with a real-time gate. |
| Understandable without the README | 4 | You see that commands ran. You don't see *why it matters* or what changed in the workbook. |
| **Overall** | **4.5** | Credible but not persuasive: a slideshow of terminal output. |

**Why V1 felt weak:** it proved things without showing them. The decisive facts (three lines become one method, Assigned becomes Derived, the unknown variable gets caught) were all on screen, but buried in uniform text with nothing directing the eye.

## 2. What the TrialProof video does well (observed)

- **The hook is a question with stakes:** "What if an AI could write the statistical program… and have every number checked by an engine it cannot influence?"
- **It shows the real product,** a GUI, and **zooms in on the decisive numbers**: huge "75.6% / 90.5% / 91.7%" cards, and "417 / 0 / 0" verification counts.
- **It has an end-to-end arc with a real injected failure:** "I change one line… the checker flags all 417 cells", then the fix, then verification, then human sign-off.
- **It labels its edits honestly:** "1.5× speed", "condensed 18×", "same run, new numbers".
- **Strong title and closing cards** use one visual language, with motion as emphasis rather than decoration.
- **The value is clear within about 20 s.**

## 3. V2 design decisions

- **The problem comes first** (s01): "Every derivation is explained twice." It shows real SAS code next to a re-typed Methods cell, clearly labelled as an illustration, then flips to "the comment is the metadata".
- **Two languages, made visual** (s02): real SAS and R tag lines side by side, coloured by tag part, feeding one table with real records.
- **A readable extraction** (s03): the real scan provides the counts, then a large table of 6 real records with provenance highlighted. The tiny 40-row terminal table is gone.
- **The failure as a moment** (s04): highlighted real output, then a zoom card with a wavy underline under the bad name and exit code 2.
- **A real fix** (s05): a one-line `sed` into a copy, a real `diff`, then the same command passes. This adds the before/after story V1 lacked.
- **A spreadsheet-style workbook preview** (s06), built from the actual .xlsx and labelled as not Excel. Cells change colour with the narration: Assigned → Derived, the joined description, the kept hand-entered cells.
- **Evidence, not walls of text** (s07): the real export and test run, three evidence chips, and a real CI screenshot.
- The same Remotion visual language as TrialProof, and the same AI narrator.

## 4. V2, rated honestly (1–10)

| Area | V1 | V2 | What changed / what is still weak |
|---|---|---|---|
| Visual design | 4 | 7 | Framed terminals, cards, a spreadsheet preview, a consistent palette. *Weak:* the s06 badge row at the bottom is busy. |
| Storytelling | 3 | 7 | Problem → convention → extraction → failure → fix → workbook → verification. *Weak:* the stakes are smaller than TrialProof's, because a CLI tool has less drama than an AI writing code. |
| Opening hook | 3 | 7 | A one-sentence problem with real code. *Weak:* the right-hand panel is an illustration, though labelled as one. |
| Pacing | 5 | 7 | Scenes are sized to the narration. s05 is quick (9.7 s, played at 1.2×). |
| Readability | 5 | 7 | 26–40 px key text, highlights and zoom cards. *Weak:* the shrunken terminal in s03 and the CI screenshot text are small (context only). |
| Composition | 4 | 7 | Each scene has one focal point. |
| Terminal presentation | 5 | 8 | Window frames, real-recording labels, highlights placed on real output lines (positions measured from frames). |
| Workbook visualization | 3 | 7 | Spreadsheet look, before/after colour changes, provenance arrow. *Weak:* it's a preview, not Excel (labelled). |
| Transitions | 4 | 6 | Fades plus purposeful motion: the terminal shrinks, cards slide, cells change colour. Still simple. |
| Captions | 6 | 6 | A sidecar `V2_CAPTIONS.srt` (24 sentence cues). *Weak:* not burned in, like the TrialProof video. |
| Technical credibility | 8 | 8 | Everything is from real runs and files. The two time edits (1.2× in s05, the cut test run in s07) are labelled. |
| Understandable without the README | 4 | 7 | The narration plus visuals explain the why, and the workbook change is legible. |
| **Overall** | **4.5** | **7** | **Materially better**, though not at TrialProof's level. See below. |

**Why it's still below TrialProof:**

- TrialProof shows a graphical product doing something surprising. DEFX Bridge is a CLI, so V2 leans on motion graphics around terminal output.
- V2 has one real failure and fix, but no independent second check computing numbers the way TrialProof's verifier does.
- The narrator is an AI voice. A human recording of `V2_NARRATION.md` would improve warmth.

## 5. Accuracy checks on V2

- Every number on screen comes from the capture's files: 48 → 40 records, SAS 15 / R 25 / 5 multi-line, V002 at `unknown_variable.R:2`, exit 2 → 0, 18/18 checks, 15 resolvable Method references, `PASS 273`.
- "66 tests" is not printed by the test reporter. It comes from the same suite's verified run (`as.data.frame(test_local())`: 66 tests) and from CI run 43340253913.
- The CI claim was verified on GitHub before narration: run 43340253913 on `9bdd0c9` is green for both jobs. The screenshot also shows the earlier red run (a codoc warning, fixed); that's real history.
- **Real-time gate on the footage:** t_scan 0.96, t_invalid 0.98, t_fix 1.08, t_export 1.03, t_tests 0.98.
- **QC findings, and their fixes before the final cut:**
  - command echoes interleaved, because commands were typed before the previous one finished (pauses added)
  - wrapped commands (terminal widened)
  - highlight boxes a character short (metrics measured from a real frame)
  - the s03 terminal covered the heading
  - the s06 description was truncated (now wraps)
  - the s07 CI box was on the header row (moved to the newest run)
  - loudness was −24.5 LUFS (normalized to −16.4, with the video stream unchanged)

## 6. Recommendation

**V2 is suitable for the interview and the portfolio**, and better than V1 on every presentation dimension, with equal credibility.

- Before publishing, consider recording your own voice over `V2_NARRATION.md` (the recipe is in `recording_instructions.md`).
- If you want accessibility on YouTube, upload `V2_CAPTIONS.srt` as the subtitle track.
- Keep V1, and the voiced V1 on YouTube, as the fallback until you've watched V2 end to end.
