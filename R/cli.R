# Command-line interface ----------------------------------------------------------
#
# Exit codes: 0 = success, 2 = validation errors found, 1 = usage/runtime error.

DEFX_VERSION <- "0.1.0"

HELP <- list(
  main = c(
    "defxbridge - extract DEFX documentation tags from SAS and R programs",
    "",
    "Usage: defxbridge <command> [options]",
    "",
    "Commands:",
    "  scan      Extract and normalize DEFX tags (syntax checks only)",
    "  validate  Scan + validate tags against a metadata specification",
    "  export    Validate, then fill a copy of a define-like .xlsx template",
    "  compare   Check two .xlsx files have identical sheets and cell text",
    "",
    "Run 'defxbridge <command> --help' for options.",
    "Exit codes: 0 success, 2 validation errors, 1 usage or runtime error.",
    "",
    "Independent prototype inspired by Bartley & Hinger, PharmaSUG 2026 AP-220.",
    "Not affiliated with or endorsed by CBAR or PharmaSUG. Synthetic data only."),
  scan = c(
    "Usage: defxbridge scan --source <dir|file> [--source ...] [--spec spec.csv] [--out scan.csv]",
    "",
    "  --source PATH    Directory or .sas/.R file to scan (repeatable). Directories are",
    "                   searched recursively; use --no-recursive to search one level.",
    "  --spec FILE      Optional. Lets single-name tags resolve to dataset vs variable.",
    "  --out FILE       Write consolidated records (one row per definition) as CSV.",
    "  --segments FILE  Write one row per tag line (raw segments) as CSV."),
  validate = c(
    "Usage: defxbridge validate --source <dir|file> --spec spec.csv [--out validation.csv]",
    "",
    "  --source PATH    Directory or .sas/.R file to scan (repeatable).",
    "  --spec FILE      Specification CSV with Dataset,Variable columns (required).",
    "  --out FILE       Write diagnostics as CSV.",
    "  --report FILE    Write a Markdown report (default: <out>.md when --out is given).",
    "  --records FILE   Write validated records as CSV.",
    "  --no-recursive   Do not search sub-directories.",
    "",
    "Exits 2 if any error-severity diagnostic is found."),
  export = c(
    "Usage: defxbridge export --source <dir> --spec spec.csv --template define.xlsx --out filled.xlsx",
    "",
    "  --template FILE  Define-like workbook with Datasets/Variables/Methods/Comments sheets.",
    "                   Never modified.",
    "  --out FILE       Output workbook (must differ from --template). Written atomically",
    "                   and verified against the template before it is moved into place.",
    "  --meta FILE      Traceability CSV of records used (default: <out>_meta.csv).",
    "  --report FILE    Markdown report (default: <out>_report.md).",
    "  --keep-unmatched Keep Methods/Comments rows that no tag matches (like KEEPTAGS=Y).",
    "                   Default drops them (like KEEPTAGS=N).",
    "",
    "No workbook is written when validation finds errors (exit 2)."),
  compare = c(
    "Usage: defxbridge compare A.xlsx B.xlsx",
    "",
    "Exits 0 when both workbooks have the same sheet names and cell text, 2 otherwise.",
    "(Binary .xlsx files differ run to run because of zip metadata; this compares content.)")
)

usage_error <- function(msg, cmd = NULL) {
  hint <- if (is.null(cmd)) "run 'defxbridge --help'" else sprintf("run 'defxbridge %s --help'", cmd)
  stop(defx_input_error(sprintf("%s (%s)", msg, hint)))
}

parse_cli_args <- function(args, cmd, value_opts, flag_opts) {
  opts <- list(); pos <- character()
  i <- 1L
  while (i <= length(args)) {
    a <- args[i]
    if (a %in% c("-h", "--help")) { opts$help <- TRUE; i <- i + 1L; next }
    if (startsWith(a, "--")) {
      key <- sub("^--", "", a); val <- NULL
      if (grepl("=", key, fixed = TRUE)) {
        val <- sub("^[^=]*=", "", key); key <- sub("=.*$", "", key)
      }
      if (key %in% flag_opts) {
        if (!is.null(val)) usage_error(sprintf("--%s takes no value", key), cmd)
        opts[[key]] <- TRUE; i <- i + 1L; next
      }
      if (!key %in% value_opts) usage_error(sprintf("unknown option --%s", key), cmd)
      if (is.null(val)) {
        if (i == length(args) || startsWith(args[i + 1L], "--"))
          usage_error(sprintf("--%s needs a value", key), cmd)
        val <- args[i + 1L]; i <- i + 1L
      }
      if (!nzchar(val)) usage_error(sprintf("--%s needs a non-empty value", key), cmd)
      opts[[key]] <- c(opts[[key]], val)
      i <- i + 1L; next
    }
    pos <- c(pos, a); i <- i + 1L
  }
  opts$positional <- pos
  for (k in setdiff(value_opts, "source"))
    if (length(opts[[k]]) > 1) usage_error(sprintf("--%s given more than once", k), cmd)
  opts
}

