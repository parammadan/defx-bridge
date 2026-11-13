# Narration script

The published video is **AI-narrated** (Kokoro TTS voice `am_onyx`, not a clone of your voice). The spoken script is in `demo/voice_script.json`, each line fitted to its scene's measured length. This file is the longer, human-readable script, kept for reading the demo yourself, live or in your own recording. It's about 260 words, roughly 2 minutes at a relaxed pace, and the bracketed times match the video.

**[0:00] Intro**
This is DEFX Bridge. It's an independent R prototype built on the DEFX approach that Brendan Bartley and Megan Hinger published at PharmaSUG this year: the comments you write to document a derivation also fill in the define.xml.

**[0:07] SAS source**
Here's a SAS program. Each DEFX comment sits right next to the code it describes. These three lines for ADAE.AERELFL are one method written across three lines, not three duplicate definitions.

**[0:17] R source**
And here's an R program with exactly the same syntax, as R comments. Line 49 is a trap: a string that looks like a tag. It's code, not a comment, so the tool must ignore it.

**[0:30] Scan**
Scan reads both languages without running either one. Forty-eight tag lines become forty records, and every record keeps its file and line numbers. That's the traceability a reviewer needs.

**[0:43] Validate**
Validation checks every target against an explicit specification. The valid examples pass with zero errors.

**[0:50] Invalid input**
Now a tag naming a variable that isn't in the spec. It's reported with its file and line, and the command exits with code 2. Errors are surfaced, never silently written into the workbook.

**[1:04] Export**
Export fills a copy of a define-like workbook. It reads the copy back and checks that everything it isn't supposed to touch is unchanged: other sheets, other columns, rows without tags, and a sentinel value. All fourteen checks pass.

**[1:15] Workbook**
This is the generated file. The three AERELFL lines are now one method description, and a hand-entered cell next to it is still there. The PreserveMe sheet is untouched.

**[1:32] Before and after**
In the template, AERELFL had a stale origin of Assigned. Now it's Derived, with its method. Rows without tags keep their hand-entered values.

**[1:50] Close**
One shared tag convention means a study can move derivations from SAS to R one program at a time, and the same validated metadata keeps flowing into the define workbook. The code is on GitHub. All data is synthetic, and the project isn't affiliated with CBAR or PharmaSUG.
