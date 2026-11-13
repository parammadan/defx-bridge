#!/usr/bin/env python3
"""Add the AI narration (Kokoro am_onyx) to the existing demo video WITHOUT touching the picture.

The video stream is copied bit-for-bit (-c:v copy); only an AAC audio track is added. Each
narration clip starts LEAD seconds after its scene starts, and the build fails if a clip
would run into the next scene. Scene start times are the measured ones from video_manifest.md.

    python3 demo/add_voice.py            # run from the repository root
Inputs : demo/DEFX_Bridge_Demo.mp4, demo/voice_script.json, demo/work/voice/audio/sNN.mp3
         (clips made with ~/walkthrough-kit/tools/tts.py, which also Whisper-checks them)
Outputs: demo/DEFX_Bridge_Demo_voiced.mp4, demo/captions_voiced.srt
"""
import json, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "demo/DEFX_Bridge_Demo.mp4"
OUT = ROOT / "demo/DEFX_Bridge_Demo_voiced.mp4"
AUDIO = ROOT / "demo/work/voice/audio"
# measured scene starts/durations (seconds) of DEFX_Bridge_Demo.mp4, see video_manifest.md
SCENES = {"s01": (0.00, 7.00), "s02": (7.00, 10.43), "s03": (17.43, 12.63), "s04": (30.07, 12.67),
          "s05": (42.73, 7.67), "s06": (50.40, 13.33), "s07": (63.73, 11.63), "s08": (75.37, 16.83),
          "s09": (92.20, 17.83), "s10": (110.03, 10.00)}
LEAD = {"s01": 0.2}          # title card: start almost immediately; others use DEFAULT_LEAD
DEFAULT_LEAD = 0.5


def probe(p):
    return float(subprocess.check_output(["ffprobe", "-v", "error", "-show_entries", "format=duration",
                                          "-of", "csv=p=0", str(p)]).decode())


def srt_time(t):
    ms = int(round(t * 1000)); h, ms = divmod(ms, 3600000); m, ms = divmod(ms, 60000); s, ms = divmod(ms, 1000)
    return f"{h:02}:{m:02}:{s:02},{ms:03}"


def main():
    script = json.loads((ROOT / "demo/voice_script.json").read_text())
    total = probe(SRC)
    inputs, filters, cues = ["-i", str(SRC)], [], []
    for n, seg in enumerate(script, start=1):
        sid = seg["id"]; start, dur = SCENES[sid]
        clip = AUDIO / f"{sid}.mp3"; d = probe(clip); at = start + LEAD.get(sid, DEFAULT_LEAD)
        if at + d > start + dur - 0.05:
            sys.exit(f"{sid}: narration {d:.2f}s does not fit its {dur:.2f}s scene (ends {at + d - start:.2f}s in)")
        inputs += ["-i", str(clip)]
        filters.append(f"[{n}:a]aresample=48000,aformat=channel_layouts=stereo,adelay={int(at*1000)}|{int(at*1000)}[a{n}]")
        cues.append(f"{n}\n{srt_time(at)} --> {srt_time(at + d)}\n{seg['caption']}\n")
        print(f"{sid}: {d:5.2f}s voice at {at:6.2f}s, ends {start + dur - (at + d):4.2f}s before scene end")
    mix = "".join(f"[a{i}]" for i in range(1, len(script) + 1))
    filters.append(f"{mix}amix=inputs={len(script)}:normalize=0,apad,atrim=duration={total:.3f},"
                   f"loudnorm=I=-16:TP=-1.5:LRA=11,aresample=48000[aout]")
    subprocess.run(["nice", "-n", "19", "ffmpeg", "-loglevel", "error", "-y", *inputs,
                    "-filter_complex", ";".join(filters), "-map", "0:v", "-map", "[aout]",
                    "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart",
                    "-t", f"{total:.3f}", str(OUT)], check=True)
    (ROOT / "demo/captions_voiced.srt").write_text("\n".join(cues))
    print(f"{OUT}  {probe(OUT):.2f}s")


if __name__ == "__main__":
    main()
