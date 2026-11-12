#!/usr/bin/env python3
"""Build demo/DEFX_Bridge_Demo.mp4 from REAL terminal recordings.

Every terminal scene is a VHS recording (https://github.com/charmbracelet/vhs): VHS
starts a real bash shell, types the command, and records what the shell prints.
Nothing is simulated and nothing is sped up. The only hidden step in each tape is
the shell setup line (prompt, lower CPU priority for the typed commands so the
recorder keeps up, clear). Title/closing cards and the caption bar are
rendered from HTML with headless Chrome and composited with ffmpeg.

Run from the repository root:   python3 demo/build_video.py
Needs: vhs, ffmpeg/ffprobe, Google Chrome, R with openxlsx + readxl.
"""
import hashlib, html, json, os, shutil, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEMO = ROOT / "demo"
WORK = DEMO / "work"
TAPES = DEMO / "tapes"
OUT = DEMO / "DEFX_Bridge_Demo.mp4"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
REPO_URL = "github.com/parammadan/defx-bridge"
W, H, TERM_H = 1920, 1080, 950          # terminal area 1920x950, caption bar below
FADE = 0.3
BG = "#1e1e2e"                          # Catppuccin Mocha base (matches the VHS theme)

V = "./bin/defxbridge"
SCENES = [
    {"id": "s01", "kind": "card", "card": "title", "secs": 7.0,
     "caption": "DEFX Bridge: an independent prototype inspired by the published DEFX approach (Bartley & Hinger, PharmaSUG 2026, AP-220)."},
    {"id": "s02", "kind": "term", "sleep": 8,
     "steps": [("# The SAS program: DEFX tags are ordinary comments beside the code", 0.6),
               ("cat -n examples/valid/makeadae.sas | sed -n '19,37p'", 0)],
     "caption": "A real SAS program. Each /* DEFX | ... */ comment documents the code beside it. "
                "The three ADAE.AERELFL lines (27-29) are one method, not three duplicates."},
    {"id": "s03", "kind": "term", "sleep": 8,
     "steps": [("# The R program: the same tag syntax, written as R comments", 0.6),
               ("cat -n examples/valid/makeadsl.R | sed -n '9,22p'", 1.5),
               ("cat -n examples/valid/makeadsl.R | sed -n '47,49p'", 0)],
     "caption": "A real R program using the same syntax as # comments. Line 49 is a DEFX-like "
                "string literal: it is code, not a comment, so it must be ignored."},
    {"id": "s04", "kind": "term", "sleep": 9,
     "steps": [("# scan: extract + normalize both languages, keeping file:line provenance", 0.6),
               (f"{V} scan --source examples/valid --spec examples/spec.csv --out artifacts/scan.csv | head -n 24", 0)],
     "caption": "scan: 48 tag lines become 40 records (SAS 15, R 25), each with its language, "
                "dataset.variable and file:line provenance, e.g. makeadae.sas:27;28;29."},
    {"id": "s05", "kind": "term", "sleep": 5,
     "steps": [("# validate against the synthetic specification", 0.6),
               (f"{V} validate --source examples/valid --spec examples/spec.csv", 0)],
     "caption": "validate: every tagged target is checked against a synthetic 71-row "
                "specification. Result: 0 errors, 0 warnings."},
    {"id": "s06", "kind": "term", "sleep": 9,
     "steps": [("# a deliberately invalid tag: the variable is not in the spec", 0.6),
               ("cat examples/invalid/unknown_variable.R", 1.2),
               (f'{V} validate --source examples/invalid/unknown_variable.R --spec examples/spec.csv; echo "exit code: $?"', 0)],
     "caption": "The unknown variable is reported with its file and line (unknown_variable.R:2) "
                "and exit code 2. Errors are surfaced, never silently accepted."},
    {"id": "s07", "kind": "term", "sleep": 9,
     "steps": [(f"{V} export --source examples/valid --spec examples/spec.csv \\", 0),
               ("  --template examples/define_like_template.xlsx --out artifacts/define_like_filled.xlsx", 0)],
     "caption": "export: fills a COPY of the define-like template, re-reads it from disk, and "
                "keeps it only because all 14 preservation checks pass."},
    {"id": "s08", "kind": "term", "sleep": 9,
     "steps": [("# the generated workbook, read back from the .xlsx file with readxl", 0.6),
               ('scripts/show_sheet.R artifacts/define_like_filled.xlsx Methods --cols ID,Type,Description,"Expression Code" --max 6', 3.0),
               ("scripts/show_sheet.R artifacts/define_like_filled.xlsx PreserveMe", 0)],
     "caption": "Methods, read from the generated file: the three AERELFL lines are joined in order, "
                "and the hand-entered Expression Code cell is kept. PreserveMe is unchanged."},
    {"id": "s09", "kind": "term", "sleep": 9,
     "steps": [("# Variables before (template) and after (generated workbook)", 0.6),
               ("scripts/show_sheet.R examples/define_like_template.xlsx Variables --where Variable=AERELFL --cols Dataset,Variable,Origin,Method", 3.0),
               ('scripts/show_sheet.R artifacts/define_like_filled.xlsx Variables --where Dataset=ADAE --cols Variable,Origin,Method,"Developer Notes"', 0)],
     "caption": "Variables: the stale Origin 'Assigned' becomes 'Derived' with its method. Rows "
                "without tags, such as AESEQ, keep their hand-entered values."},
    {"id": "s10", "kind": "card", "card": "closing", "secs": 10.0,
     "caption": "DEFX Bridge: an independent prototype exploring reproducible metadata workflows across SAS and R."},
]


