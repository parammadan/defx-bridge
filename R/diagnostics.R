# Diagnostics -----------------------------------------------------------------
#
# Every finding is one row: code, severity, source_file, source_line, name,
# message, suggestion, related (other locations, "file:line; file:line").

DIAG_COLS <- c("code", "severity", "source_file", "source_line", "name",
               "message", "suggestion", "related")

DIAG_TITLES <- c(
  V001 = "Malformed DEFX tag",
  V002 = "Unknown target (not in specification)",
  V003 = "Conflicting cross-program definition",
  V004 = "Unsupported or invalid tag type",
  V005 = "Invalid predecessor reference",
  V006 = "Conflicting origins or types",
  V007 = "Missing or invalid metadata specification",
  V008 = "Source file could not be read or lexed",
  V009 = "Target missing from workbook template",
  V010 = "DEFX-like comment without '|' delimiter (ignored)",
  V011 = "Predecessor outside validation scope (not verified)",
  V012 = "DEFX tag in unsupported SAS comment form (ignored)",
  V013 = "Dangling workbook reference",
  V014 = "No DEFX tags found"
)

new_diag <- function(code, severity, source_file = "", source_line = NA_integer_,
                     name = "", message, suggestion = "", related = "") {
  stopifnot(severity %in% c("error", "warning", "info"))
  data.frame(code = code, severity = severity, source_file = source_file,
             source_line = as.integer(source_line), name = name,
             message = message, suggestion = suggestion, related = related,
             stringsAsFactors = FALSE)
}

empty_diags <- function() {
  d <- new_diag("V000", "info", message = "x")
  d[0, , drop = FALSE]
}

bind_diags <- function(...) {
  parts <- Filter(function(x) !is.null(x) && nrow(x) > 0, list(...))
  if (!length(parts)) return(empty_diags())
  do.call(rbind, parts)
}

#' Deterministic ordering: file, line, code, name.
sort_diags <- function(d) {
  if (!nrow(d)) return(d)
  sev <- match(d$severity, c("error", "warning", "info"))
  ln <- ifelse(is.na(d$source_line), .Machine$integer.max, d$source_line)
  d <- d[order(d$source_file, ln, d$code, d$name, sev, d$message,
               method = "radix"), , drop = FALSE]
  d <- d[!duplicated(d), , drop = FALSE]
  rownames(d) <- NULL
  d
}

diag_counts <- function(d) {
  c(error = sum(d$severity == "error"), warning = sum(d$severity == "warning"),
    info = sum(d$severity == "info"))
}
