# Comment extraction and DEFX tag parsing -------------------------------------
#
# Nothing here evaluates source code. R files are tokenised with R's own parser
# (parse() + getParseData(), which never runs the code); SAS files go through a
# small conservative lexer that understands block comments, quoted strings,
# statement comments and DATALINES/CARDS blocks. Both produce the same
# "comment" table, which parse_defx_comments() turns into tag segments.

DEFX_TYPES <- c("Computation", "Imputation", "Predecessor", "Assigned", "Comments")

empty_comments <- function() {
  data.frame(line = integer(), end_line = integer(), col = integer(),
             form = character(), body = character(), raw = character(),
             stringsAsFactors = FALSE)
}

read_source_text <- function(path) {
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  lines
}

# SAS ---------------------------------------------------------------------------

#' Lex SAS source into comments.
#'
#' Supported comment forms: `/* ... */` (single or multi-line) and statement
#' comments `* ... ;` / `%* ... ;` that begin a statement. Quoted strings
#' ('...' and "..." with doubled-quote escapes) and DATALINES/CARDS blocks are
#' skipped so text inside them is never treated as a comment. Macro quoting
#' functions (%str, %nrstr, ...) are NOT interpreted.
#'
#' @return list(comments = data.frame, problems = character())
lex_sas_comments <- function(lines) {
  text <- paste(lines, collapse = "\n")
  ch <- strsplit(text, "", fixed = TRUE)[[1]]
  n <- length(ch)
  com <- vector("list", 0)
  problems <- character()
  i <- 1L; line <- 1L; col <- 1L
  stmt_start <- TRUE
  stmt_from <- 1L
  line_start <- 1L   # index of first char of current line (for column numbers)

  advance_newlines <- function(from, to) {
    # count newlines in ch[from..to], update line + line_start
    if (to < from) return(invisible())
    idx <- which(ch[from:to] == "\n")
    if (length(idx)) {
      line <<- line + length(idx)
      line_start <<- from + idx[length(idx)]
    }
  }

  while (i <= n) {
    c <- ch[i]
    nx <- if (i < n) ch[i + 1L] else ""

    if (c == "/" && nx == "*") {                      # block comment
      sline <- line; scol <- i - line_start + 1L
      j <- i + 2L
      found <- FALSE
      while (j < n) {
        if (ch[j] == "*" && ch[j + 1L] == "/") { found <- TRUE; break }
        j <- j + 1L
      }
      if (!found) {
        problems <- c(problems, sprintf("line %d: unterminated /* comment", sline))
        break
      }
      body <- if (j > i + 2L) paste(ch[(i + 2L):(j - 1L)], collapse = "") else ""
      advance_newlines(i, j)
      com[[length(com) + 1L]] <- list(line = sline, end_line = line, col = scol,
                                      form = "block", body = body,
                                      raw = paste0("/*", body, "*/"))
      i <- j + 2L
      next
    }

    if (c == "'" || c == "\"") {                      # quoted string
      sline <- line
      j <- i + 1L
      closed <- FALSE
      while (j <= n) {
        if (ch[j] == c) {
          if (j < n && ch[j + 1L] == c) { j <- j + 2L; next }  # doubled quote
          closed <- TRUE; break
        }
        j <- j + 1L
      }
      if (!closed) {
        problems <- c(problems, sprintf("line %d: unterminated %s string", sline, c))
        break
      }
      advance_newlines(i, j)
      stmt_start <- FALSE
      i <- j + 1L
      next
    }

    if (stmt_start && (c == "*" || (c == "%" && nx == "*"))) {  # statement comment
      sline <- line; scol <- i - line_start + 1L
      skip <- if (c == "%") 2L else 1L
      j <- i + skip
      while (j <= n && ch[j] != ";") j <- j + 1L
      if (j > n) {
        problems <- c(problems, sprintf("line %d: unterminated * comment statement", sline))
        break
      }
      body <- if (j > i + skip) paste(ch[(i + skip):(j - 1L)], collapse = "") else ""
      advance_newlines(i, j)
      com[[length(com) + 1L]] <- list(line = sline, end_line = line, col = scol,
                                      form = "statement", body = body,
                                      raw = paste(ch[i:j], collapse = ""))
      stmt_start <- TRUE
      stmt_from <- j + 1L
      i <- j + 1L
      next
    }

    if (c == ";") {
      stmt <- if (i > stmt_from) tolower(trimws(paste(ch[stmt_from:(i - 1L)], collapse = ""))) else ""
      i <- i + 1L
      if (grepl("^(datalines|cards|lines|parmcards)4$", stmt)) {
        end <- regexpr(";;;;", paste(ch[i:n], collapse = ""), fixed = TRUE)
        j <- if (end > 0) i + end + 2L else n
        advance_newlines(i, j); i <- j + 1L
      } else if (grepl("^(datalines|cards|lines|parmcards)$", stmt)) {
        j <- i
        while (j <= n && ch[j] != ";") j <- j + 1L
        advance_newlines(i, min(j, n)); i <- j + 1L
      }
      stmt_start <- TRUE
      stmt_from <- i
      next
    }

    if (c == "\n") { line <- line + 1L; line_start <- i + 1L }
    else if (!grepl("[[:space:]]", c)) stmt_start <- FALSE
    i <- i + 1L
  }

  comments <- if (length(com)) {
    do.call(rbind, lapply(com, as.data.frame, stringsAsFactors = FALSE))
  } else empty_comments()
  list(comments = comments, problems = problems)
}