def run(cmd, **kw):
    print("+", " ".join(map(str, cmd)) if isinstance(cmd, list) else cmd, flush=True)
    return subprocess.run(cmd, check=True, **kw)


def probe(p):
    return float(subprocess.check_output(["ffprobe", "-v", "error", "-show_entries", "format=duration",
                                          "-of", "csv=p=0", str(p)]).decode())


def vhs_quote(s):
    for q in ('"', "`", "'"):
        if q not in s:
            return f"{q}{s}{q}"
    raise ValueError(f"cannot quote for VHS: {s}")


def write_tape(scene):
    raw = WORK / f"{scene['id']}_raw.mp4"
    lines = [f"Output {raw.relative_to(ROOT)}", 'Set Shell "bash"', "Set FontSize 22", 'Set FontFamily "Menlo"',
             f"Set Width {W}", f"Set Height {TERM_H}", "Set Padding 36",
             'Set Theme "Catppuccin Mocha"', "Set TypingSpeed 15ms", "Set Framerate 20",
             "Hide", "Type \"export PS1='$ ' PS2='> ' && renice -n 15 -p $$ >/dev/null && clear\"", "Enter", "Sleep 300ms", "Show"]
    for cmd, pause in scene["steps"]:
        lines += [f"Type {vhs_quote(cmd)}", "Enter"]
        if pause:
            lines.append(f"Sleep {pause}s")
    lines.append(f"Sleep {scene['sleep']}s")
    tape = TAPES / f"{scene['id']}.tape"
    tape.write_text("\n".join(lines) + "\n")
    return tape, raw


CARD_CSS = f"""
* {{ margin:0; padding:0; box-sizing:border-box; }}
html,body {{ width:{W}px; height:{H}px; background:{BG}; color:#cdd6f4;
  font-family:-apple-system,"Helvetica Neue",Helvetica,Arial,sans-serif; }}
.wrap {{ position:absolute; inset:0; padding:120px 150px; display:flex; flex-direction:column; justify-content:center; }}
h1 {{ font-size:104px; font-weight:700; letter-spacing:-1px; color:#ffffff; }}
h2 {{ font-size:42px; font-weight:400; color:#89b4fa; margin-top:18px; }}
.mono {{ font-family:Menlo,monospace; font-size:28px; color:#a6e3a1; background:#181825;
  border-left:4px solid #89b4fa; padding:14px 22px; margin-top:12px; }}
p {{ font-size:30px; line-height:1.45; color:#bac2de; margin-top:34px; max-width:1500px; }}
.small {{ font-size:24px; color:#7f849c; margin-top:40px; line-height:1.5; }}
.url {{ font-family:Menlo,monospace; font-size:36px; color:#f9e2af; margin-top:30px; }}
"""


