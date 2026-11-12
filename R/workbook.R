# Define-like workbook export ---------------------------------------------------
#
# Only four sheets are touched (Datasets, Variables, Methods, Comments), and in
# Datasets/Variables only the tag-owned columns of targeted rows change. Every
# other sheet, column and cell is left as loaded. The output is written to a
# temporary file in the destination directory, re-opened and checked against
# the template, and only then renamed into place.

DEFX_SHEETS <- c("Datasets", "Variables", "Methods", "Comments")
REQUIRED_COLS <- list(
  Datasets  = c("Dataset", "Comment"),
  Variables = c("Dataset", "Variable", "Origin", "Predecessor", "Method", "Comment"),
  Methods   = c("ID", "Name", "Type", "Description"),
  Comments  = c("ID", "Description")
)
OWNED_COLS <- list(Datasets = "Comment",
                   Variables = c("Origin", "Predecessor", "Method", "Comment"))

read_sheet <- function(wb, sheet) {
  df <- openxlsx::readWorkbook(wb, sheet = sheet, colNames = TRUE, sep.names = " ",
                               skipEmptyRows = FALSE, skipEmptyCols = FALSE,
                               detectDates = FALSE, check.names = FALSE)
  if (is.null(df)) df <- data.frame()
  df
}

up <- function(x) toupper(trimws(ifelse(is.na(x), "", as.character(x))))

#' Load and check a define-like template.
load_template <- function(path) {
  if (!file.exists(path))
    stop(defx_input_error(sprintf("template not found: %s", path)))
  wb <- tryCatch(openxlsx::loadWorkbook(path),
                 error = function(e) stop(defx_input_error(sprintf(
                   "cannot open template %s as .xlsx: %s", path, conditionMessage(e)))))
  sheets <- names(wb)
  miss <- setdiff(DEFX_SHEETS, sheets)
  if (length(miss))
    stop(defx_input_error(sprintf("template %s is missing sheet(s): %s", path,
                                  paste(miss, collapse = ", "))))
  data <- lapply(setNames(DEFX_SHEETS, DEFX_SHEETS), function(s) read_sheet(wb, s))
  for (s in DEFX_SHEETS) {
    mc <- setdiff(REQUIRED_COLS[[s]], names(data[[s]]))
    if (length(mc))
      stop(defx_input_error(sprintf("template sheet '%s' is missing column(s): %s", s,
                                    paste(mc, collapse = ", "))))
  }
  list(wb = wb, data = data, sheets = sheets)
}

set_col <- function(df, col, rows, value) {
  if (!length(rows)) return(df)
  if (!is.character(df[[col]])) df[[col]] <- ifelse(is.na(df[[col]]), NA_character_,
                                                    as.character(df[[col]]))
  df[[col]][rows] <- value
  df
}

