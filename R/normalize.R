# Normalization / consolidation -------------------------------------------------
#
# Segments are individual tag lines. A *record* is one documented definition:
# all segments that share (source_file, name, type) are consolidated, in
# original source order, into one record. This is how the published pattern
#
#   /* DEFX | ADAE.AERELFL | Y if related */
#   /* DEFX | ADAE.AERELFL | N if not related */
#
# becomes ONE computation method instead of two conflicting ones. Every
# contributing line number is kept in `source_lines`, and every contributing
# raw comment in `raw_tag` (newline-separated), so no provenance is lost.

RECORD_COLS <- c("record_id", "source_file", "source_line", "source_lines",
                 "segment_count", "language", "raw_tag", "name", "scope",
                 "dataset", "variable", "parameter", "type", "origin",
                 "predecessor", "description", "status")

origin_for_type <- function(type) {
  out <- rep("", length(type))
  out[type %in% c("Computation", "Imputation")] <- "Derived"
  out[type == "Predecessor"] <- "Predecessor"
  out[type == "Assigned"] <- "Assigned"
  out
}

#' Consolidate segments into normalized metadata records.
#'
#' @param segments Output of extract_all()$segments.
#' @param spec Optional specification (load_spec()); used only to decide
#'   whether a single-name tag (no '.') names a dataset or a variable.
normalize_defx_metadata <- function(segments, spec = NULL) {
  if (!nrow(segments)) {
    r <- as.data.frame(setNames(replicate(length(RECORD_COLS), character(),
                                          simplify = FALSE), RECORD_COLS),
                       stringsAsFactors = FALSE)
    r$source_line <- integer(); r$segment_count <- integer()
    return(r)
  }
  # source order: files are already sorted; within file by line then column
  segments <- segments[order(segments$source_file, segments$source_line,
                             segments$source_col, method = "radix"), , drop = FALSE]
  ok <- segments$parse_status == "ok"
  key <- ifelse(ok, paste(segments$source_file, segments$name, segments$type, sep = "\r"),
                paste(segments$source_file, segments$source_line, segments$source_col,
                      "malformed", sep = "\r"))
  groups <- split(seq_len(nrow(segments)), factor(key, levels = unique(key)))
  recs <- lapply(groups, function(idx) {
    s <- segments[idx, , drop = FALSE]
    type <- s$type[1]
    joined <- paste(s$description[nzchar(s$description)], collapse = " ")
    is_pred <- type == "Predecessor"
    data.frame(
      record_id = "",
      source_file = s$source_file[1],
      source_line = s$source_line[1],
      source_lines = paste(unique(s$source_line), collapse = ";"),
      segment_count = nrow(s),
      language = s$language[1],
      raw_tag = paste(s$raw_tag, collapse = "\n"),
      name = s$name[1],
      scope = s$name_form[1],
      dataset = s$dataset[1], variable = s$variable[1], parameter = s$parameter[1],
      type = type,
      origin = origin_for_type(type),
      predecessor = if (is_pred) joined else "",
      description = if (is_pred) "" else joined,
      status = if (s$parse_status[1] == "ok") "ok" else "malformed",
      stringsAsFactors = FALSE)
  })
  r <- do.call(rbind, recs)
  rownames(r) <- NULL
  r <- resolve_scope(r, spec)
  r$record_id <- sprintf("R%04d", seq_len(nrow(r)))
  r[, RECORD_COLS]
}

#' Resolve single-name tags to dataset or variable scope.
#'
#' Scopes: dataset_variable, dataset (dataset-level comment), variable_all
#' (a variable in every dataset that has it), parameter (Methods-only
#' AVAL/PARAMCD-style method), or dataset_or_variable when no specification
#' is available to decide.
resolve_scope <- function(records, spec = NULL) {
  single <- records$scope == "single"
  if (!any(single)) return(records)
  if (is.null(spec)) {
    records$scope[single] <- "dataset_or_variable"
    return(records)
  }
  is_ds <- single & records$name %in% unique(spec$Dataset)
  records$scope[is_ds] <- "dataset"
  records$dataset[is_ds] <- records$name[is_ds]
  is_var <- single & !is_ds
  records$scope[is_var] <- "variable_all"
  records$variable[is_var] <- records$name[is_var]
  records
}