def card_html(kind):
    if kind == "title":
        body = f"""<h1>DEFX Bridge</h1>
<h2>Cross-language metadata extraction and validation for SAS &amp; R</h2>
<div style="margin-top:46px">
<div class="mono">/* DEFX | ADAE.AERELFL | Y if AE.AEREL="RELATED" */</div>
<div class="mono"># DEFX | ADSL.AGE | Predecessor | DM.AGE</div></div>
<p>An independent R prototype inspired by the published DEFX approach: structured comments in
statistical programs become define.xml metadata.</p>
<div class="small">Param Madan &middot; DEFX concept: Brendan Bartley &amp; Megan Hinger, PharmaSUG 2026, Paper AP-220<br>
Not affiliated with or endorsed by CBAR or PharmaSUG &middot; synthetic data only</div>"""
    else:
        body = f"""<h2 style="margin-top:0;color:#cdd6f4;font-size:46px;line-height:1.35">One tag convention for SAS and R programs
lets a study move derivations to R one program at a time, while the same validated metadata
keeps flowing into the define workbook.</h2>
<p style="color:#ffffff;font-size:36px">DEFX Bridge: an independent prototype exploring reproducible metadata workflows across SAS and R.</p>
<div class="url">{REPO_URL}</div>
<div class="small">Credits: DEFX tag concept and paper by Brendan Bartley &amp; Megan Hinger (PharmaSUG 2026, AP-220);
original DEFX SAS macro by Megan Hinger; defxit script by Scott Anderson; testing acknowledged to Shawn Ward.<br>
DEFX Bridge is a separate implementation: no code from the paper or any internal repository.
Not affiliated with or endorsed by CBAR or PharmaSUG. Synthetic data only. Not a validated or regulatory tool.</div>"""
    return f"<!doctype html><html><head><meta charset='utf-8'><style>{CARD_CSS}</style></head><body><div class='wrap'>{body}</div></body></html>"


def caption_html(text, tag):
    return f"""<!doctype html><html><head><meta charset="utf-8"><style>
* {{ margin:0; padding:0; box-sizing:border-box; }}
html,body {{ width:{W}px; height:{H - TERM_H}px; background:{BG};
  font-family:-apple-system,"Helvetica Neue",Helvetica,Arial,sans-serif; }}
.bar {{ position:absolute; inset:0; border-top:2px solid #45475a; padding:16px 48px;
  display:flex; align-items:center; gap:40px; }}
.t {{ flex:1; font-size:29px; line-height:1.3; color:#ffffff; }}
.tag {{ font-size:18px; color:#a6e3a1; text-align:right; line-height:1.4; white-space:nowrap;
  border:1px solid #45475a; border-radius:6px; padding:8px 14px; }}
</style></head><body><div class="bar"><div class="t">{html.escape(text)}</div>
<div class="tag">{tag}</div></div></body></html>"""


def shot(html_text, png, w, h):
    src = WORK / (png.stem + ".html")
    src.write_text(html_text)
    run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1",
         f"--window-size={w},{h}", f"--screenshot={png}", src.as_uri()],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if not png.exists():
        sys.exit(f"Chrome did not produce {png}")


def enc(extra_in, filt, out, dur=None):
    cmd = ["nice", "-n", "19", "ffmpeg", "-loglevel", "error", "-y", *extra_in, "-filter_complex", filt,
           "-map", "[v]", "-an", "-c:v", "libx264", "-preset", "medium", "-crf", "20",
           "-pix_fmt", "yuv420p", "-r", "30"]
    if dur:
        cmd += ["-t", f"{dur:.3f}"]
    run(cmd + [str(out)])


def srt_time(t):
    ms = int(round(t * 1000)); h, ms = divmod(ms, 3600000); m, ms = divmod(ms, 60000); s, ms = divmod(ms, 1000)
    return f"{h:02}:{m:02}:{s:02},{ms:03}"


