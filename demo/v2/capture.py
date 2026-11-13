#!/usr/bin/env python3
"""DEFX Bridge demo V2: capture REAL footage and REAL data for the Remotion scenes.

1. Deletes ~/defx-bridge/artifacts so nothing shown is stale.
2. Records each terminal step with VHS (a real bash session; commands typed and executed).
   A real-time gate rejects any clip that plays faster than the session ran.
3. Extracts the data views from the files written by those same runs
   (scan.csv, diagnostics, the exported .xlsx via readxl) into defx-data.json.
4. Screenshots the public GitHub Actions page with headless Chrome.
Outputs go to ~/brutalist.art/runtime/remotion/public/defx/ and src/scenes/defx-data.json.
"""
import json, shutil, subprocess, sys, datetime
from pathlib import Path

REPO = Path.home() / "defx-bridge"
W = Path(__file__).resolve().parent
RM = Path.home() / "brutalist.art/runtime/remotion"
PUB = RM / "public/defx"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
V = "./bin/defxbridge"

TAPES = {
    "t_scan": [(f"{V} scan --source examples/valid --spec examples/spec.csv --out artifacts/scan.csv | head -n 4", 0)],
    "t_invalid": [("cat examples/invalid/unknown_variable.R", 1.0),
                  (f"{V} validate --source examples/invalid/unknown_variable.R --spec examples/spec.csv", 2.2), ('echo "exit code: $?"', 0)],
    "t_fix": [("sed 's/DOESNOTEXIST/TRTEMFL/' examples/invalid/unknown_variable.R > artifacts/fixed.R", 0.8),
              ("diff examples/invalid/unknown_variable.R artifacts/fixed.R", 1.2),
              (f"{V} validate --source artifacts/fixed.R --spec examples/spec.csv", 2.2), ('echo "exit code: $?"', 0)],
    "t_export": [(f"{V} export --source examples/valid --spec examples/spec.csv \\", 0),
                 ("  --template examples/define_like_template.xlsx --out artifacts/define_like_filled.xlsx | tail -n 8", 0)],
    "t_tests": [("Rscript -e 'testthat::test_local(\".\")'", 0)],
}
SLEEP = {"t_scan": 5, "t_invalid": 6, "t_fix": 6, "t_export": 7, "t_tests": 45}


def run(cmd, **kw):
    return subprocess.run(cmd, check=True, **kw)


def probe(p):
    return float(subprocess.check_output(["ffprobe", "-v", "error", "-show_entries", "format=duration",
                                          "-of", "csv=p=0", str(p)]).decode())


def vq(s):
    for q in ('"', "`", "'"):
        if q not in s:
            return f"{q}{s}{q}"
    raise ValueError(s)


def record(name, steps):
    raw = W / "raw" / f"{name}.mp4"
    lines = [f"Output raw/{name}.mp4", 'Set Shell "bash"', "Set FontSize 26", 'Set FontFamily "Menlo"',
             "Set Width 1860", "Set Height 840", "Set Padding 30", 'Set Theme "Catppuccin Mocha"',
             "Set TypingSpeed 15ms", "Set Framerate 20", "Hide",
             f"Type \"cd {REPO} && export PS1='$ ' PS2='> ' && renice -n 15 -p $$ >/dev/null && clear\"",
             "Enter", "Sleep 400ms", "Show"]
    for cmd, pause in steps:
        lines += [f"Type {vq(cmd)}", "Enter"] + ([f"Sleep {pause}s"] if pause else [])
    lines.append(f"Sleep {SLEEP[name]}s")
    tape = W / "tapes" / f"{name}.tape"
    tape.write_text("\n".join(lines) + "\n")
    run(["vhs", str(tape)], stdout=subprocess.DEVNULL, cwd=W)
    d = probe(raw)
    exp = sum(len(c) * 0.015 + 0.1 + p for c, p in steps) + SLEEP[name]
    ratio = d / exp
    print(f"{name}: {d:.2f}s recorded, ~{exp:.2f}s expected (ratio {ratio:.2f})")
    if not 0.9 <= ratio <= 1.35:
        sys.exit(f"{name}: not real-time (ratio {ratio:.2f}); retry on a quieter machine")
    return {"file": f"defx/{name}.mp4", "duration": round(d, 2), "realtime_ratio": round(ratio, 3),
            "commands": [c for c, _ in steps]}


