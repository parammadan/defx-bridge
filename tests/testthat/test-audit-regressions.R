# Regression tests for defects found by the independent audit (2026-11-12).
# Each test reproduces the original failure; see docs/DEFX_BRIDGE_INDEPENDENT_AUDIT.md.

tpl_copy <- function(dir, edit = NULL) {
  p <- file.path(dir, "tpl.xlsx")
  wb <- openxlsx::loadWorkbook(example_path("define_like_template.xlsx"))
  if (!is.null(edit)) edit(wb)
  openxlsx::saveWorkbook(wb, p, overwrite = TRUE)
  p
}
valid_records <- function() run_pipeline(example_path("valid"), example_path("spec.csv"))$records

test_that("D1: a comment before DATALINES does not hide the data block", {
  d <- new_tmp()
  write_src(d, "names.sas", c("data names;", "input name $20.;", "/* raw names follow */",
                              "datalines;", "O'Brien", "/* DEFX | ADAE.FAKE | data, not a tag */", ";", "run;",
                              "/* DEFX | ADSL.AGE | Predecessor | DM.AGE */"))
  res <- run_dir(d, mini_spec(d))
  expect_false(any(res$diagnostics$code %in% c("V001", "V008")))   # (DM is outside mini_spec: V011 info only)
  expect_equal(res$records$name, "ADSL.AGE")                       # the DEFX-like data line is not a tag
  expect_equal(res$records$source_line, 9L)
})

test_that("D11: an unterminated DATALINES4 block is reported, not silently swallowed", {
  d <- new_tmp()
  write_src(d, "x.sas", c("data x; input a $; datalines4;", "a", "/* DEFX | ADSL.AGE | never */"))
  res <- run_dir(d)
  expect_equal(res$diagnostics$code[res$diagnostics$code != "V014"], "V008")
  expect_match(res$diagnostics$message[res$diagnostics$code == "V008"], ";;;;")
})

test_that("D2: a non-UTF-8 program is a V008 for that file; other files still scan", {
  d <- new_tmp()
  writeBin(c(charToRaw("/* DEFX | ADSL.AGE | caf"), as.raw(0xe9), charToRaw(" */\n")), file.path(d, "latin1.sas"))
  write_src(d, "ok.R", "# DEFX | ADSL.AGE | Predecessor | DM.AGE")
  res <- run_dir(d)
  v8 <- res$diagnostics[res$diagnostics$code == "V008", ]
  expect_equal(v8$source_file, "latin1.sas")
  expect_match(v8$message, "not valid UTF-8")
  expect_equal(res$records$source_file, "ok.R")
})

test_that("D16: dataset/variable names cannot start with a digit; parameter values may", {
  d <- new_tmp()
  write_src(d, "a.sas", c("/* DEFX | ADSL.1AGE | x */", "/* DEFX | ADVS.AVAL.1A | x */"))
  res <- run_dir(d)
  expect_equal(res$diagnostics$code, "V001")
  expect_equal(res$diagnostics$source_line, 1L)
  expect_equal(res$records$name[res$records$status == "ok"], "ADVS.AVAL.1A")
})

test_that("D8: the two spellings of one AVAL parameter in two programs are a V003 conflict", {
  d <- new_tmp()
  write_src(d, "a.sas", "/* DEFX | AVAL.ADVS.PARAMCD.EQ.SYSBP | x */")
  write_src(d, "b.R", "# DEFX | ADVS.AVAL.SYSBP | y")
  e <- errors(run_dir(d, mini_spec(d)))
  expect_equal(e$code, c("V003", "V003"))
  expect_equal(e$source_file, c("a.sas", "b.R"))
})

test_that("D13: an unnamed warning on the same line does not taint another record", {
  d <- new_tmp()
  write_src(d, "a.sas", "/* DEFX | ADAE.AERELFL | Y */ /* DEFX no pipe */")
  res <- run_dir(d, mini_spec(d))
  expect_equal(res$diagnostics$code, "V010")
  expect_equal(res$records$status, "ok")
})

test_that("D3: --out that is a directory is refused and reports no success", {
  skip_without_repo()
  d <- new_tmp(); dir.create(file.path(d, "out.xlsx"))
  expect_error(export_defx_workbook(valid_records(), example_path("define_like_template.xlsx"),
                                    file.path(d, "out.xlsx")), "is a directory", class = "defx_input_error")
  expect_length(list.files(file.path(d, "out.xlsx"), all.files = TRUE, no.. = TRUE), 0)
})

test_that("D4: formulas and numbers in untargeted Variables cells survive export", {
  skip_without_repo(); skip_if_not_installed("readxl")
  d <- new_tmp()
  # row 8 = ADSL.SEX (no DEFX tag); col 6 = Length; col 12 = Developer Notes (a text column)
  tp <- tpl_copy(d, function(wb) {
    openxlsx::writeFormula(wb, "Variables", "=40+2", startCol = 6, startRow = 8)
    openxlsx::writeData(wb, "Variables", 7, startCol = 12, startRow = 9)        # a number in a text column
  })
  out <- file.path(d, "out.xlsx")
  ex <- export_defx_workbook(valid_records(), tp, out)
  expect_false(is.null(ex$out))
  x <- file.path(d, "x"); utils::unzip(out, exdir = x)
  sheets <- list.files(file.path(x, "xl", "worksheets"), "\\.xml$", full.names = TRUE)
  expect_true(any(vapply(sheets, function(f) any(grepl("40+2</f>", readLines(f, warn = FALSE), fixed = TRUE)), logical(1))))
  v <- readxl::read_excel(out, "Variables", col_types = "list")
  expect_true(is.numeric(v[["Developer Notes"]][[8]]))                         # still a number, not text
  expect_true(is.numeric(v$Order[[1]]))
})