#' Compute the new contents of the four DEFX sheets.
#'
#' @param records Validated records (no error status).
#' @param data Template sheet data (load_template()$data).
#' @param keep_unmatched KEEPTAGS-style switch: if TRUE, Methods/Comments rows in
#'   the template that no tag matches are retained; if FALSE (default) they are
#'   dropped, so those sheets reflect current tags only.
#' @return list(data = new sheet data, diagnostics, touched = list of targeted rows)
build_workbook_data <- function(records, data, keep_unmatched = FALSE) {
  d <- list()
  add <- function(...) d[[length(d) + 1L]] <<- new_diag(...)
  rec <- records[records$status %in% c("ok", "warning"), , drop = FALSE]
  ds <- data$Datasets; vars <- data$Variables
  vkey <- paste(up(vars$Dataset), up(vars$Variable), sep = ".")
  touched_vars <- integer(); touched_ds <- integer()

  rows_for <- function(r) {
    if (r$scope == "dataset_variable") which(vkey == r$name)
    else if (r$scope == "variable_all") which(up(vars$Variable) == r$variable)
    else integer()
  }

  for (k in seq_len(nrow(rec))) {
    r <- rec[k, ]
    if (r$scope == "parameter") next                       # Methods only
    if (r$scope == "dataset") {
      i <- which(up(ds$Dataset) == r$dataset)
      if (!length(i)) {
        add("V009", "error", r$source_file, r$source_line, r$name,
            sprintf("dataset %s is not on the template's Datasets sheet", r$dataset),
            "add the dataset to the template or remove the tag")
        next
      }
      ds <- set_col(ds, "Comment", i, r$name); touched_ds <- c(touched_ds, i)
      next
    }
    i <- rows_for(r)
    if (!length(i)) {
      add("V009", "error", r$source_file, r$source_line, r$name,
          sprintf("%s has no row on the template's Variables sheet", r$name),
          "add the variable to the template or remove the tag")
      next
    }
    touched_vars <- c(touched_vars, i)
    if (r$type == "Comments") {
      vars <- set_col(vars, "Comment", i, r$name)
    } else {
      vars <- set_col(vars, "Origin", i, r$origin)
      vars <- set_col(vars, "Method", i, if (r$origin == "Derived") r$name else NA_character_)
      vars <- set_col(vars, "Predecessor", i,
                      if (r$type == "Predecessor") toupper(trimws(r$predecessor)) else NA_character_)
    }
  }

  merge_id_sheet <- function(old, new_ids, fill) {
    old_id <- up(old$ID)
    rows <- list()
    for (j in seq_along(new_ids)) {
      m <- which(old_id == new_ids[j])
      row <- if (length(m)) old[m[1], , drop = FALSE] else {
        x <- old[0, , drop = FALSE]; x[1, ] <- NA; x
      }
      for (col in names(fill)) {
        if (!is.character(row[[col]])) row[[col]] <- as.character(row[[col]])
        row[[col]] <- fill[[col]][j]
      }
      rows[[j]] <- row
    }
    for (col in names(fill)) if (!is.character(old[[col]])) old[[col]] <- as.character(old[[col]])
    out <- if (length(rows)) do.call(rbind, rows) else old[0, , drop = FALSE]
    if (keep_unmatched) {
      keep <- old[!old_id %in% new_ids & nzchar(old_id), , drop = FALSE]
      out <- rbind(out, keep)
    }
    out <- out[order(up(out$ID), method = "radix"), , drop = FALSE]
    rownames(out) <- NULL
    out
  }

  m <- rec[rec$type %in% c("Computation", "Imputation"), , drop = FALSE]
  methods <- merge_id_sheet(data$Methods, m$name,
                            list(ID = m$name, Name = m$name, Type = m$type,
                                 Description = m$description))
  cm <- rec[rec$type == "Comments", , drop = FALSE]
  comments <- merge_id_sheet(data$Comments, cm$name,
                             list(ID = cm$name, Description = cm$description))

  new <- list(Datasets = ds, Variables = vars, Methods = methods, Comments = comments)

  # V013: references that point at nothing
  mid <- up(methods$ID); cid <- up(comments$ID)
  vm <- up(vars$Method); vc <- up(vars$Comment); dc <- up(ds$Comment)
  for (i in which(nzchar(vm) & !vm %in% mid))
    add("V013", "warning", name = vm[i], message = sprintf(
      "Variables row %s.%s references method %s, which is not on the Methods sheet",
      vars$Dataset[i], vars$Variable[i], vm[i]),
      suggestion = "add a DEFX tag for it or use --keep-unmatched to retain manual rows")
  for (i in which(nzchar(vc) & !vc %in% cid))
    add("V013", "warning", name = vc[i], message = sprintf(
      "Variables row %s.%s references comment %s, which is not on the Comments sheet",
      vars$Dataset[i], vars$Variable[i], vc[i]),
      suggestion = "add a DEFX Comments tag or use --keep-unmatched")
  for (i in which(nzchar(dc) & !dc %in% cid))
    add("V013", "warning", name = dc[i], message = sprintf(
      "Datasets row %s references comment %s, which is not on the Comments sheet",
      ds$Dataset[i], dc[i]),
      suggestion = "add a DEFX Comments tag or use --keep-unmatched")

  list(data = new, diagnostics = sort_diags(do.call(bind_diags, d)),
       touched = list(Variables = sort(unique(touched_vars)),
                      Datasets = sort(unique(touched_ds))))
}

