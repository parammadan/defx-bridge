# Source discovery ------------------------------------------------------------

defx_input_error <- function(msg, code = NA_character_) {
  structure(class = c("defx_input_error", "error", "condition"),
            list(message = msg, call = NULL, code = code))
}

#' Language for a file path, or NA if not a supported source file.
source_language <- function(path) {
  ext <- tolower(tools::file_ext(path))
  if (ext == "sas") "SAS" else if (ext == "r") "R" else NA_character_
}

#' Discover SAS (.sas) and R (.R/.r) programs.
#'
#' @param sources Character vector of directories and/or files.
#' @param recursive Search sub-directories (hidden directories are skipped).
#' @return data.frame with `path` (absolute), `source_file` (relative label)
#'   and `language`, sorted deterministically by `source_file` (C-locale radix).
discover_sources <- function(sources, recursive = TRUE) {
  if (length(sources) == 0 || all(!nzchar(sources)))
    stop(defx_input_error("no --source given"))
  roots <- normalizePath(sources, mustWork = FALSE)
  missing <- sources[!file.exists(roots)]
  if (length(missing))
    stop(defx_input_error(sprintf("source path does not exist: %s",
                                  paste(missing, collapse = ", "))))
  multi <- length(roots) > 1
  if (multi) {
    bn <- basename(roots)
    if (anyDuplicated(bn))
      stop(defx_input_error(paste0(
        "multiple --source paths share the same base name; ",
        "rename one so provenance labels stay unambiguous")))
  }
  out <- list()
  for (root in roots) {
    if (dir.exists(root)) {
      rel <- list.files(root, recursive = recursive, all.files = FALSE,
                        include.dirs = FALSE, no.. = TRUE)
      # skip anything inside hidden directories
      rel <- rel[!grepl("(^|/)\\.", rel)]
      abs <- file.path(root, rel)
      prefix <- if (multi) paste0(basename(root), "/") else ""
      lab <- paste0(prefix, rel)
    } else {
      abs <- root
      lab <- basename(root)
    }
    lang <- vapply(abs, source_language, character(1), USE.NAMES = FALSE)
    keep <- !is.na(lang) & !dir.exists(abs)
    out[[length(out) + 1]] <- data.frame(path = abs[keep], source_file = lab[keep],
                                         language = lang[keep],
                                         stringsAsFactors = FALSE)
  }
  res <- do.call(rbind, out)
  if (is.null(res) || nrow(res) == 0)
    stop(defx_input_error(sprintf(
      "no .sas, .R or .r programs found in: %s", paste(sources, collapse = ", "))))
  if (anyDuplicated(res$path)) res <- res[!duplicated(res$path), , drop = FALSE]
  res <- res[order(res$source_file, method = "radix"), , drop = FALSE]
  rownames(res) <- NULL
  res
}