def main():
    os.chdir(ROOT)
    for tool in ("vhs", "ffmpeg", "ffprobe", "Rscript"):
        if not shutil.which(tool):
            sys.exit(f"missing tool: {tool}")
    WORK.mkdir(parents=True, exist_ok=True); TAPES.mkdir(exist_ok=True)
    shutil.rmtree(ROOT / "artifacts", ignore_errors=True)   # nothing on screen may be stale
    (ROOT / "artifacts").mkdir()
    only = set(sys.argv[1:])
    segs = []
    for sc in SCENES:
        seg = WORK / f"{sc['id']}.mp4"
        if sc["kind"] == "term":
            tag = "LIVE TERMINAL RECORDING<br>real commands &middot; real output &middot; not sped up"
            cap = WORK / f"{sc['id']}_cap.png"; shot(caption_html(sc["caption"], tag), cap, W, H - TERM_H)
            tape, raw = write_tape(sc)
            if not only or sc["id"] in only or not raw.exists():
                run(["vhs", str(tape)], stdout=subprocess.DEVNULL)   # not niced: capture must keep up
            d = probe(raw)
            # Real-time check: VHS drops frames under CPU load, which would make the clip play
            # faster than the session ran. Expected = typing (15 ms/char + Enter) + pauses + final sleep.
            expected = sum(len(c) * 0.015 + 0.1 + p for c, p in sc["steps"]) + sc["sleep"]
            sc["realtime_ratio"] = round(d / expected, 3)
            print(f"{sc['id']}: recorded {d:.2f}s, expected ~{expected:.2f}s real time (ratio {d / expected:.2f})")
            if not 0.9 <= d / expected <= 1.35:
                sys.exit(f"{sc['id']}: recording is not real-time (ratio {d / expected:.2f}); re-run on a quieter machine")
            enc(["-i", str(raw), "-loop", "1", "-i", str(cap)],
                f"[0:v]fps=30,pad={W}:{H}:0:0:color={BG}[b];[b][1:v]overlay=0:{TERM_H}:shortest=1,"
                f"fade=t=in:st=0:d={FADE},fade=t=out:st={d - FADE:.3f}:d={FADE},format=yuv420p[v]", seg, d)
        else:
            png = WORK / f"{sc['id']}_card.png"; shot(card_html(sc["card"]), png, W, H)
            d = sc["secs"]
            enc(["-loop", "1", "-framerate", "30", "-i", str(png)],
                f"[0:v]fade=t=in:st=0:d=0.6,fade=t=out:st={d - 0.6:.3f}:d=0.6,format=yuv420p[v]", seg, d)
        segs.append((sc, seg, probe(seg)))

    lst = WORK / "list.txt"
    lst.write_text("".join(f"file '{p}'\n" for _, p, _ in segs))
    run(["ffmpeg", "-loglevel", "error", "-y", "-f", "concat", "-safe", "0", "-i", str(lst),
         "-c", "copy", "-movflags", "+faststart", str(OUT)])

    # subtitles from measured segment durations
    t, cues = 0.0, []
    for i, (sc, _, d) in enumerate(segs, 1):
        cues.append(f"{i}\n{srt_time(t + 0.2)} --> {srt_time(t + d - 0.2)}\n{sc['caption']}\n")
        t += d
    (DEMO / "captions.srt").write_text("\n".join(cues))
    timeline = [{"id": sc["id"], "kind": sc["kind"], "start": round(sum(x[2] for x in segs[:i]), 2),
                 "duration": round(d, 2), "realtime_ratio": sc.get("realtime_ratio"),
                 "commands": [c for c, _ in sc.get("steps", [])]} for i, (sc, _, d) in enumerate(segs)]
    (WORK / "timeline.json").write_text(json.dumps(timeline, indent=1))
    sha = hashlib.sha256(OUT.read_bytes()).hexdigest()
    print(f"\n{OUT}  {probe(OUT):.2f}s  {OUT.stat().st_size} bytes  sha256 {sha}")


if __name__ == "__main__":
    main()