# R -----------------------------------------------------------------------------

#' Lex R source into comments with R's own tokenizer (no evaluation).
lex_r_comments <- function(lines, label = "source.R") {
  sf <- srcfilecopy(label, lines)
  res <- tryCatch({
    parse(text = lines, srcfile = sf, keep.source = TRUE)
    NULL
  }, error = function(e) conditionMessage(e))
  if (!is.null(res)) {
    m <- regmatches(res, regexec(":([0-9]+):[0-9]+:", res))[[1]]
    ln <- if (length(m) == 2) m[2] else "1"
    return(list(comments = empty_comments(),
                problems = sprintf("line %s: R parser error: %s", ln,
                                   gsub("\\s+", " ", res))))
  }
  pd <- utils::getParseData(sf)
  if (is.null(pd)) return(list(comments = empty_comments(), problems = character()))
  pd <- pd[pd$token == "COMMENT", , drop = FALSE]
  pd <- pd[order(pd$line1, pd$col1), , drop = FALSE]
  if (!nrow(pd)) return(list(comments = empty_comments(), problems = character()))
  comments <- data.frame(line = pd$line1, end_line = pd$line2, col = pd$col1,
                         form = "line", body = sub("^#+'?", "", pd$text),
                         raw = pd$text, stringsAsFactors = FALSE)
  list(comments = comments, problems = character())
}

# DEFX tag parsing ----------------------------------------------------------------

starts_with_defx <- function(x) grepl("^[[:space:]]*defx([[:space:]]|\\||$)", x, ignore.case = TRUE)

split_fields <- function(body) {
  # keep empty fields, including a trailing one ("A | B |" -> 3 fields)
  trimws(strsplit(paste0(body, "|"), "|", fixed = TRUE)[[1]])
}

