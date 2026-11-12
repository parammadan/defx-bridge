# Specification + validation ----------------------------------------------------

#' Load the metadata specification CSV (columns Dataset, Variable; others kept).
#'
#' Fails with a defx_input_error (code V007) when the file is missing,
#' unreadable, lacks the required columns, is empty, or has blank/invalid
#' identifiers.
load_spec <- function(path) {
  v007 <- function(msg) stop(defx_input_error(paste("V007", msg), code = "V007"))
  if (is.null(path) || !nzchar(path)) v007("no --spec file given")
  if (!file.exists(path) || dir.exists(path)) v007(sprintf("specification not found: %s", path))
  spec <- tryCatch(utils::read.csv(path, colClasses = "character", check.names = FALSE,
                                   na.strings = character(0), strip.white = TRUE,
                                   encoding = "UTF-8"),
                   error = function(e) v007(sprintf("cannot read specification %s: %s",
                                                    path, conditionMessage(e))))
  names(spec) <- sub("^\ufeff", "", names(spec))
  nm <- tolower(trimws(names(spec)))
  need <- c("dataset", "variable")
  if (!all(need %in% nm))
    v007(sprintf("specification %s must have columns Dataset and Variable (found: %s)",
                 path, paste(names(spec), collapse = ", ")))
  names(spec)[match(need, nm)] <- c("Dataset", "Variable")
  if (!nrow(spec)) v007(sprintf("specification %s has no rows", path))
  spec$Dataset <- toupper(trimws(spec$Dataset))
  spec$Variable <- toupper(trimws(spec$Variable))
  bad <- which(!grepl("^[A-Z_][A-Z0-9_]*$", spec$Dataset) |
               !grepl("^[A-Z_][A-Z0-9_]*$", spec$Variable))
  if (length(bad))
    v007(sprintf("specification %s has blank or invalid Dataset/Variable on data row(s) %s",
                 path, paste(head(bad, 10), collapse = ", ")))
  spec <- spec[!duplicated(spec[, c("Dataset", "Variable")]), , drop = FALSE]
  rownames(spec) <- NULL
  spec
}

loc <- function(r) sprintf("%s:%s", r$source_file, r$source_line)