write_sheet <- function(wb, sheet, old, new) {
  nr <- max(nrow(old), nrow(new)) + 1L
  nc <- max(ncol(old), ncol(new))
  openxlsx::deleteData(wb, sheet, cols = seq_len(nc), rows = seq_len(nr), gridExpand = TRUE)
  openxlsx::writeData(wb, sheet, new, startRow = 1, startCol = 1, colNames = TRUE,
                      keepNA = FALSE)
}

#' Read every sheet of a workbook as text, for comparison.
#'
#' Uses readxl (an independent reader) when installed, otherwise openxlsx.
workbook_content <- function(path) {
  if (requireNamespace("readxl", quietly = TRUE)) {
    sh <- readxl::excel_sheets(path)
    out <- lapply(setNames(sh, sh), function(s) {
      x <- suppressMessages(readxl::read_excel(path, sheet = s, col_names = FALSE,
                                               col_types = "text", .name_repair = "minimal"))
      x <- as.data.frame(x, stringsAsFactors = FALSE)
      names(x) <- NULL
      x
    })
  } else {
    sh <- openxlsx::getSheetNames(path)
    out <- lapply(setNames(sh, sh), function(s) {
      x <- openxlsx::read.xlsx(path, sheet = s, colNames = FALSE, skipEmptyRows = FALSE,
                               skipEmptyCols = FALSE)
      if (is.null(x)) x <- data.frame()
      x[] <- lapply(x, as.character); names(x) <- NULL; x
    })
  }
  out
}

#' TRUE if two workbooks have identical sheet names and cell text.
workbooks_equivalent <- function(a, b) {
  identical(workbook_content(a), workbook_content(b))
}