stem <- function(p) sub("\\.[^./]*$", "", p)

say <- function(...) emit(sprintf(...))

header_block <- function(res) {
  src <- res$sources; rec <- res$records
  n_sas <- sum(src$language == "SAS"); n_r <- sum(src$language == "R")
  say("Programs scanned : %d (SAS %d, R %d)", nrow(src), n_sas, n_r)
  say("Tag lines found  : %d", nrow(res$segments))
  say("Records          : %d (SAS %d, R %d; %d multi-line)", nrow(rec),
      sum(rec$language == "SAS"), sum(rec$language == "R"), sum(rec$segment_count > 1))
}

cmd_scan <- function(args) {
  o <- parse_cli_args(args, "scan", c("source", "spec", "out", "segments"), c("no-recursive"))
  if (isTRUE(o$help)) { emit(HELP$scan); return(0L) }
  if (length(o$positional)) usage_error(sprintf("unexpected argument '%s'", o$positional[1]), "scan")
  if (is.null(o$source)) usage_error("--source is required", "scan")
  res <- run_pipeline(o$source, o$spec, recursive = !isTRUE(o[["no-recursive"]]))
  say("DEFX Bridge scan")
  header_block(res)
  emit("")
  print_records(res$records)
  if (nrow(res$diagnostics)) { emit(""); print_diags(res$diagnostics) }
  if (!is.null(o$out)) { write_csv_det(res$records, o$out); say("\nRecords written  : %s", o$out) }
  if (!is.null(o$segments)) { write_csv_det(res$segments, o$segments); say("Segments written : %s", o$segments) }
  failed <- any(res$diagnostics$severity == "error")
  say("\nScan %s: %s", if (failed) "FAILED" else "OK", summary_line(res$diagnostics))
  if (failed) 2L else 0L
}

cmd_validate <- function(args) {
  o <- parse_cli_args(args, "validate", c("source", "spec", "out", "report", "records"),
                      c("no-recursive"))
  if (isTRUE(o$help)) { emit(HELP$validate); return(0L) }
  if (length(o$positional)) usage_error(sprintf("unexpected argument '%s'", o$positional[1]), "validate")
  if (is.null(o$source)) usage_error("--source is required", "validate")
  if (is.null(o$spec)) usage_error("--spec is required", "validate")
  res <- run_pipeline(o$source, o$spec, recursive = !isTRUE(o[["no-recursive"]]))
  say("DEFX Bridge validate")
  header_block(res)
  say("Specification    : %s (%d rows)", o$spec, nrow(res$spec))
  if (nrow(res$diagnostics)) { emit(""); print_diags(res$diagnostics) }
  report <- o$report %||% if (!is.null(o$out)) paste0(stem(o$out), ".md") else NULL
  if (!is.null(o$out)) { write_csv_det(res$diagnostics, o$out); say("\nDiagnostics      : %s", o$out) }
  if (!is.null(o$records)) { write_csv_det(res$records, o$records); say("Records          : %s", o$records) }
  if (!is.null(report)) {
    write_validation_report(report, res, paste("defxbridge validate", paste(args, collapse = " ")))
    say("Report           : %s", report)
  }
  failed <- any(res$diagnostics$severity == "error")
  say("\nValidation %s: %s", if (failed) "FAILED" else "PASSED", summary_line(res$diagnostics))
  if (failed) 2L else 0L
}