#' Validate normalized records against a specification.
#'
#' @param records normalize_defx_metadata() output (scope resolved with spec).
#' @param spec load_spec() output.
#' @return Diagnostics data.frame (see DIAG_COLS). Does not include parse
#'   diagnostics; combine with extract_all()$diagnostics.
validate_defx_metadata <- function(records, spec) {
  d <- list()
  add <- function(...) d[[length(d) + 1L]] <<- new_diag(...)
  ok <- records[records$status == "ok", , drop = FALSE]
  if (!nrow(ok)) return(empty_diags())

  spec_key <- paste(spec$Dataset, spec$Variable, sep = ".")
  spec_ds <- unique(spec$Dataset)

  for (k in seq_len(nrow(ok))) {
    r <- ok[k, ]
    # --- V004: type not allowed for this scope
    if (r$scope == "dataset" && r$type != "Comments") {
      add("V004", "error", r$source_file, r$source_line, r$name,
          sprintf("'%s' is a dataset; dataset-level tags support only Comments (got %s)",
                  r$name, r$type),
          sprintf("use DEFX | %s | Comments | <Description>, or name a variable", r$name))
      next
    }
    # --- V002: unknown target
    if (r$scope == "dataset_variable" && !paste(r$dataset, r$variable, sep = ".") %in% spec_key) {
      add("V002", "error", r$source_file, r$source_line, r$name,
          sprintf("%s is not in the specification", r$name),
          if (r$dataset %in% spec_ds) sprintf("check the variable name; %s is a known dataset", r$dataset)
          else sprintf("dataset %s is not in the specification", r$dataset))
    }
    if (r$scope == "variable_all" && !r$variable %in% spec$Variable) {
      add("V002", "error", r$source_file, r$source_line, r$name,
          sprintf("single-name tag '%s' matches neither a dataset nor a variable in the specification",
                  r$name),
          "use <Dataset>.<Variable>, or add the variable to the specification")
    }
    if (r$scope == "parameter") {
      target <- paste(r$dataset, r$variable, sep = ".")
      if (!target %in% spec_key)
        add("V002", "error", r$source_file, r$source_line, r$name,
            sprintf("parameter-level method '%s' refers to %s, which is not in the specification",
                    r$name, target), "check the dataset and variable parts of the name")
    }
    # --- V005 / V011: predecessor reference
    if (r$type == "Predecessor") {
      p <- toupper(trimws(r$predecessor))
      if (!grepl("^[A-Z_][A-Z0-9_]*\\.[A-Z_][A-Z0-9_]*$", p)) {
        add("V005", "error", r$source_file, r$source_line, r$name,
            sprintf("predecessor '%s' is not a single <Dataset>.<Variable> reference", r$predecessor),
            if (grepl("[[:space:]]", p)) "a Predecessor tag takes exactly one reference on one line"
            else "write the predecessor as <Dataset>.<Variable>, e.g. AE.AETERM")
      } else if (p == r$name) {
        add("V005", "error", r$source_file, r$source_line, r$name,
            sprintf("%s lists itself as its predecessor", r$name), "name the source variable")
      } else {
        pds <- sub("\\..*$", "", p)
        if (pds %in% spec_ds) {
          if (!p %in% spec_key)
            add("V005", "error", r$source_file, r$source_line, r$name,
                sprintf("predecessor %s not found: %s is in the specification but %s is not",
                        p, pds, p),
                "check the predecessor variable name")
        } else {
          add("V011", "info", r$source_file, r$source_line, r$name,
              sprintf("predecessor %s: dataset %s is outside the specification, so the reference was checked for structure only",
                      p, pds),
              sprintf("add %s variables to the specification to verify them", pds))
        }
      }
    }
  }

  # --- V003: same target defined in more than one program
  kind <- ifelse(ok$type == "Comments", "comment", "origin")
  grp <- split(seq_len(nrow(ok)), paste(ok$name, kind, sep = "\r"))
  for (g in grp) {
    files <- unique(ok$source_file[g])
    if (length(files) < 2) next
    for (k in g) {
      others <- g[ok$source_file[g] != ok$source_file[k]]
      add("V003", "error", ok$source_file[k], ok$source_line[k], ok$name[k],
          sprintf("%s %s appears in %d programs (%s); a target must be documented by one program",
                  ok$name[k], if (kind[k] == "comment") "comment" else "definition",
                  length(files), paste(files, collapse = ", ")),
          "keep the tag in the program that creates the variable and remove the others",
          related = paste(loc(ok[others, ]), collapse = "; "))
    }
  }

  # --- V006 (a): one program gives conflicting origin types for one target
  o <- which(kind == "origin")
  grp <- split(o, paste(ok$source_file[o], ok$name[o], sep = "\r"))
  for (g in grp) {
    if (length(unique(ok$type[g])) < 2) next
    for (k in g) {
      others <- setdiff(g, k)
      add("V006", "error", ok$source_file[k], ok$source_line[k], ok$name[k],
          sprintf("%s is declared as %s in the same program",
                  ok$name[k], paste(sort(unique(ok$type[g])), collapse = " and ")),
          "a target has one origin; if these are continuation lines, repeat the same type on every line",
          related = paste(loc(ok[others, ]), collapse = "; "))
    }
  }

  # --- V006 (b): variable-only tag overlaps a dataset-specific tag
  for (kd in c("origin", "comment")) {
    va <- which(ok$scope == "variable_all" & kind == kd)
    dv <- which(ok$scope == "dataset_variable" & kind == kd)
    for (k in va) {
      clash <- dv[ok$variable[dv] == ok$variable[k]]
      if (!length(clash)) next
      for (j in c(k, clash)) {
        others <- setdiff(c(k, clash), j)
        add("V006", "error", ok$source_file[j], ok$source_line[j], ok$name[j],
            sprintf("variable-only tag %s and dataset-specific tag(s) %s both set the %s of the same Variables row(s)",
                    ok$name[k], paste(unique(ok$name[clash]), collapse = ", "),
                    if (kd == "origin") "origin/method" else "comment"),
            "keep either the variable-only tag or the dataset-specific tag(s), not both",
            related = paste(loc(ok[others, ]), collapse = "; "))
      }
    }
  }

  sort_diags(do.call(bind_diags, d))
}

#' Mark each record's status from the diagnostics that point at it.
apply_status <- function(records, diags) {
  if (!nrow(records)) return(records)
  for (k in seq_len(nrow(records))) {
    lines <- as.integer(strsplit(records$source_lines[k], ";", fixed = TRUE)[[1]])
    hit <- diags$source_file == records$source_file[k] &
      diags$source_line %in% lines &
      (diags$name == records$name[k] | !nzchar(diags$name))
    sev <- diags$severity[hit]
    records$status[k] <- if ("error" %in% sev) "error" else if ("warning" %in% sev)
      "warning" else if (records$status[k] == "malformed") "error" else "ok"
  }
  records
}

#' Full pipeline up to validation: discover -> extract -> normalize -> validate.
#'
#' @return list(sources, segments, records, diagnostics, spec)
run_pipeline <- function(sources, spec_path = NULL, recursive = TRUE) {
  spec <- if (!is.null(spec_path)) load_spec(spec_path) else NULL
  src <- discover_sources(sources, recursive = recursive)
  ex <- extract_all(src)
  rec <- normalize_defx_metadata(ex$segments, spec)
  diags <- ex$diagnostics
  if (!nrow(ex$segments))
    diags <- bind_diags(diags, new_diag("V014", "warning", message = sprintf(
      "no DEFX tags found in %d program(s)", nrow(src)),
      suggestion = "tags look like: /* DEFX | ADAE.AERELFL | <Description> */ or # DEFX | ..."))
  if (!is.null(spec)) diags <- bind_diags(diags, validate_defx_metadata(rec, spec))
  diags <- sort_diags(diags)
  rec <- apply_status(rec, diags)
  list(sources = src, segments = ex$segments, records = rec, diagnostics = diags,
       spec = spec)
}