#' Parse the body of one DEFX comment.
#'
#' @param body Comment text without comment delimiters, e.g.
#'   " DEFX | ADAE.AERELFL | Y if related ".
#' @return list(ok, name, type, description, name_form, dataset, variable,
#'   parameter, code, message, suggestion). When `ok` is FALSE, `code` is the
#'   diagnostic code (V001, V004 or V005).
parse_defx_tag <- function(body) {
  fail <- function(code, message, suggestion = "", name = "") {
    list(ok = FALSE, name = name, code = code, message = message,
         suggestion = suggestion)
  }
  syntax <- "DEFX | <Dataset>.<Variable> | [<Type> |] <Description>"
  f <- split_fields(body)
  if (toupper(f[1]) != "DEFX")
    return(fail("V001", sprintf("unexpected text before the first '|': '%s'", f[1]),
                sprintf("start the tag with exactly: %s", syntax)))
  rest <- f[-1]
  if (!length(rest) || rest[1] == "")
    return(fail("V001", "missing <Dataset>.<Variable> name", syntax))
  name <- toupper(rest[1])
  if (grepl(",", name, fixed = TRUE))
    return(fail("V001", sprintf("comma in tag name '%s'", rest[1]),
                "remove the comma; one tag names one target", name))
  if (!grepl("^[A-Z_][A-Z0-9_]*(\\.[A-Z0-9_]+)*$", name))
    return(fail("V001", sprintf("invalid identifier in tag name '%s'", rest[1]),
                "use <Dataset>.<Variable> with letters, digits and underscores", name))

  # name form (independent of any specification)
  parts <- strsplit(name, ".", fixed = TRUE)[[1]]
  form <- NULL; ds <- ""; var <- ""; par <- ""
  if (length(parts) == 1) {
    form <- "single"                     # dataset OR variable-in-all-datasets
  } else if (length(parts) == 2) {
    form <- "dataset_variable"; ds <- parts[1]; var <- parts[2]
  } else if (length(parts) == 5 && parts[1] == "AVAL" && parts[3] == "PARAMCD" &&
             parts[4] == "EQ") {
    form <- "parameter"; ds <- parts[2]; var <- "AVAL"; par <- parts[5]
  } else if (length(parts) == 3) {
    form <- "parameter"; ds <- parts[1]; var <- parts[2]; par <- parts[3]
  } else {
    return(fail("V001", sprintf("unsupported name form '%s'", rest[1]),
                paste("supported: <Dataset>, <Variable>, <Dataset>.<Variable>,",
                      "<Dataset>.<Variable>.<Value>, AVAL.<Dataset>.PARAMCD.EQ.<Value>"),
                name))
  }

  type_kw <- c(computation = "Computation", imputation = "Imputation",
               predecessor = "Predecessor", assigned = "Assigned",
               comments = "Comments")
  n <- length(rest)
  if (n == 1)
    return(fail("V001", sprintf("tag '%s' has no description", name),
                "add '| <Description>' or '| Assigned'", name))
  if (n >= 4)
    return(fail("V001", sprintf("tag '%s' has %d '|' delimiters; expected at most 3",
                                name, n),
                "a description cannot contain '|'; reword it or split it across tag lines",
                name))
  if (n == 2) {
    x <- rest[2]
    kw <- tolower(x)
    if (x == "") return(fail("V001", sprintf("empty description for '%s'", name),
                             "write the description after the second '|'", name))
    if (kw == "assigned") {
      type <- "Assigned"; desc <- ""
    } else if (kw %in% names(type_kw)) {
      code <- if (kw == "predecessor") "V005" else "V001"
      return(fail(code, sprintf("type '%s' given for '%s' but nothing follows it",
                                type_kw[[kw]], name),
                  sprintf("use: DEFX | %s | %s | <%s>", name, type_kw[[kw]],
                          if (kw == "predecessor") "Dataset.Variable" else "Description"),
                  name))
    } else {
      type <- "Computation"; desc <- x   # implicit computation (paper default)
    }
  } else {                                  # n == 3
    kw <- tolower(rest[2]); desc <- rest[3]
    if (kw == "assigned")
      return(fail("V004", sprintf("'Assigned' takes no description (tag '%s')", name),
                  sprintf("use: DEFX | %s | Assigned", name), name))
    if (!kw %in% names(type_kw))
      return(fail("V004", sprintf("unsupported tag type '%s' for '%s'", rest[2], name),
                  paste("valid types: Imputation, Predecessor, Comments, Computation",
                        "(or omit the type); if the description contains '|', reword it"),
                  name))
    type <- type_kw[[kw]]
    if (desc == "") {
      code <- if (type == "Predecessor") "V005" else "V001"
      return(fail(code, sprintf("empty %s for '%s'",
                                if (type == "Predecessor") "predecessor" else "description", name),
                  "write it after the last '|'", name))
    }
  }
  if (form == "parameter" && !type %in% c("Computation", "Imputation"))
    return(fail("V004", sprintf("parameter-level name '%s' supports only Computation/Imputation, not %s",
                                name, type),
                "document the variable itself with <Dataset>.<Variable>", name))

  list(ok = TRUE, name = name, type = type, description = desc,
       name_form = form, dataset = ds, variable = var, parameter = par)
}

