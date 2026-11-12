# Shared test helpers.

repo_root <- function() normalizePath(file.path(testthat::test_path(), "..", ".."), mustWork = FALSE)
example_path <- function(...) file.path(repo_root(), "examples", ...)
cli_path <- function() file.path(repo_root(), "bin", "defxbridge")
skip_without_repo <- function() {
  # CI sets DEFX_REQUIRE_FIXTURES=true for the full-suite job so these tests can't silently skip.
  if (identical(Sys.getenv("DEFX_REQUIRE_FIXTURES"), "true") && !dir.exists(example_path()))
    stop("DEFX_REQUIRE_FIXTURES=true but examples/ is missing")
  testthat::skip_if_not(dir.exists(example_path()), "repository examples/ not available")
}

new_tmp <- function(env = parent.frame()) {
  normalizePath(withr::local_tempdir(pattern = "defx-test-", .local_envir = env))
}

write_src <- function(dir, name, lines) {
  p <- file.path(dir, name)
  dir.create(dirname(p), recursive = TRUE, showWarnings = FALSE)
  writeLines(lines, p, useBytes = TRUE)
  p
}

mini_spec <- function(dir, rows = c("ADAE.AERELFL", "ADAE.AETERM", "ADAE.ASTDT",
                                    "ADAE.PARAMCD", "ADAE.STUDYID", "ADSL.STUDYID",
                                    "ADSL.AGE", "AE.AETERM", "AE.AEREL", "ADVS.AVAL",
                                    "ADVS.PARAMCD")) {
  p <- file.path(dir, "spec.csv")
  parts <- do.call(rbind, strsplit(rows, ".", fixed = TRUE))
  utils::write.csv(data.frame(Dataset = parts[, 1], Variable = parts[, 2]), p, row.names = FALSE)
  p
}

#' Pipeline over a temp dir of sources.
run_dir <- function(dir, spec = NULL) run_pipeline(dir, spec)

codes <- function(res) res$diagnostics$code
errors <- function(res) res$diagnostics[res$diagnostics$severity == "error", , drop = FALSE]

run_cli <- function(args, wd = NULL) {
  bin <- normalizePath(cli_path())
  old <- if (!is.null(wd)) setwd(wd)
  on.exit(if (!is.null(old)) setwd(old))
  out <- suppressWarnings(system2(bin, shQuote(args), stdout = TRUE, stderr = TRUE))
  status <- attr(out, "status")
  list(status = if (is.null(status)) 0L else as.integer(status),
       out = paste(out, collapse = "\n"))
}