test_that("D5: verify_export fails when a targeted cell does not hold the tag value", {
  skip_without_repo(); skip_if_not_installed("readxl")
  d <- new_tmp(); out <- file.path(d, "out.xlsx")
  rec <- valid_records(); tpl <- example_path("define_like_template.xlsx")
  ex <- export_defx_workbook(rec, tpl, out)
  built <- build_workbook_data(rec, load_template(tpl)$data)
  wb <- openxlsx::loadWorkbook(out)
  v <- openxlsx::readWorkbook(wb, "Variables", sep.names = " ")
  r <- which(v$Variable == "AERELFL"); oc <- match("Origin", names(v))
  openxlsx::writeData(wb, "Variables", "WRONG", startCol = oc, startRow = r + 1)
  bad <- file.path(d, "bad.xlsx"); openxlsx::saveWorkbook(wb, bad)
  chk <- verify_export(tpl, bad, built$touched, expected = built$data)
  expect_equal(chk$result[chk$check == "Variables: tagged cells hold the tag values"], "FAIL")
})

test_that("D5: export refuses to keep the workbook when verification fails", {
  skip_without_repo()
  d <- new_tmp(); out <- file.path(d, "out.xlsx")
  local_mocked_bindings(verify_export = function(...) data.frame(check = "forced", result = "FAIL", detail = ""))
  ex <- export_defx_workbook(valid_records(), example_path("define_like_template.xlsx"), out)
  expect_null(ex$out)
  expect_false(file.exists(out))
  expect_length(list.files(d, pattern = "^\\.defx-", all.files = TRUE), 0)
})

test_that("D7: a sentinel on a legitimately dropped Methods row does not fail verification", {
  skip_without_repo()
  d <- new_tmp()
  tp <- tpl_copy(d, function(wb) {
    openxlsx::writeData(wb, "Methods", data.frame(ID = "MANUAL.X", Name = "MANUAL.X", Type = "Computation",
                        Description = "manual", `Expression Context` = NA, `Expression Code` = "DO_NOT_CHANGE",
                        check.names = FALSE), startRow = 4, colNames = FALSE)
  })
  ex <- export_defx_workbook(valid_records(), tp, file.path(d, "out.xlsx"))
  expect_false(is.null(ex$out))
  expect_true(all(ex$checks$result == "PASS"))
})

test_that("D9: --keep-unmatched keeps blank-ID note rows", {
  skip_without_repo(); skip_if_not_installed("readxl")
  d <- new_tmp(); out <- file.path(d, "out.xlsx")
  tp <- tpl_copy(d, function(wb) openxlsx::writeData(wb, "Methods", "a note row with no ID", startCol = 4, startRow = 4))
  ex <- export_defx_workbook(valid_records(), tp, out, keep_unmatched = TRUE)
  m <- readxl::read_excel(out, "Methods", col_types = "text")
  expect_true("a note row with no ID" %in% m$Description)
})

test_that("V013 is emitted for a Method reference that resolves to nothing", {
  skip_without_repo()
  d <- new_tmp()
  # row 8 = ADSL.SEX (no tag); col 10 = Method
  tp <- tpl_copy(d, function(wb) openxlsx::writeData(wb, "Variables", "NO.SUCH.METHOD", startCol = 10, startRow = 8))
  ex <- export_defx_workbook(valid_records(), tp, file.path(d, "out.xlsx"))
  expect_equal(ex$diagnostics$code, "V013")
  expect_equal(ex$diagnostics$severity, "warning")
  expect_match(ex$diagnostics$message, "ADSL.SEX references method NO.SUCH.METHOD")
})

test_that("D6 / D10: CLI refuses zero-tag exports and outputs that would overwrite inputs", {
  skip_without_cli <- function() { skip_without_repo(); skip_if_not(file.exists(cli_path())); skip_on_os("windows") }
  skip_without_cli()
  d <- new_tmp()
  write_src(d, "empty/a.R", "x <- 1")
  r <- run_cli(c("export", "--source", file.path(d, "empty"), "--spec", example_path("spec.csv"),
                 "--template", example_path("define_like_template.xlsx"), "--out", file.path(d, "o.xlsx")))
  expect_equal(r$status, 1L); expect_match(r$out, "refusing to export"); expect_false(file.exists(file.path(d, "o.xlsx")))
  file.copy(example_path("spec.csv"), file.path(d, "spec.csv"))
  before <- readLines(file.path(d, "spec.csv"))
  r <- run_cli(c("validate", "--source", example_path("valid"), "--spec", file.path(d, "spec.csv"),
                 "--out", file.path(d, "spec.csv")))
  expect_equal(r$status, 1L); expect_match(r$out, "refusing to write an output over an input")
  expect_identical(readLines(file.path(d, "spec.csv")), before)
})
