/**
 * DefxWalk.tsx — DEFX Bridge demo V2.
 * Terminal panels are REAL VHS recordings (public/defx/t_*.mp4) of real commands.
 * Every table, cell, number and source line comes from defx-data.json, which
 * ~/books/defx-bridge/walkthrough/capture.py extracted from the files written by
 * those same runs (scan.csv, diagnostics CSV, the exported .xlsx read with readxl).
 * Data views are labelled with the file they were rendered from; the workbook view
 * is a preview, explicitly not Microsoft Excel.
 */
import React from 'react';
import { OffthreadVideo, Img, Sequence, staticFile, interpolate, Easing, useVideoConfig } from 'remotion';
import { PANEL, LINE, TEXT, DIM, CYAN, RED, GREEN, AMBER, MONO, useT, fade, Stage, Kicker } from './ChaosBatchWalk';
import D from './defx-data.json';

const D_: any = D;
const CLIP_W = 1860, CLIP_H = 840, LH = 30.75, CW = 16.0, PADX = 30, Y0 = 53, BAR = 46;   // measured from a recorded frame

const ease = (s: number, a: number, b: number) =>
  interpolate(s, [a, b], [0, 1], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing: Easing.inOut(Easing.cubic) });

/* ---------- shared pieces ---------- */

const Badge: React.FC<{ text: string; color?: string; o?: number; style?: React.CSSProperties }> = ({ text, color = DIM, o = 1, style }) => (
  <div style={{ fontFamily: MONO, fontSize: 20, color, border: `1px solid ${color}55`, borderRadius: 8, padding: '6px 12px',
    background: 'rgba(11,13,18,0.85)', opacity: o, whiteSpace: 'nowrap', ...style }}>{text}</div>
);

type HL = { line: number; col?: number; len: number; at: number; color: string };

/** A real terminal recording in a window frame, with highlight boxes placed on real output lines. */
const Term: React.FC<{ clip: string; dur: number; x: number; y: number; w: number; s: number; start?: number;
  startFrom?: number; rate?: number; hl?: HL[]; o?: number; title?: string; tag?: string }> =
({ clip, dur, x, y, w, s, start = 0, startFrom = 0, rate = 1, hl = [], o = 1, title = 'bash', tag = 'REAL TERMINAL RECORDING · not sped up' }) => {
  const { fps } = useVideoConfig();
  const k = w / CLIP_W, h = CLIP_H * k;
  const playable = (dur - startFrom) / rate;             // seconds of footage after startFrom
  return (
    <div style={{ position: 'absolute', left: x, top: y, width: w, opacity: o, borderRadius: 14, overflow: 'hidden',
      border: `1px solid ${LINE}`, boxShadow: '0 30px 80px rgba(0,0,0,0.55)', background: '#1e1e2e' }}>
      <div style={{ height: BAR, background: '#15161f', display: 'flex', alignItems: 'center', gap: 9, padding: '0 16px' }}>
        {['#ff5f57', '#febc2e', '#28c840'].map(c => <div key={c} style={{ width: 13, height: 13, borderRadius: 7, background: c }} />)}
        <div style={{ marginLeft: 14, fontFamily: MONO, fontSize: 19, color: DIM }}>{title}</div>
        <div style={{ marginLeft: 'auto' }}><Badge text={tag} color={GREEN} /></div>
      </div>
      <div style={{ position: 'relative', width: w, height: h }}>
        <Sequence from={Math.round(start * fps)} durationInFrames={Math.max(1, Math.round(playable * fps) - 1)} layout="none">
          <OffthreadVideo src={staticFile(`defx/${clip}.mp4`)} startFrom={Math.round(startFrom * fps)} playbackRate={rate} muted
            style={{ width: w, height: h, display: 'block' }} />
        </Sequence>
        {s >= start + playable - 0.05 && <Img src={staticFile(`defx/${clip}_last.png`)} style={{ position: 'absolute', inset: 0, width: w, height: h }} />}
        {hl.map((b, i) => {
          const on = fade(s, b.at, b.at + 0.35);
          return <div key={i} style={{ position: 'absolute', left: (PADX + (b.col ?? 0) * CW) * k - 8, top: (Y0 + b.line * LH - LH / 2) * k - 4,
            width: b.len * CW * k + 16, height: LH * k + 8, border: `3px solid ${b.color}`, borderRadius: 8, opacity: on,
            boxShadow: `0 0 ${18 * on}px ${b.color}`, background: `${b.color}14` }} />;
        })}
      </div>
    </div>
  );
};