R_EXTRACT = r'''
suppressMessages({library(readxl)})
a <- "artifacts"; out <- list()
sc <- read.csv(file.path(a, "scan.csv"), colClasses = "character")
pick <- c("ADAE.AERELFL","ADAE.AETERM","ADAE.ASTDT","ADSL.AGEGR1","STUDYID","AVAL.ADVS.PARAMCD.EQ.SYSBP")
rows <- sc[sc$name %in% pick & !(sc$name == "ADAE.AERELFL" & sc$type == "Comments"), ]
rows <- rows[match(pick, rows$name), ]
out$records <- lapply(seq_len(nrow(rows)), function(i) as.list(rows[i, c("source_file","source_lines","language","name","type","origin","predecessor","description")]))
out$record_counts <- list(n = nrow(sc), sas = sum(sc$language == "SAS"), r = sum(sc$language == "R"), multiline = sum(as.integer(sc$segment_count) > 1))
dv <- read.csv(file.path(a, "invalid_diag.csv"), colClasses = "character")
out$diagnostic <- as.list(dv[1, c("code","severity","source_file","source_line","name","message","suggestion")])
out$invalid_source <- readLines("examples/invalid/unknown_variable.R")
out$fixed_source <- readLines(file.path(a, "fixed.R"))
x <- file.path(a, "define_like_filled.xlsx"); t <- "examples/define_like_template.xlsx"
rd <- function(f, s) as.data.frame(read_excel(f, sheet = s, col_types = "text"))
v <- rd(x, "Variables"); vt <- rd(t, "Variables")
keep <- v$Dataset == "ADAE" & v$Variable %in% c("AESEQ","AETERM","AERELFL","AESAECAT","ASTDT","TRTEMFL")
cols <- c("Dataset","Variable","Label","Origin","Predecessor","Method","Comment","Developer Notes")
vv <- v[keep, cols]; vtt <- vt[keep, cols]
out$variables <- list(cols = cols, rows = unname(lapply(seq_len(nrow(vv)), function(i) unname(as.list(ifelse(is.na(unlist(vv[i,])), "", unlist(vv[i,])))))),
  template = unname(lapply(seq_len(nrow(vtt)), function(i) unname(as.list(ifelse(is.na(unlist(vtt[i,])), "", unlist(vtt[i,])))))))
m <- rd(x, "Methods"); mt <- rd(t, "Methods")
mr <- m[m$ID == "ADAE.AERELFL", c("ID","Type","Description","Expression Context","Expression Code")]
out$method <- lapply(as.list(mr[1, ]), function(z) ifelse(is.na(z), "", z))
out$method_template <- lapply(as.list(mt[mt$ID == "ADAE.AERELFL", c("ID","Type","Description","Expression Context","Expression Code")][1, ]), function(z) ifelse(is.na(z), "", z))
out$method_ids <- m$ID
cm <- rd(x, "Comments"); out$comment <- as.list(cm[cm$ID == "ADAE.AERELFL", c("ID","Description")][1, ])
pm <- rd(x, "PreserveMe"); out$preserve <- unname(lapply(seq_len(nrow(pm)), function(i) unname(as.list(unlist(pm[i, ])))))
out$preserve_template_identical <- identical(pm, rd(t, "PreserveMe"))
refs <- v$Method[!is.na(v$Method)]; out$methods_resolvable <- list(n = length(refs), all = all(refs %in% m$ID))
cat(jsonlite::toJSON(out, auto_unbox = TRUE, pretty = TRUE))
'''


def main():
    for d in ("raw", "tapes"):
        (W / d).mkdir(parents=True, exist_ok=True)
    PUB.mkdir(parents=True, exist_ok=True)
    shutil.rmtree(REPO / "artifacts", ignore_errors=True); (REPO / "artifacts").mkdir()
    only = set(sys.argv[1:])
    clips = {}
    for name, steps in TAPES.items():
        if only and name not in only and (W / "clips.json").exists():
            clips[name] = json.loads((W / "clips.json").read_text())[name]; continue
        clips[name] = record(name, steps)
        shutil.copy(W / "raw" / f"{name}.mp4", PUB / f"{name}.mp4")
    (W / "clips.json").write_text(json.dumps(clips, indent=1))
    # off-camera rerun of the same invalid validation, to have the diagnostic as a CSV (same command + --out)
    subprocess.run([str(REPO / "bin/defxbridge"), "validate", "--source", "examples/invalid/unknown_variable.R",
                    "--spec", "examples/spec.csv", "--out", "artifacts/invalid_diag.csv"], cwd=REPO,
                   stdout=subprocess.DEVNULL)
    data = json.loads(subprocess.check_output(["Rscript", "-e", R_EXTRACT], cwd=REPO).decode())
    rep = (REPO / "artifacts/define_like_filled_report.md").read_text()
    rows = [l for l in rep.splitlines() if l.startswith("| ") and (" | PASS |" in l or " | FAIL |" in l)]
    data["preservation"] = {"pass": sum(" | PASS |" in l for l in rows), "total": len(rows),
                            "source": "artifacts/define_like_filled_report.md"}
    data["captured"] = datetime.date.today().isoformat()
    data["clips"] = clips
    (RM / "src/scenes/defx-data.json").write_text(json.dumps(data, indent=1))
    (W / "defx-data.json").write_text(json.dumps(data, indent=1))
    # real screenshot of the public CI page
    run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--window-size=1600,900",
         "--virtual-time-budget=8000", f"--screenshot={PUB / 'ci.png'}",
         "https://github.com/parammadan/defx-bridge/actions"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    print(json.dumps({k: data[k] for k in ("record_counts", "diagnostic", "methods_resolvable", "preserve_template_identical")}, indent=1))


if __name__ == "__main__":
    main()
