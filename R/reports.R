# Reports and console output ----------------------------------------------------

# Console output: a closed stdout (e.g. `defxbridge scan ... | head`) is the reader's
# choice, not a failure. Output files are written independently of the console.
emit <- function(x, con = stdout()) {
  tryCatch(writeLines(x, con), error = function(e) {
    if (grepl("SIGPIPE|broken pipe|error writing to connection", conditionMessage(e), ignore.case = TRUE)) invisible(NULL)
    else stop(e)
  })
}

#' Usable console width (DEFX_COLUMNS, set by bin/defxbridge from the terminal), or NA.
console_width <- function() {
  w <- suppressWarnings(as.integer(Sys.getenv("DEFX_COLUMNS", "")))
  if (is.na(w) || w < 40) NA_integer_ else w
}

write_csv_det <- function(df, path) {
  dir.create(dirname(normalizePath(path, mustWork = FALSE)), recursive = TRUE,
             showWarnings = FALSE)
  tmp <- paste0(path, ".tmp")
  utils::write.csv(df, tmp, row.names = FALSE, na = "", fileEncoding = "UTF-8")
  if (!file.rename(tmp, path)) { file.copy(tmp, path, overwrite = TRUE); unlink(tmp) }
  invisible(path)
}

clip <- function(x, n) {
  x <- gsub("[\r\n]+", " ", ifelse(is.na(x), "", as.character(x)))
  ifelse(nchar(x) > n, paste0(substr(x, 1, n - 1), "\u2026"), x)
}

#' Print a compact fixed-width table.
print_table <- function(df, widths, con = stdout(), flex = NULL) {
  if (!nrow(df)) return(invisible())
  cols <- names(widths)
  avail <- console_width()
  if (!is.null(flex) && !is.na(avail)) {        # shrink the free-text column to fit
    used <- sum(pmin(unlist(widths), vapply(cols, function(c)
      max(nchar(c), nchar(as.character(df[[c]])), 0L), 1L))) + 2L * length(cols)
    if (used > avail) widths[[flex]] <- max(12L, widths[[flex]] - (used - avail))
  }
  cells <- lapply(cols, function(c) clip(df[[c]], widths[[c]]))
  w <- vapply(seq_along(cols), function(i) max(nchar(cols[i]), nchar(cells[[i]]), 0L), 1L)
  fmt <- function(v) paste(paste0(v, strrep(" ", pmax(0L, w - nchar(v)))), collapse = "  ")
  emit(paste0("  ", fmt(cols)), con)
  emit(paste0("  ", paste(strrep("-", w), collapse = "  ")), con)
  for (r in seq_len(nrow(df)))
    emit(paste0("  ", fmt(vapply(cells, `[`, "", r))), con)
}

print_records <- function(rec) {
  if (!nrow(rec)) return(invisible())
  view <- data.frame(where = sprintf("%s:%s", rec$source_file, rec$source_lines),
                     lang = rec$language, name = rec$name, type = rec$type,
                     origin = rec$origin,
                     text = ifelse(nzchar(rec$predecessor), rec$predecessor, rec$description),
                     status = rec$status, stringsAsFactors = FALSE)
  print_table(view, c(where = 30, lang = 4, name = 26, type = 11, origin = 11,
                      text = 44, status = 9), flex = "text")
}

print_diags <- function(d, con = stdout()) {
  if (!nrow(d)) return(invisible())
  for (i in seq_len(nrow(d))) {
    x <- d[i, ]
    where <- if (nzchar(x$source_file)) sprintf("%s:%s", x$source_file,
                                               ifelse(is.na(x$source_line), "-", x$source_line)) else "-"
    emit(sprintf("  [%s %s] %s  %s", toupper(x$severity), x$code, where, x$message), con)
    if (nzchar(x$related)) emit(sprintf("      also at: %s", x$related), con)
    if (nzchar(x$suggestion)) emit(sprintf("      fix: %s", x$suggestion), con)
  }
}

summary_line <- function(d) {
  n <- diag_counts(d)
  sprintf("%d error(s), %d warning(s), %d info", n[["error"]], n[["warning"]], n[["info"]])
}

#' Write a human-readable Markdown validation report.
write_validation_report <- function(path, result, command = "validate", extra = NULL) {
  rec <- result$records; d <- result$diagnostics; src <- result$sources
  langs <- table(factor(src$language, levels = c("SAS", "R")))
  rl <- table(factor(rec$language, levels = c("SAS", "R")))
  L <- c(
    "# DEFX Bridge validation report", "",
    "_Synthetic, independent prototype output. Not a CDISC/Pinnacle 21 conformance result._", "",
    sprintf("- Command: `%s`", command),
    sprintf("- Programs scanned: %d (SAS %d, R %d)", nrow(src), langs[["SAS"]], langs[["R"]]),
    sprintf("- Tag lines (segments): %d", nrow(result$segments)),
    sprintf("- Consolidated records: %d (SAS %d, R %d)", nrow(rec), rl[["SAS"]], rl[["R"]]),
    sprintf("- Specification: %s", if (is.null(result$spec)) "none (syntax checks only)"
            else sprintf("%d dataset-variable rows, datasets %s", nrow(result$spec),
                         paste(unique(result$spec$Dataset), collapse = ", "))),
    sprintf("- Result: **%s** - %s", if (any(d$severity == "error")) "FAILED" else "PASSED",
            summary_line(d)), "")
  if (length(extra)) L <- c(L, extra, "")
  L <- c(L, "## Diagnostics", "")
  if (!nrow(d)) L <- c(L, "None.", "") else {
    L <- c(L, "| Code | Severity | Location | Name | Message | Suggested fix |",
           "|---|---|---|---|---|---|")
    esc <- function(x) gsub("|", "\\|", x, fixed = TRUE)
    for (i in seq_len(nrow(d))) {
      x <- d[i, ]
      where <- if (nzchar(x$source_file)) sprintf("%s:%s", x$source_file,
                                                 ifelse(is.na(x$source_line), "-", x$source_line)) else "-"
      if (nzchar(x$related)) where <- paste0(where, " (also ", x$related, ")")
      L <- c(L, sprintf("| %s | %s | %s | %s | %s | %s |", x$code, x$severity, esc(where),
                        esc(x$name), esc(x$message), esc(x$suggestion)))
    }
    L <- c(L, "")
  }
  L <- c(L, "## Records", "", "| Record | Location (lines) | Lang | Name | Scope | Type | Origin | Predecessor / Description | Status |",
         "|---|---|---|---|---|---|---|---|---|")
  esc <- function(x) gsub("|", "\\|", gsub("\n", " ", x), fixed = TRUE)
  for (i in seq_len(nrow(rec))) {
    r <- rec[i, ]
    L <- c(L, sprintf("| %s | %s:%s | %s | %s | %s | %s | %s | %s | %s |", r$record_id,
                      r$source_file, r$source_lines, r$language, r$name, r$scope, r$type,
                      r$origin, esc(if (nzchar(r$predecessor)) r$predecessor else r$description),
                      r$status))
  }
  dir.create(dirname(normalizePath(path, mustWork = FALSE)), recursive = TRUE, showWarnings = FALSE)
  writeLines(L, path, useBytes = TRUE)
  invisible(path)
}
