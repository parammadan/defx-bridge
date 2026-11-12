# CLI end-to-end (runs the real bin/defxbridge) -------------------------------------

skip_without_cli <- function() {
  skip_without_repo()
  skip_if_not(file.exists(cli_path()), "bin/defxbridge not available")
  skip_on_os("windows")
}

no_stack_trace <- function(out) {
  expect_false(grepl("Traceback|Backtrace|Error in |Execution halted", out))
}

test_that("help and usage errors use the right exit codes", {
  skip_without_cli()
  r <- run_cli("--help"); expect_equal(r$status, 0L); expect_match(r$out, "Commands:")
  for (cmd in c("scan", "validate", "export", "compare")) {
    r <- run_cli(c(cmd, "--help")); expect_equal(r$status, 0L); expect_match(r$out, "Usage:")
  }
  r <- run_cli(character()); expect_equal(r$status, 1L)
  r <- run_cli("frobnicate"); expect_equal(r$status, 1L); expect_match(r$out, "unknown command")
  r <- run_cli(c("scan", "--source", example_path("valid"), "--bogus", "x"))
  expect_equal(r$status, 1L); expect_match(r$out, "unknown option --bogus"); no_stack_trace(r$out)
  r <- run_cli(c("validate", "--source", example_path("valid")))
  expect_equal(r$status, 1L); expect_match(r$out, "--spec is required")
  r <- run_cli(c("scan", "--source"))
  expect_equal(r$status, 1L); expect_match(r$out, "--source needs a value")
})

test_that("scan, validate and export succeed on the valid example (exit 0)", {
  skip_without_cli()
  d <- new_tmp()
  r <- run_cli(c("scan", "--source", example_path("valid"), "--out", file.path(d, "scan.csv")))
  expect_equal(r$status, 0L); expect_match(r$out, "Scan OK")
  scan <- utils::read.csv(file.path(d, "scan.csv"), colClasses = "character")
  expect_equal(nrow(scan), 40)
  expect_setequal(unique(scan$language), c("SAS", "R"))
  r <- run_cli(c("validate", "--source", example_path("valid"), "--spec", example_path("spec.csv"),
                 "--out", file.path(d, "validation.csv")))
  expect_equal(r$status, 0L); expect_match(r$out, "Validation PASSED: 0 error")
  expect_true(file.exists(file.path(d, "validation.md")))
  out <- file.path(d, "filled.xlsx")
  r <- run_cli(c("export", "--source", example_path("valid"), "--spec", example_path("spec.csv"),
                 "--template", example_path("define_like_template.xlsx"), "--out", out))
  expect_equal(r$status, 0L); expect_match(r$out, "Export OK"); expect_false(grepl("FAIL", r$out))
  expect_true(file.exists(out))
  expect_true(file.exists(file.path(d, "filled_meta.csv")))
  expect_true(file.exists(file.path(d, "filled_report.md")))
})

test_that("validation failures exit 2 and export writes no workbook", {
  skip_without_cli()
  d <- new_tmp()
  r <- run_cli(c("validate", "--source", example_path("invalid"), "--spec", example_path("spec.csv")))
  expect_equal(r$status, 2L); expect_match(r$out, "Validation FAILED")
  expect_match(r$out, "ADAE.DOESNOTEXIST is not in the specification")
  expect_false(grepl("PASSED|Export OK", r$out)); no_stack_trace(r$out)
  out <- file.path(d, "should_not_exist.xlsx")
  r <- run_cli(c("export", "--source", example_path("invalid"), "--spec", example_path("spec.csv"),
                 "--template", example_path("define_like_template.xlsx"), "--out", out))
  expect_equal(r$status, 2L); expect_match(r$out, "Export REFUSED")
  expect_false(file.exists(out))
  r <- run_cli(c("scan", "--source", example_path("invalid", "malformed.sas")))
  expect_equal(r$status, 2L)
})