cmd_export <- function(args) {
  o <- parse_cli_args(args, "export", c("source", "spec", "template", "out", "meta", "report"),
                      c("keep-unmatched", "no-recursive"))
  if (isTRUE(o$help)) { emit(HELP$export); return(0L) }
  if (length(o$positional)) usage_error(sprintf("unexpected argument '%s'", o$positional[1]), "export")
  for (k in c("source", "spec", "template", "out"))
    if (is.null(o[[k]])) usage_error(sprintf("--%s is required", k), "export")
  if (!grepl("\\.xlsx$", o$out, ignore.case = TRUE)) usage_error("--out must end in .xlsx", "export")
  if (identical(normalizePath(o$template, mustWork = FALSE), normalizePath(o$out, mustWork = FALSE)))
    usage_error("--out must be a different file from --template (the template is never overwritten)", "export")
  res <- run_pipeline(o$source, o$spec, recursive = !isTRUE(o[["no-recursive"]]))
  tpl_check <- load_template(o$template)   # fail early on a bad template
  rm(tpl_check)
  say("DEFX Bridge export")
  header_block(res)
  report <- o$report %||% paste0(stem(o$out), "_report.md")
  meta <- o$meta %||% paste0(stem(o$out), "_meta.csv")
  cmdline <- paste("defxbridge export", paste(args, collapse = " "))
  if (any(res$diagnostics$severity == "error")) {
    emit(""); print_diags(res$diagnostics)
    write_validation_report(report, res, cmdline)
    say("\nExport REFUSED: validation found %s. No workbook was written.", summary_line(res$diagnostics))
    if (file.exists(o$out)) say("NOTE: an older file already exists at %s and was NOT updated.", o$out)
    say("Report: %s", report)
    return(2L)
  }
  ex <- export_defx_workbook(res$records, o$template, o$out,
                             keep_unmatched = isTRUE(o[["keep-unmatched"]]))
  res$diagnostics <- sort_diags(bind_diags(res$diagnostics, ex$diagnostics))
  if (nrow(res$diagnostics)) { emit(""); print_diags(res$diagnostics) }
  checks_md <- if (!is.null(ex$checks))
    c("## Workbook preservation checks", "", "| Check | Result | Detail |", "|---|---|---|",
      sprintf("| %s | %s | %s |", ex$checks$check, ex$checks$result, ex$checks$detail))
  write_validation_report(report, res, cmdline, extra = checks_md)
  if (is.null(ex$out)) {
    if (!is.null(ex$checks)) { emit("\nPreservation checks:"); print_table(ex$checks, c(check = 48, result = 6, detail = 50), flex = "detail") }
    say("\nExport REFUSED: %s. No workbook was written.",
        if (any(ex$diagnostics$severity == "error")) "template does not contain every tagged target"
        else "preservation verification failed")
    say("Report: %s", report)
    return(2L)
  }
  write_csv_det(res$records, meta)
  emit("\nPreservation checks (template vs output, re-read from disk):")
  print_table(ex$checks, c(check = 48, result = 6, detail = 50), flex = "detail")
  say("\nWorkbook         : %s", o$out)
  say("  Methods rows %d, Comments rows %d, Variables rows updated %d, Datasets rows updated %d",
      ex$counts[["methods"]], ex$counts[["comments"]], ex$counts[["variables_updated"]],
      ex$counts[["datasets_updated"]])
  say("Traceability CSV : %s", meta)
  say("Report           : %s", report)
  say("\nExport OK: %s", summary_line(res$diagnostics))
  0L
}

cmd_compare <- function(args) {
  o <- parse_cli_args(args, "compare", character(), character())
  if (isTRUE(o$help)) { emit(HELP$compare); return(0L) }
  if (length(o$positional) != 2) usage_error("compare needs exactly two .xlsx files", "compare")
  for (p in o$positional) if (!file.exists(p)) usage_error(sprintf("file not found: %s", p), "compare")
  same <- workbooks_equivalent(o$positional[1], o$positional[2])
  say("%s: %s vs %s", if (same) "EQUIVALENT" else "DIFFERENT", o$positional[1], o$positional[2])
  if (same) 0L else 2L
}

`%||%` <- function(a, b) if (is.null(a)) b else a

#' CLI entry point. Returns an integer exit status; never throws.
defxbridge_main <- function(args = commandArgs(trailingOnly = TRUE)) {
  run <- function() {
    if (!length(args) || args[1] %in% c("-h", "--help", "help")) {
      emit(HELP$main); return(if (length(args)) 0L else 1L)
    }
    if (args[1] %in% c("--version", "-V")) { emit(paste("defxbridge", DEFX_VERSION)); return(0L) }
    cmd <- args[1]; rest <- args[-1]
    switch(cmd,
           scan = cmd_scan(rest), validate = cmd_validate(rest),
           export = cmd_export(rest), compare = cmd_compare(rest),
           usage_error(sprintf("unknown command '%s'", cmd)))
  }
  status <- tryCatch(
    withCallingHandlers(run(), warning = function(w) {
      message("defxbridge: warning: ", conditionMessage(w))
      invokeRestart("muffleWarning")
    }),
    defx_input_error = function(e) { message("defxbridge: error: ", conditionMessage(e)); 1L },
    error = function(e) { message("defxbridge: runtime error: ", conditionMessage(e)); 1L })
  as.integer(status)
}