/** Colour one DEFX comment line: marker, keyword, pipes, name, description. */
const TagLine: React.FC<{ text: string; glow?: number; size?: number }> = ({ text, glow = 0, size = 27 }) => {
  const m = text.match(/^(\s*)(\/\*|#)(\s*)(DEFX)(\s*\|\s*)([A-Z0-9_.]+)(\s*\|\s*)(.*?)(\s*\*\/)?$/);
  if (!m) return <span style={{ color: '#a6adc8' }}>{text}</span>;
  return (
    <span style={{ textShadow: glow ? `0 0 ${16 * glow}px ${GREEN}` : 'none' }}>
      <span>{m[1]}</span><span style={{ color: DIM }}>{m[2]}{m[3]}</span>
      <span style={{ color: CYAN, fontWeight: 700 }}>{m[4]}</span><span style={{ color: DIM }}>{m[5]}</span>
      <span style={{ color: AMBER, fontWeight: 700 }}>{m[6]}</span><span style={{ color: DIM }}>{m[7]}</span>
      <span style={{ color: TEXT }}>{m[8]}</span><span style={{ color: DIM }}>{m[9] ?? ''}</span>
    </span>
  );
};

const CodeCard: React.FC<{ file: string; from: number; lines: string[]; x: number; y: number; w: number; o?: number;
  glow?: number; size?: number; lang: string }> = ({ file, from, lines, x, y, w, o = 1, glow = 0, size = 26, lang }) => (
  <div style={{ position: 'absolute', left: x, top: y, width: w, opacity: o, background: PANEL, borderRadius: 14,
    border: `1px solid ${LINE}`, overflow: 'hidden', boxShadow: '0 24px 60px rgba(0,0,0,0.45)' }}>
    <div style={{ display: 'flex', justifyContent: 'space-between', padding: '12px 20px', borderBottom: `1px solid ${LINE}`,
      fontFamily: MONO, fontSize: 21 }}>
      <span style={{ color: TEXT }}>{file}</span><span style={{ color: lang === 'SAS' ? AMBER : CYAN }}>{lang}</span>
    </div>
    <div style={{ padding: '14px 0', fontFamily: MONO, fontSize: size, lineHeight: 1.55, whiteSpace: 'pre' }}>
      {lines.map((l, i) => (
        <div key={i} style={{ display: 'flex' }}>
          <span style={{ width: 60, textAlign: 'right', paddingRight: 18, color: '#4b5263' }}>{from + i}</span>
          <TagLine text={l} glow={/DEFX/.test(l) ? glow : 0} size={size} />
        </div>
      ))}
    </div>
  </div>
);

/** Spreadsheet-like grid rendered from real cell values. */
const Sheet: React.FC<{ cols: string[]; rows: string[][]; widths: number[]; x: number; y: number; o?: number;
  cell?: (r: number, c: number) => React.CSSProperties | undefined; tab: string; size?: number }> =
({ cols, rows, widths, x, y, o = 1, cell, tab, size = 22 }) => (
  <div style={{ position: 'absolute', left: x, top: y, opacity: o, background: '#ffffff', borderRadius: 10, overflow: 'hidden',
    boxShadow: '0 24px 60px rgba(0,0,0,0.5)', border: '1px solid #c8ccd4' }}>
    <div style={{ display: 'flex', background: '#eef0f4', borderBottom: '1px solid #c8ccd4' }}>
      <div style={{ width: 46, borderRight: '1px solid #d5d8de' }} />
      {cols.map((c, i) => <div key={c} style={{ width: widths[i], padding: '8px 10px', fontSize: size - 2, fontWeight: 700, color: '#30343c',
        borderRight: '1px solid #d5d8de', fontFamily: 'Inter, system-ui, sans-serif' }}>{c}</div>)}
    </div>
    {rows.map((r, ri) => (
      <div key={ri} style={{ display: 'flex', borderBottom: '1px solid #e3e5ea' }}>
        <div style={{ width: 46, textAlign: 'center', padding: '8px 0', fontSize: size - 4, color: '#8a909c', background: '#f6f7f9',
          borderRight: '1px solid #d5d8de' }}>{ri + 2}</div>
        {r.map((v, ci) => <div key={ci} style={{ width: widths[ci], padding: '8px 10px', fontSize: size, color: '#1c1f26',
          fontFamily: MONO, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis', borderRight: '1px solid #e3e5ea',
          position: 'relative', ...(cell ? cell(ri, ci) : {}) }}>{v}</div>)}
      </div>
    ))}
    <div style={{ display: 'flex', gap: 2, background: '#e7e9ee', padding: '6px 8px 0', borderTop: '1px solid #c8ccd4' }}>
      {['Datasets', 'Variables', 'Methods', 'Comments', 'PreserveMe'].map(t => (
        <div key={t} style={{ padding: '6px 16px', fontSize: 17, fontFamily: 'Inter, system-ui, sans-serif',
          background: t === tab ? '#ffffff' : 'transparent', color: t === tab ? '#1f7a4d' : '#5b616e', fontWeight: t === tab ? 700 : 500,
          borderRadius: '6px 6px 0 0', borderBottom: t === tab ? '3px solid #1f7a4d' : 'none' }}>{t}</div>
      ))}
    </div>
  </div>
);

const hlCell = (on: number, color: string): React.CSSProperties =>
  ({ background: `rgba(${color === 'green' ? '61,220,151' : color === 'amber' ? '255,200,87' : '255,77,109'},${0.35 * on})`,
     outline: on > 0.01 ? `3px solid ${color === 'green' ? '#1f9d63' : color === 'amber' ? '#d39a12' : '#d92d4b'}` : 'none', outlineOffset: -3 });

/* ---------- s00: author introduction (on-screen text only, no voice) ---------- */
export const DefxIntro: React.FC = () => {
  const { s } = useT();
  return (
    <Stage>
      <div style={{ position: 'absolute', left: 160, top: 330, fontSize: 84, fontWeight: 800, letterSpacing: -2, opacity: fade(s, 0.2, 0.9),
        transform: `translateY(${(1 - fade(s, 0.2, 0.9)) * 18}px)` }}>
        Hi, I'm <span style={{ color: CYAN }}>Param Madan</span>.
      </div>
      <div style={{ position: 'absolute', left: 160, top: 470, width: 1560, fontSize: 44, lineHeight: 1.4, color: TEXT, opacity: fade(s, 1.0, 1.8) }}>
        I built <span style={{ fontWeight: 700 }}>DEFX Bridge</span>, an independent R-based prototype inspired by the DEFX work presented at
        <span style={{ color: AMBER }}> PharmaSUG 2026</span>.
      </div>
      <div style={{ position: 'absolute', left: 160, top: 640, width: 220, height: 4, background: CYAN, opacity: fade(s, 1.6, 2.2) }} />
      <div style={{ position: 'absolute', left: 160, top: 670, fontFamily: MONO, fontSize: 24, color: DIM, opacity: fade(s, 2.0, 2.6) }}>
        github.com/parammadan/defx-bridge
      </div>
    </Stage>
  );
};

/* ---------- s01: the problem ---------- */
export const DefxHook: React.FC = () => {
  const { s } = useT();
  const src = D_.source;
  const turn = fade(s, 7.9, 8.6);
  const typed = Math.round(interpolate(s, [3.6, 6.6], [0, 58], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' }));
  const desc = D_.method.Description as string;
  return (
    <Stage>
      <Kicker text="DEFX BRIDGE · SAS + R METADATA" o={fade(s, 0, 0.5)} />
      <div style={{ position: 'absolute', left: 120, top: 150, fontSize: 78, fontWeight: 800, letterSpacing: -2, opacity: fade(s, 0.3, 1.0) }}>
        Every derivation is explained <span style={{ color: AMBER }}>twice.</span>
      </div>
      <CodeCard file={src.sas_file} from={src.sas_from} lines={src.sas_lines.slice(0, 6)} x={120} y={320} w={900} lang="SAS"
        o={fade(s, 0.9, 1.6)} glow={turn} size={23} />
      <div style={{ position: 'absolute', left: 1090, top: 320, width: 710, opacity: fade(s, 2.6, 3.2), background: '#fff', borderRadius: 10,
        boxShadow: '0 24px 60px rgba(0,0,0,0.5)', overflow: 'hidden' }}>
        <div style={{ background: '#eef0f4', padding: '10px 16px', fontSize: 20, fontWeight: 700, color: '#30343c' }}>
          define workbook · Methods <span style={{ fontWeight: 400, color: '#8a909c' }}>(illustration)</span></div>
        <div style={{ display: 'flex', borderTop: '1px solid #d5d8de', fontFamily: MONO, fontSize: 21, color: '#1c1f26' }}>
          <div style={{ width: 210, padding: '12px', borderRight: '1px solid #e3e5ea' }}>ADAE.AERELFL</div>
          <div style={{ flex: 1, padding: '12px', minHeight: 96, whiteSpace: 'normal', ...(turn > 0 ? hlCell(turn, 'green') : {}) }}>
            {turn > 0.5 ? desc : desc.slice(0, typed)}{turn < 0.5 && s > 3.6 && s < 7.8 && Math.floor(s * 3) % 2 === 0 ? '▍' : ''}
          </div>
        </div>
      </div>
      <svg width={1920} height={1080} style={{ position: 'absolute', inset: 0, opacity: fade(s, 3.0, 3.5) }}>
        <path d="M 1025 470 C 1050 470, 1060 470, 1085 470" stroke={turn > 0.5 ? GREEN : AMBER} strokeWidth={5}
          strokeDasharray={turn > 0.5 ? '0' : '12 9'} fill="none" markerEnd="url(#a)" />
        <defs><marker id="a" markerWidth="10" markerHeight="10" refX="5" refY="5" orient="auto">
          <path d="M0,0 L10,5 L0,10 z" fill={turn > 0.5 ? GREEN : AMBER} /></marker></defs>
      </svg>
      <div style={{ position: 'absolute', left: 1090, top: 520, fontFamily: MONO, fontSize: 24, color: AMBER, opacity: fade(s, 3.6, 4.0) * (1 - turn) }}>
        ✎ re-typed by hand, after the programming is done
      </div>
      <div style={{ position: 'absolute', left: 1090, top: 520, fontFamily: MONO, fontSize: 24, color: GREEN, opacity: turn }}>
        ✓ filled from the comments beside the code
      </div>
      <div style={{ position: 'absolute', left: 120, top: 760, fontSize: 52, fontWeight: 700, opacity: fade(s, 8.4, 9.1) }}>
        What if the comment <span style={{ color: GREEN }}>were</span> the metadata?
      </div>
    </Stage>
  );
};

/* ---------- s02: one convention, two languages ---------- */
export const DefxTwoLangs: React.FC = () => {
  const { s } = useT();
  const src = D_.source;
  const recs = D_.records.filter((r: any) => r.name === 'ADAE.AERELFL' || r.name === 'ADSL.AGEGR1');
  const down = ease(s, 10.4, 11.4);
  return (
    <Stage>
      <Kicker text="ONE CONVENTION · TWO LANGUAGES" o={fade(s, 0, 0.5)} />
      <div style={{ position: 'absolute', left: 120, top: 145, fontSize: 30, color: DIM, opacity: fade(s, 0.6, 1.2) }}>
        The DEFX approach: <span style={{ color: TEXT }}>Brendan Bartley &amp; Megan Hinger</span>, PharmaSUG 2026 (AP-220)
      </div>
      <div style={{ position: 'absolute', left: 120, top: 195, fontSize: 56, fontWeight: 800, letterSpacing: -1, opacity: fade(s, 4.4, 5.1) }}>
        DEFX Bridge <span style={{ color: DIM, fontWeight: 500, fontSize: 40 }}>· an independent R prototype</span>
      </div>
      <CodeCard file={src.sas_file} from={src.sas_from} lines={src.sas_lines.slice(0, 3)} x={120} y={320} w={820} lang="SAS"
        o={fade(s, 6.8, 7.4)} size={21} glow={fade(s, 7.6, 8.2) * (1 - down * 0.5)} />
      <CodeCard file={src.r_file} from={src.r_from} lines={src.r_lines.slice(0, 3)} x={980} y={320} w={820} lang="R"
        o={fade(s, 7.6, 8.2)} size={21} glow={fade(s, 8.4, 9.0) * (1 - down * 0.5)} />
      <svg width={1920} height={1080} style={{ position: 'absolute', inset: 0, opacity: down }}>
        {[530, 1390].map((x0, i) => <path key={i} d={`M ${x0} 540 C ${x0} 600, 960 590, 960 655`} stroke={GREEN} strokeWidth={4} fill="none" />)}
      </svg>
      <div style={{ position: 'absolute', left: 260, top: 665, width: 1400, opacity: down, background: PANEL, borderRadius: 14,
        border: `1px solid ${GREEN}66`, overflow: 'hidden' }}>
        <div style={{ display: 'flex', padding: '12px 22px', fontFamily: MONO, fontSize: 20, color: DIM, borderBottom: `1px solid ${LINE}` }}>
          {['NAME', 'TYPE', 'ORIGIN', 'LANG', 'SOURCE'].map((c, i) => <div key={c} style={{ width: [380, 230, 200, 120, 400][i] }}>{c}</div>)}
        </div>
        {recs.map((r: any, i: number) => (
          <div key={i} style={{ display: 'flex', padding: '14px 22px', fontFamily: MONO, fontSize: 27, color: TEXT,
            opacity: fade(s, 11.2 + i * 0.4, 11.7 + i * 0.4) }}>
            <div style={{ width: 380, color: AMBER }}>{r.name}</div><div style={{ width: 230 }}>{r.type}</div>
            <div style={{ width: 200 }}>{r.origin}</div><div style={{ width: 120, color: r.language === 'SAS' ? AMBER : CYAN }}>{r.language}</div>
            <div style={{ width: 400, color: GREEN }}>{r.source_file}:{r.source_lines}</div>
          </div>
        ))}
      </div>
      <div style={{ position: 'absolute', left: 260, top: 905, opacity: fade(s, 12.2, 12.8) }}>
        <Badge text="one shared metadata table · rows rendered from artifacts/scan.csv" color={GREEN} />
      </div>
    </Stage>
  );
};

/* ---------- s03: real extraction ---------- */
export const DefxScan: React.FC = () => {
  const { s } = useT();
  const c = D_.clips.t_scan, n = D_.record_counts;
  const out = ease(s, 6.4, 7.4);
  const t0 = 0.2;
  return (
    <Stage>
      <Kicker text="REAL EXTRACTION" o={fade(s, 0, 0.5)} />
      <Term clip="t_scan" dur={c.duration} x={60} y={150 - 20 * out} w={1800 - 980 * out} s={s} start={t0}
        o={1 - 0.35 * out} title="defx-bridge — scan"
        hl={[{ line: 3, len: 22, at: t0 + 4.1, color: CYAN }, { line: 4, len: 46, at: t0 + 4.5, color: GREEN }]} />
      <div style={{ position: 'absolute', left: 940, top: 190, opacity: out, display: 'flex', flexDirection: 'column', gap: 14 }}>
        <div style={{ fontSize: 54, fontWeight: 800 }}>{48} tag lines → <span style={{ color: GREEN }}>{n.n} records</span></div>
        <div style={{ fontSize: 28, color: DIM }}>SAS {n.sas} · R {n.r} · {n.multiline} multi-line · read, never executed</div>
      </div>
      <div style={{ position: 'absolute', left: 60, top: 570, width: 1800, opacity: out, background: PANEL, borderRadius: 14,
        border: `1px solid ${LINE}`, overflow: 'hidden' }}>
        <div style={{ display: 'flex', padding: '14px 24px', fontFamily: MONO, fontSize: 21, color: DIM, borderBottom: `1px solid ${LINE}` }}>
          {['DATASET.VARIABLE', 'TYPE', 'ORIGIN', 'LANG', 'SOURCE FILE : LINES'].map((h, i) =>
            <div key={h} style={{ width: [560, 260, 240, 130, 560][i] }}>{h}</div>)}
        </div>
        {D_.records.map((r: any, i: number) => {
          const row = fade(s, 7.4 + i * 0.25, 7.9 + i * 0.25), srcHl = fade(s, 10.6, 11.2);
          return (
            <div key={i} style={{ display: 'flex', padding: '11px 24px', fontFamily: MONO, fontSize: 27, opacity: row,
              background: i === 0 ? `rgba(61,220,151,${0.08 * srcHl})` : 'transparent' }}>
              <div style={{ width: 560, color: AMBER }}>{r.name}</div><div style={{ width: 260 }}>{r.type}</div>
              <div style={{ width: 240 }}>{r.origin}</div>
              <div style={{ width: 130, color: r.language === 'SAS' ? AMBER : CYAN }}>{r.language}</div>
              <div style={{ width: 560, color: GREEN, textShadow: srcHl ? `0 0 ${12 * srcHl}px ${GREEN}` : 'none' }}>{r.source_file} : {r.source_lines}</div>
            </div>
          );
        })}
      </div>
      <div style={{ position: 'absolute', left: 60, top: 975, opacity: fade(s, 8.6, 9.2) }}>
        <Badge text={`rendered from artifacts/scan.csv, written by the scan above · ${D_.records.length} of ${n.n} records`} />
      </div>
    </Stage>
  );
};

/* ---------- s04: validation catches a real problem ---------- */
export const DefxFail: React.FC = () => {
  const { s } = useT();
  const c = D_.clips.t_invalid, dg = D_.diagnostic;
  const zoom = ease(s, 8.1, 8.9);
  const line2: string = D_.invalid_source[1];
  const [pre, post] = line2.split('DOESNOTEXIST');
  return (
    <Stage>
      <Kicker text="VALIDATION CATCHES A REAL PROBLEM" o={fade(s, 0, 0.5)} />
      <Term clip="t_invalid" dur={c.duration} x={60} y={150} w={1800} s={s} start={0} o={1 - 0.75 * zoom}
        title="defx-bridge — validate (invalid example)"
        hl={[{ line: 2, len: 44, at: 1.8, color: RED }, { line: 11, col: 2, len: 70, at: 4.1, color: RED },
             { line: 16, len: 12, at: 6.2, color: RED }]} />
      <div style={{ position: 'absolute', left: 210, top: 260, width: 1500, opacity: zoom, transform: `scale(${0.92 + 0.08 * zoom})`,
        background: PANEL, borderRadius: 18, border: `2px solid ${RED}`, boxShadow: `0 0 60px rgba(255,77,109,0.35)`, padding: '34px 44px' }}>
        <div style={{ fontFamily: MONO, fontSize: 24, color: DIM }}>{dg.source_file} · line {dg.source_line}</div>
        <div style={{ fontFamily: MONO, fontSize: 40, marginTop: 10, color: TEXT }}>
          {pre}<span style={{ color: RED, textDecoration: 'underline wavy', textDecorationColor: RED, textUnderlineOffset: 10 }}>DOESNOTEXIST</span>{post}
        </div>
        <div style={{ height: 1, background: LINE, margin: '28px 0' }} />
        <div style={{ display: 'flex', alignItems: 'center', gap: 22 }}>
          <div style={{ fontFamily: MONO, fontSize: 30, color: '#fff', background: RED, borderRadius: 8, padding: '4px 14px' }}>{dg.code}</div>
          <div style={{ fontSize: 40, fontWeight: 700 }}>{dg.message}</div>
        </div>
        <div style={{ fontFamily: MONO, fontSize: 26, color: DIM, marginTop: 16 }}>fix: {dg.suggestion}</div>
        <div style={{ display: 'flex', gap: 18, marginTop: 30, opacity: fade(s, 9.4, 9.9) }}>
          <div style={{ fontFamily: MONO, fontSize: 30, color: RED, border: `2px solid ${RED}`, borderRadius: 10, padding: '8px 18px' }}>exit code 2</div>
          <div style={{ fontSize: 28, color: DIM, alignSelf: 'center' }}>a script or CI job stops here: nothing is silently accepted</div>
        </div>
      </div>
    </Stage>
  );
};

/* ---------- s05: the one-line fix ---------- */
export const DefxFix: React.FC = () => {
  const { s } = useT();
  const c = D_.clips.t_fix, r = 1.2;
  const at = (clipT: number) => clipT / r;
  return (
    <Stage>
      <Kicker text="THE FIX: ONE LINE" o={fade(s, 0, 0.5)} />
      <Term clip="t_fix" dur={c.duration} x={60} y={150} w={1800} s={s} start={0} rate={r} title="defx-bridge — corrected copy"
        tag="REAL TERMINAL RECORDING · 1.2× speed"
        hl={[{ line: 3, len: 48, at: at(4.3), color: RED }, { line: 5, len: 42, at: at(4.5), color: GREEN },
             { line: 13, len: 52, at: at(8.0), color: GREEN }, { line: 15, len: 12, at: at(9.6), color: GREEN }]} />
      <div style={{ position: 'absolute', right: 80, top: 85, opacity: fade(s, 0.4, 1.0) }}>
        <Badge text="the original invalid fixture is unchanged; the fix is in artifacts/fixed.R" />
      </div>
    </Stage>
  );
};

/* ---------- s06: the generated workbook ---------- */
export const DefxWorkbook: React.FC = () => {
  const { s } = useT();
  const src = D_.source, m = D_.method, mt = D_.method_template, V = D_.variables;
  const mOn = fade(s, 3.3, 3.9), oOn = fade(s, 6.4, 7.0), keepOn = fade(s, 11.0, 11.6);
  const vcols = ['Variable', 'Label', 'Origin', 'Predecessor', 'Method', 'Comment', 'Developer Notes'];
  const idx = vcols.map(cn => V.cols.indexOf(cn));
  const vrows: string[][] = V.rows.map((r: string[]) => idx.map(i => r[i]));
  const tmpl: string[][] = V.template.map((r: string[]) => idx.map(i => r[i]));
  const aer = vrows.findIndex(r => r[0] === 'AERELFL');
  const swap = s >= 7.0;
  const shown = vrows.map((r, ri) => ri === aer && !swap ? tmpl[ri] : r);
  return (
    <Stage>
      <Kicker text="THE GENERATED WORKBOOK" o={fade(s, 0, 0.5)} />
      <CodeCard file={src.sas_file} from={src.sas_from} lines={src.sas_lines.slice(0, 3)} x={60} y={150} w={560} lang="SAS"
        o={fade(s, 0.6, 1.2)} size={14} glow={mOn} />
      <Sheet tab="Methods" x={650} y={150} o={fade(s, 1.0, 1.6)} size={19}
        cols={['ID', 'Type', 'Description', 'Expression Code']} widths={[190, 150, 660, 170]}
        rows={[[m.ID, m.Type, s < 3.6 ? mt.Description : m.Description, m['Expression Code']]]}
        cell={(r, c) => c === 2 ? { ...hlCell(mOn, 'green'), whiteSpace: 'normal' } : c === 3 ? hlCell(keepOn, 'amber') : undefined} />
      <svg width={1920} height={1080} style={{ position: 'absolute', inset: 0, opacity: mOn }}>
        <path d="M 622 215 C 680 215, 900 300, 1180 268" stroke={GREEN} strokeWidth={4} fill="none" strokeDasharray="10 7" />
      </svg>
      <div style={{ position: 'absolute', left: 650, top: 345, fontFamily: MONO, fontSize: 21, color: GREEN, opacity: mOn }}>
        3 tag lines → 1 method description
      </div>
      <div style={{ position: 'absolute', left: 1640, top: 345, fontFamily: MONO, fontSize: 21, color: AMBER, opacity: keepOn }}>
        hand-entered · kept
      </div>
      <Sheet tab="Variables" x={60} y={420} o={fade(s, 5.4, 6.0)} size={20}
        cols={vcols} widths={[150, 380, 160, 160, 210, 210, 400]} rows={shown}
        cell={(r, c) => {
          if (r === aer && c === 2) return swap ? hlCell(oOn, 'green') : hlCell(fade(s, 5.9, 6.3), 'red');
          if (r === aer && (c === 4 || c === 5)) return hlCell(fade(s, 7.6, 8.2), 'green');
          if (c === 6 && shown[r][6]) return hlCell(keepOn, 'amber');
          return undefined;
        }} />
      <div style={{ position: 'absolute', left: 60, top: 860, display: 'flex', gap: 16 }}>
        <Badge o={fade(s, 6.0, 6.4) * (swap ? 0 : 1)} color={RED} text="template: Origin = Assigned (stale)" />
        <Badge o={oOn} color={GREEN} text="tag: Computation → Origin = Derived, Method = ADAE.AERELFL" />
        <Badge o={fade(s, 9.0, 9.6)} color={GREEN} text={`all ${D_.methods_resolvable.n} Method references resolve to a Methods row`} />
      </div>
      <div style={{ position: 'absolute', left: 60, top: 915, opacity: keepOn }}>
        <Badge color={AMBER} text="untagged rows (AESEQ) and Developer Notes: unchanged from the template" />
      </div>
      <div style={{ position: 'absolute', left: 60, top: 985, opacity: fade(s, 1.2, 1.8) }}>
        <Badge text="preview rendered from artifacts/define_like_filled.xlsx (read with readxl) · not Microsoft Excel" />
      </div>
    </Stage>
  );
};

/* ---------- s07: verification ---------- */
export const DefxVerify: React.FC = () => {
  const { s } = useT();
  const ce = D_.clips.t_export, ct = D_.clips.t_tests, pv = D_.preservation;
  const phB = 8.3, phC = 10.9;
  const showA = s < phB, showB = s >= phB && s < phC, showC = s >= phC;
  const chip = (t: number, big: string, small: string, src: string) => (
    <div style={{ opacity: fade(s, t, t + 0.5), transform: `translateX(${(1 - fade(s, t, t + 0.5)) * 40}px)`, background: PANEL,
      border: `1px solid ${GREEN}66`, borderRadius: 14, padding: '20px 24px', width: 520 }}>
      <div style={{ fontSize: 40, fontWeight: 800, color: GREEN }}>✓ {big}</div>
      <div style={{ fontSize: 24, color: TEXT, marginTop: 6 }}>{small}</div>
      <div style={{ fontFamily: MONO, fontSize: 17, color: DIM, marginTop: 8 }}>{src}</div>
    </div>
  );
  return (
    <Stage>
      <Kicker text="VERIFIED, NOT ASSUMED" o={fade(s, 0, 0.5)} />
      {showA && <Term clip="t_export" dur={ce.duration} x={60} y={160} w={1240} s={s} start={0} startFrom={3.6}
        title="defx-bridge — export"
        hl={[{ line: 2, col: 2, len: 70, at: 2.4, color: GREEN }, { line: 9, len: 37, at: 2.7, color: GREEN }]} />}
      {showB && <>
        <Term clip="t_tests" dur={0.9} x={60} y={160} w={1240} s={s} start={phB} title="defx-bridge — test suite" tag="REAL RECORDING · condensed" />
        {s >= phB + 0.9 && <div style={{ position: 'absolute', left: 60, top: 160 }}>
          <Term clip="t_tests" dur={ct.duration} x={0} y={0} w={1240} s={s} start={phB + 0.9} startFrom={26.4}
            title="defx-bridge — test suite" tag="REAL RECORDING · ~25 s of progress cut"
            hl={[{ line: 1, len: 39, at: phB + 1.3, color: GREEN }]} />
        </div>}
      </>}
      {showC && <div style={{ position: 'absolute', left: 60, top: 160, width: 1240, opacity: fade(s, phC, phC + 0.4), borderRadius: 14,
        overflow: 'hidden', border: `1px solid ${LINE}`, boxShadow: '0 30px 80px rgba(0,0,0,0.55)' }}>
        <div style={{ height: 46, background: '#15161f', display: 'flex', alignItems: 'center', padding: '0 18px', fontFamily: MONO, fontSize: 19, color: DIM }}>
          github.com/parammadan/defx-bridge/actions
          <div style={{ marginLeft: 'auto' }}><Badge text={`screenshot of the public Actions page · ${D_.ci_captured || D_.captured}`} color={GREEN} /></div>
        </div>
        <Img src={staticFile('defx/ci.png')} style={{ width: 1240, display: 'block' }} />
        <div style={{ position: 'absolute', left: 300, top: 46 + 268 * (1240 / 1600), width: 900, height: 46, border: `3px solid ${GREEN}`,
          borderRadius: 8, opacity: fade(s, phC + 0.8, phC + 1.2), boxShadow: `0 0 18px ${GREEN}` }} />
      </div>}
      <div style={{ position: 'absolute', left: 1340, top: 160, display: 'flex', flexDirection: 'column', gap: 22 }}>
        {chip(6.4, `${pv.pass} / ${pv.total} checks pass`, 're-read with readxl, compared cell by cell', pv.source)}
        {chip(8.9, `${D_.tests?.tests ?? 66} tests · ${D_.tests?.expectations ?? 273} checks`, '0 failed · 0 skipped', 'testthat::test_local(".")')}
        {chip(11.4, 'CI passing on GitHub', 'full suite + R CMD check, no skips allowed', '.github/workflows/ci.yml')}
      </div>
    </Stage>
  );
};

/* ---------- s08: closing ---------- */
export const DefxClose: React.FC = () => {
  const { s } = useT();
  return (
    <Stage>
      <div style={{ position: 'absolute', left: 0, right: 0, top: 200, textAlign: 'center', fontSize: 120, fontWeight: 800, letterSpacing: -3, opacity: fade(s, 0.2, 1.0) }}>
        DEFX Bridge
      </div>
      <div style={{ position: 'absolute', left: 0, right: 0, top: 360, textAlign: 'center', fontSize: 46, color: DIM, opacity: fade(s, 0.8, 1.6) }}>
        Structured metadata across <span style={{ color: AMBER }}>SAS</span> and <span style={{ color: CYAN }}>R</span>.
      </div>
      <div style={{ position: 'absolute', left: 0, right: 0, top: 450, textAlign: 'center', fontSize: 30, color: GREEN, opacity: fade(s, 1.8, 2.6) }}>
        An independent research prototype · synthetic data · read, never executed
      </div>
      <div style={{ position: 'absolute', left: 0, right: 0, top: 545, textAlign: 'center', fontSize: 36, fontWeight: 600, opacity: fade(s, 2.8, 3.6) }}>
        Designed and developed by Param Madan
      </div>
      <div style={{ position: 'absolute', left: 0, right: 0, top: 607, textAlign: 'center', fontFamily: MONO, fontSize: 27, color: CYAN, opacity: fade(s, 3.2, 4.0) }}>
        github.com/parammadan/defx-bridge · parammadan.github.io/defx-bridge
      </div>
      <div style={{ position: 'absolute', left: 0, right: 0, top: 760, textAlign: 'center', fontFamily: MONO, fontSize: 20, letterSpacing: 4, color: CYAN, opacity: fade(s, 4.0, 4.6) }}>
        ORIGINAL DEFX WORK
      </div>
      <div style={{ position: 'absolute', left: 0, right: 0, top: 800, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6, fontSize: 27, color: DIM }}>
        {[['Megan Hinger', 'creator of the original DEFX SAS macro and paper coauthor'],
          ['Brendan Bartley', 'PharmaSUG 2026 paper coauthor (AP-220)'],
          ['Scott Anderson', 'creator of the defxit Linux command-line utility']].map(([n, r], i) => (
          <div key={n} style={{ opacity: fade(s, 4.3 + i * 0.35, 4.9 + i * 0.35) }}>
            <span style={{ color: TEXT, fontWeight: 600 }}>{n}</span> · {r}
          </div>
        ))}
      </div>
      <div style={{ position: 'absolute', left: 160, right: 160, top: 935, textAlign: 'center', fontSize: 19, lineHeight: 1.5, color: DIM, opacity: fade(s, 5.6, 6.2) }}>
        Original program testing: Shawn Ward. DEFX Bridge is a separate implementation with no code from the paper.
        Not affiliated with or endorsed by CBAR or PharmaSUG · not a validated or regulatory tool.
      </div>
    </Stage>
  );
};