test_that("runtime/input errors exit 1 without stack traces", {
  skip_without_cli()
  d <- new_tmp()
  r <- run_cli(c("validate", "--source", example_path("valid"), "--spec", file.path(d, "missing.csv")))
  expect_equal(r$status, 1L); expect_match(r$out, "V007"); no_stack_trace(r$out)
  r <- run_cli(c("scan", "--source", file.path(d, "no such dir")))
  expect_equal(r$status, 1L); expect_match(r$out, "source path does not exist"); no_stack_trace(r$out)
  tpl <- example_path("define_like_template.xlsx")
  r <- run_cli(c("export", "--source", example_path("valid"), "--spec", example_path("spec.csv"),
                 "--template", tpl, "--out", tpl))
  expect_equal(r$status, 1L); expect_match(r$out, "never overwritten")
  r <- run_cli(c("export", "--source", example_path("valid"), "--spec", example_path("spec.csv"),
                 "--template", file.path(d, "nope.xlsx"), "--out", file.path(d, "o.xlsx")))
  expect_equal(r$status, 1L); expect_match(r$out, "template not found"); no_stack_trace(r$out)
})

test_that("CLI works from another directory with relative paths and spaces", {
  skip_without_cli()
  d <- new_tmp()
  dir.create(file.path(d, "my src")); dir.create(file.path(d, "out dir"))
  file.copy(list.files(example_path("valid"), full.names = TRUE), file.path(d, "my src"))
  file.copy(example_path("spec.csv"), file.path(d, "spec file.csv"))
  file.copy(example_path("define_like_template.xlsx"), file.path(d, "tpl.xlsx"))
  r <- run_cli(c("export", "--source", "my src", "--spec", "spec file.csv", "--template", "tpl.xlsx",
                 "--out", "out dir/filled book.xlsx"), wd = d)
  expect_equal(r$status, 0L)
  expect_true(file.exists(file.path(d, "out dir", "filled book.xlsx")))
  # --opt=value form
  r <- run_cli(c("scan", "--source=my src", "--out=out dir/s.csv"), wd = d)
  expect_equal(r$status, 0L); expect_true(file.exists(file.path(d, "out dir", "s.csv")))
})

test_that("compare reports equivalence of two exports", {
  skip_without_cli()
  d <- new_tmp()
  base <- c("export", "--source", example_path("valid"), "--spec", example_path("spec.csv"),
            "--template", example_path("define_like_template.xlsx"))
  expect_equal(run_cli(c(base, "--out", file.path(d, "a.xlsx")))$status, 0L)
  expect_equal(run_cli(c(base, "--out", file.path(d, "b.xlsx")))$status, 0L)
  r <- run_cli(c("compare", file.path(d, "a.xlsx"), file.path(d, "b.xlsx")))
  expect_equal(r$status, 0L); expect_match(r$out, "EQUIVALENT")
  r <- run_cli(c("compare", file.path(d, "a.xlsx"), example_path("define_like_template.xlsx")))
  expect_equal(r$status, 2L); expect_match(r$out, "DIFFERENT")
})

test_that("piping output to head is not an error and keeps the real exit status", {
  skip_without_cli()
  d <- new_tmp(); out <- file.path(d, "v.csv")
  cmd <- sprintf("%s validate --source %s --spec %s --out %s | head -n 1 >/dev/null; echo \"status=${PIPESTATUS[0]}\"",
                 shQuote(normalizePath(cli_path())), shQuote(example_path("invalid")),
                 shQuote(example_path("spec.csv")), shQuote(out))
  res <- suppressWarnings(system2("bash", c("-c", shQuote(cmd)), stdout = TRUE, stderr = TRUE))
  expect_equal(tail(res, 1), "status=2")
  expect_false(any(grepl("error", head(res, -1), ignore.case = TRUE)))
  expect_true(file.exists(out))                       # files are still written
  expect_gt(length(readLines(out)), 1)
})

test_that("record tables fit the terminal width", {
  skip_without_cli()
  withr::local_envvar(DEFX_COLUMNS = "120")
  r <- run_cli(c("scan", "--source", example_path("valid"), "--spec", example_path("spec.csv")))
  lines <- strsplit(r$out, "\n")[[1]]
  tbl <- lines[grepl("^  (where|makead)", lines)]
  expect_equal(length(tbl), 41)                       # header + 40 records
  expect_true(all(nchar(tbl) <= 120))
})
