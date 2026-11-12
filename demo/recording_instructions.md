# Recording instructions

## Rebuild the video (automated)

```bash
brew install vhs ffmpeg          # vhs also needs ttyd (installed with it) and Google Chrome
Rscript -e 'install.packages(c("openxlsx", "readxl"))'
python3 demo/build_video.py      # about 4-5 minutes; run from the repository root
```

The build:

1. deletes `artifacts/`, so nothing on screen is stale
2. writes `demo/tapes/s02–s09.tape` and records each one with VHS (a real bash session)
3. aborts if any recording isn't real-time, i.e. its recorded ÷ expected length is outside 0.90–1.35
4. renders the cards and the caption bar with headless Chrome
5. composites, fades and concatenates the scenes into `demo/DEFX_Bridge_Demo.mp4`, and writes `demo/captions.srt` and `demo/work/timeline.json`

Afterwards, update the values in `video_manifest.md` from:

```bash
ffprobe -v error -show_entries format=duration,size -of default=nw=1 demo/DEFX_Bridge_Demo.mp4
shasum -a 256 demo/DEFX_Bridge_Demo.mp4
cat demo/work/timeline.json
```

**Quality checks before publishing:**

- Grab one frame near the end of each scene (`ffmpeg -ss <t> -i demo/DEFX_Bridge_Demo.mp4 -frames:v 1 f.png`) and read every one. Look for wrapped commands, overlapping output (if a command was typed before the previous one finished, lengthen its pause), and any path or name that shouldn't be shown.
- Run `ffmpeg -v error -i demo/DEFX_Bridge_Demo.mp4 -f null -`. It should print nothing.

If the machine is busy (other apps, swap), VHS can't keep up and the real-time gate will stop the build. Close heavy apps and run it again. Don't loosen the gate.

`demo/work/` holds intermediate clips (a few MB) and can be deleted after the final video is verified. It is git-ignored.

## Optional: record a voiced version

The shipped video is captioned with no voice. To add your own voice:

1. Play `demo/DEFX_Bridge_Demo.mp4` and read `narration.md` along with it, recording with QuickTime (File → New Audio Recording) to `voice.m4a`.
2. Mux the audio in without re-encoding the video:
   ```bash
   ffmpeg -i demo/DEFX_Bridge_Demo.mp4 -i voice.m4a -map 0:v -map 1:a -c:v copy -c:a aac -b:a 160k -shortest demo/DEFX_Bridge_Demo_voiced.mp4
   ```
3. Watch the result once to check the sync before sharing it.

Don't use a synthetic voice that imitates yours.

## Optional: a real screen recording of the workbook in Excel or Numbers

There was no spreadsheet application on the build machine, so the video shows the workbook's cells read back with readxl. On a machine that has one:

1. Run `./bin/defxbridge export ... --out artifacts/define_like_filled.xlsx` (the command is in `docs/DEMO.md`).
2. Turn on Do Not Disturb, close other windows, and open `artifacts/define_like_filled.xlsx`.
3. Record with QuickTime (File → New Screen Recording, "Record Selected Portion") while you open the Methods, Variables and PreserveMe sheets.
4. Keep the clip unedited, and label it in the video as a screen recording.

## YouTube-ready text (not published)

No YouTube upload has been made. If you choose to upload:

- **Title:** DEFX Bridge — SAS & R Metadata Automation | Live Demo
- **Description:**
  > DEFX Bridge is an independent R prototype that extracts structured DEFX documentation comments from SAS and R programs, validates them against a specification, and fills a define-like Excel workbook, keeping file:line provenance for every definition. Every terminal scene is a real recorded shell session (real commands, real output, not sped up); all data is synthetic.
  >
  > Code: https://github.com/parammadan/defx-bridge
  >
  > Inspired by: Brendan Bartley & Megan Hinger, "Do One Task, Get Another Done for Free: Use DEFX Tags in Comments to Fill Out Your define.xml", PharmaSUG 2026, Paper AP-220. The original DEFX SAS macro is by Megan Hinger and the defxit script by Scott Anderson; Shawn Ward tested the original program. DEFX Bridge is a separate implementation and is not affiliated with or endorsed by CBAR or PharmaSUG. Not a validated or regulatory tool.
- **Thumbnail:** use a frame from the video, not a mock-up. The s04 scan table (`docs/images/scan.png`) or the s07 preservation table works well. You can put the words "SAS + R → define metadata" over it in large type. Don't use Harvard or CBAR logos.