#' Verify that an exported workbook preserved everything it should.
#'
#' @return data.frame(check, result, detail) with result PASS/FAIL.
verify_export <- function(template_path, out_path, touched, sentinel = "DO_NOT_CHANGE") {
  a <- workbook_content(template_path); b <- workbook_content(out_path)
  res <- list()
  chk <- function(check, pass, detail) res[[length(res) + 1L]] <<-
    data.frame(check = check, result = if (isTRUE(pass)) "PASS" else "FAIL",
               detail = detail, stringsAsFactors = FALSE)
  chk("sheet names and order unchanged", identical(names(a), names(b)),
      paste(names(b), collapse = ", "))
  other <- setdiff(names(a), DEFX_SHEETS)
  for (s in other)
    chk(sprintf("sheet '%s' byte-for-byte cell text unchanged", s),
        s %in% names(b) && identical(a[[s]], b[[s]]),
        sprintf("%d x %d cells", nrow(a[[s]]), ncol(a[[s]])))
  for (s in c("Datasets", "Variables")) {
    x <- a[[s]]; y <- b[[s]]
    hx <- unlist(x[1, ]); hy <- unlist(y[1, ])
    same_shape <- identical(dim(x), dim(y)) && identical(hx, hy)
    chk(sprintf("%s: same rows, columns and header", s), same_shape,
        sprintf("%d rows x %d cols", nrow(y) - 1L, ncol(y)))
    if (!same_shape) next
    owned <- which(hx %in% OWNED_COLS[[s]])
    keep <- setdiff(seq_along(hx), owned)
    chk(sprintf("%s: non-DEFX columns unchanged", s),
        identical(x[, keep, drop = FALSE], y[, keep, drop = FALSE]),
        paste(hx[keep], collapse = ", "))
    untouched <- setdiff(seq_len(nrow(x) - 1L), touched[[s]]) + 1L
    chk(sprintf("%s: rows without tags unchanged", s),
        identical(x[untouched, , drop = FALSE], y[untouched, , drop = FALSE]),
        sprintf("%d untouched rows", length(untouched)))
  }
  for (s in c("Methods", "Comments")) {
    hx <- unlist(a[[s]][1, ]); hy <- unlist(b[[s]][1, ])
    chk(sprintf("%s: header unchanged", s), identical(hx, hy), paste(hy, collapse = ", "))
    if (!identical(hx, hy) || nrow(a[[s]]) < 2 || nrow(b[[s]]) < 2) next
    idc <- which(hx == "ID")
    keep <- which(!hx %in% REQUIRED_COLS[[s]])
    ax <- a[[s]][-1, , drop = FALSE]; bx <- b[[s]][-1, , drop = FALSE]
    common <- intersect(up(ax[[idc]]), up(bx[[idc]]))
    same <- all(vapply(common, function(id) identical(
      unlist(ax[match(id, up(ax[[idc]])), keep]), unlist(bx[match(id, up(bx[[idc]])), keep])),
      logical(1)))
    chk(sprintf("%s: matched rows keep non-DEFX columns", s), same,
        sprintf("%d matched ID(s); columns: %s", length(common),
                if (length(keep)) paste(hx[keep], collapse = ", ") else "none"))
  }
  count_sentinel <- function(w) sum(vapply(w, function(x) sum(unlist(x) == sentinel, na.rm = TRUE),
                                           numeric(1)))
  ns_a <- count_sentinel(a); ns_b <- count_sentinel(b)
  chk(sprintf("sentinel '%s' count unchanged", sentinel), ns_a == ns_b,
      sprintf("template %d, output %d", ns_a, ns_b))
  do.call(rbind, res)
}

#' Export validated records into a copy of a define-like template.
#'
#' Refuses to run if `records` contain errors, never writes over the template,
#' writes atomically, and verifies the result before it is moved into place.
#'
#' @return list(out, diagnostics, checks, counts)
export_defx_workbook <- function(records, template_path, out_path, keep_unmatched = FALSE) {
  tp <- normalizePath(template_path, mustWork = FALSE)
  op <- normalizePath(out_path, mustWork = FALSE)
  if (identical(tp, op))
    stop(defx_input_error("--out must be a different file from --template (the template is never overwritten)"))
  if (any(records$status == "error"))
    stop("internal: export_defx_workbook() called with error records")
  tpl <- load_template(template_path)
  built <- build_workbook_data(records, tpl$data, keep_unmatched = keep_unmatched)
  if (any(built$diagnostics$severity == "error"))
    return(list(out = NULL, diagnostics = built$diagnostics, checks = NULL, counts = NULL))
  wb <- tpl$wb
  for (s in DEFX_SHEETS) write_sheet(wb, s, tpl$data[[s]], built$data[[s]])
  dir.create(dirname(op), recursive = TRUE, showWarnings = FALSE)
  tmp <- tempfile(pattern = ".defx-", tmpdir = dirname(op), fileext = ".xlsx")
  on.exit(if (file.exists(tmp)) unlink(tmp), add = TRUE)
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)
  checks <- verify_export(template_path, tmp, built$touched)
  if (any(checks$result == "FAIL"))
    return(list(out = NULL, diagnostics = built$diagnostics, checks = checks, counts = NULL))
  if (!file.rename(tmp, op)) {
    ok <- file.copy(tmp, op, overwrite = TRUE)
    if (!ok) stop(sprintf("could not move workbook into place at %s", op))
  }
  counts <- c(methods = nrow(built$data$Methods), comments = nrow(built$data$Comments),
              variables_updated = length(built$touched$Variables),
              datasets_updated = length(built$touched$Datasets))
  list(out = op, diagnostics = built$diagnostics, checks = checks, counts = counts)
}
