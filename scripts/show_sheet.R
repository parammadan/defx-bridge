#!/usr/bin/env Rscript
# Print cells of one worksheet, read straight from an .xlsx file with readxl.
# Used in the demo to show the generated workbook in a terminal.
#
#   scripts/show_sheet.R <file.xlsx> <sheet> [--cols A,B,C] [--where Col=Value]
#                                [--max N] [--width W]
local({
  a <- commandArgs(trailingOnly = TRUE)
  if (length(a) < 2) {
    message("usage: scripts/show_sheet.R <file.xlsx> <sheet> [--cols A,B] [--where Col=Value] [--max N] [--width W]")
    quit(status = 1)
  }
  opt <- function(k, d = NULL) { i <- match(k, a); if (is.na(i)) d else a[i + 1] }
  path <- a[1]; sheet <- a[2]
  if (!requireNamespace("readxl", quietly = TRUE)) { message("needs the readxl package"); quit(status = 1) }
  x <- as.data.frame(readxl::read_excel(path, sheet = sheet, col_types = "text"), check.names = FALSE)
  total <- nrow(x)
  w <- opt("--where")
  if (!is.null(w)) {
    kv <- strsplit(w, "=", fixed = TRUE)[[1]]
    x <- x[!is.na(x[[kv[1]]]) & x[[kv[1]]] == kv[2], , drop = FALSE]
  }
  cols <- opt("--cols"); if (!is.null(cols)) x <- x[, strsplit(cols, ",", fixed = TRUE)[[1]], drop = FALSE]
  n <- as.integer(opt("--max", nrow(x))); shown <- head(x, n)
  width <- as.integer(opt("--width", 40))
  cell <- function(v) { v[is.na(v)] <- "."; ifelse(nchar(v) > width, paste0(substr(v, 1, width - 1), "~"), v) }
  m <- rbind(names(shown), as.matrix(as.data.frame(lapply(shown, cell), check.names = FALSE)))
  wd <- apply(m, 2, function(col) max(nchar(col)))
  cat(sprintf("%s  [sheet: %s]  %d of %d rows%s\n", path, sheet, nrow(shown), total,
              if (!is.null(w)) sprintf(" where %s", w) else ""))
  for (r in seq_len(nrow(m))) {
    cat(" ", paste0(m[r, ], strrep(" ", pmax(0L, wd - nchar(m[r, ]))), collapse = "  "), "\n", sep = "")
    if (r == 1) cat(" ", paste(strrep("-", wd), collapse = "  "), "\n", sep = "")
  }
})