#' Turn a comment table into DEFX segments plus diagnostics.
parse_defx_comments <- function(comments, source_file, language) {
  segs <- list(); diags <- list()
  add_diag <- function(...) diags[[length(diags) + 1L]] <<- new_diag(...)
  for (k in seq_len(nrow(comments))) {
    cm <- comments[k, ]
    if (cm$form == "block" && cm$end_line > cm$line) {
      # multi-line block comment: one-tag-per-comment is the supported form
      ls <- strsplit(cm$body, "\n", fixed = TRUE)[[1]]
      hit <- which(starts_with_defx(sub("^[[:space:]]*\\*?", "", ls)))
      for (h in hit)
        add_diag("V001", "error", source_file, cm$line + h - 1L,
                 message = "DEFX tag inside a multi-line /* ... */ comment is not supported",
                 suggestion = "put each tag line in its own /* DEFX | ... */ comment")
      next
    }
    if (!starts_with_defx(cm$body)) next
    if (cm$form == "statement") {
      add_diag("V012", "warning", source_file, cm$line,
               message = "DEFX tag in a '* ... ;' statement comment was ignored",
               suggestion = "use /* DEFX | ... */ in SAS programs")
      next
    }
    if (!grepl("|", cm$body, fixed = TRUE)) {
      add_diag("V010", "warning", source_file, cm$line,
               message = sprintf("comment starts with DEFX but has no '|' delimiter: '%s'",
                                 trimws(cm$body)),
               suggestion = "if this is meant to be a tag, use DEFX | <Dataset>.<Variable> | <Description>")
      next
    }
    p <- parse_defx_tag(cm$body)
    if (!p$ok) {
      add_diag(p$code, "error", source_file, cm$line, name = p$name,
               message = p$message, suggestion = p$suggestion)
      segs[[length(segs) + 1L]] <- list(
        source_file = source_file, source_line = cm$line, source_col = cm$col,
        language = language, raw_tag = cm$raw, name = p$name, name_form = "",
        dataset = "", variable = "", parameter = "", type = "",
        description = "", parse_status = "malformed")
      next
    }
    segs[[length(segs) + 1L]] <- list(
      source_file = source_file, source_line = cm$line, source_col = cm$col,
      language = language, raw_tag = cm$raw, name = p$name, name_form = p$name_form,
      dataset = p$dataset, variable = p$variable, parameter = p$parameter,
      type = p$type, description = p$description, parse_status = "ok")
  }
  list(segments = if (length(segs)) do.call(rbind, lapply(segs, as.data.frame,
                                                         stringsAsFactors = FALSE))
                  else empty_segments(),
       diagnostics = do.call(bind_diags, diags))
}

empty_segments <- function() {
  data.frame(source_file = character(), source_line = integer(), source_col = integer(),
             language = character(), raw_tag = character(), name = character(),
             name_form = character(), dataset = character(), variable = character(),
             parameter = character(), type = character(), description = character(),
             parse_status = character(), stringsAsFactors = FALSE)
}

#' Extract DEFX segments from one SAS program.
extract_sas_tags <- function(path, source_file = basename(path)) {
  extract_tags_file(path, source_file, "SAS")
}

#' Extract DEFX segments from one R program.
extract_r_tags <- function(path, source_file = basename(path)) {
  extract_tags_file(path, source_file, "R")
}

extract_tags_file <- function(path, source_file, language) {
  lines <- tryCatch(read_source_text(path), error = function(e) e,
                    warning = function(w) w)
  if (inherits(lines, "condition")) {
    return(list(segments = empty_segments(),
                diagnostics = new_diag("V008", "error", source_file,
                                       message = sprintf("cannot read file: %s",
                                                         conditionMessage(lines)))))
  }
  lx <- if (language == "SAS") lex_sas_comments(lines) else lex_r_comments(lines, source_file)
  pd <- parse_defx_comments(lx$comments, source_file, language)
  probs <- if (length(lx$problems)) {
    do.call(bind_diags, lapply(lx$problems, function(p)
      new_diag("V008", "error", source_file,
               source_line = suppressWarnings(as.integer(sub("^line ([0-9]+):.*$", "\\1", p))),
               message = p,
               suggestion = if (language == "R") "fix the R syntax error; tags in this file were NOT extracted"
                            else "tags after this point were NOT extracted")))
  } else NULL
  list(segments = pd$segments, diagnostics = bind_diags(pd$diagnostics, probs))
}

#' Extract DEFX segments from every discovered program.
extract_all <- function(sources) {
  segs <- list(); diags <- list()
  for (k in seq_len(nrow(sources))) {
    r <- extract_tags_file(sources$path[k], sources$source_file[k], sources$language[k])
    segs[[k]] <- r$segments; diags[[k]] <- r$diagnostics
  }
  list(segments = if (length(segs)) do.call(rbind, segs) else empty_segments(),
       diagnostics = do.call(bind_diags, diags))
}
