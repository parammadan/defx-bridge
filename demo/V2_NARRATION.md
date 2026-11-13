# DEFX Bridge demo V2: narration

The published narration in `DEFX_Bridge_Demo_V2.mp4` is an **AI voice** (Kokoro TTS `am_onyx`, local and free; not a clone of the author's voice). Below is the exact script, with the spoken spellings normalized (`D E F X` → DEFX). Read it aloud yourself to record a human version: the timings match the scenes, and each scene is about its narration length plus 1.4 s.

Every clip was transcribed back with Whisper (`small.en`), and the full MP4 transcript was checked for timing. Every line starts inside its own scene.

**[0:00] The problem**
In clinical programming, every derivation is explained twice: once in the code, and again, by hand, in the define.xml metadata. What if the comment beside the code could be the metadata?

**[0:13] One convention, two languages**
That's the DEFX approach, published by Brendan Bartley and Megan Hinger. DEFX Bridge is my independent R prototype. It reads the same tags from SAS and from R, and normalizes both into one metadata table.

**[0:28] Real extraction**
Here is a real scan of three synthetic programs. Forty-eight tag lines become forty records. Nothing is executed; the R language's own parser reads the R files. Each record keeps its dataset, variable and type, and the exact file and lines it came from.

**[0:44] Validation catches a real problem**
Now a real mistake. This tag points at a variable that isn't in the specification. Validation catches it, names the file and the line, and exits with code two, so nothing downstream can quietly continue.

**[0:58] The fix: one line**
I correct the reference in a copy of the file. The difference is one line. The same command now passes, with zero errors and exit code zero.

**[1:08] The generated workbook**
Export fills a copy of a define-like workbook. The three tag lines become one method description. The stale origin on that variable becomes Derived, with a method reference that resolves. Hand-entered cells, including the expression code, stay exactly as they were.

**[1:24] Verified, not assumed**
Before the file is kept, it is read back with a different library and compared with the template, cell by cell: eighteen checks, all passing. Sixty-six automated tests pass locally and on GitHub's CI, where nothing is allowed to skip.

**[1:39] Closing**
DEFX Bridge. One documentation convention across SAS and R, so a study can adopt R gradually, one program at a time. An independent research prototype, built with credit to the original DEFX authors.

**Spelling choices for the AI voice:**
- `D E F X`: otherwise it is read as 'deffix'.
- 'define dot X M L': 'define workbook' was heard as 'defined workbook'.
- 'the R language's own parser': 'R's own tokenizer' was heard as 'ours own'.
- 'adopt R gradually, one program at a time': 'adopt R one program' was heard as 'R1 program'.
