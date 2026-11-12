# Workbook export ----------------------------------------------------------------

export_valid <- function(out, keep_unmatched = FALSE) {
  res <- run_pipeline(example_path("valid"), example_path("spec.csv"))
  export_defx_workbook(res$records, example_path("define_like_template.xlsx"), out,
                       keep_unmatched = keep_unmatched)
}

sheet <- function(path, s) as.data.frame(readxl::read_excel(path, sheet = s, col_types = "text"))

test_that("export fills Datasets, Variables, Methods and Comments as documented", {
  skip_without_repo(); skip_if_not_installed("readxl")
  d <- new_tmp(); out <- file.path(d, "filled.xlsx")
  ex <- export_valid(out)
  expect_true(file.exists(out))
  expect_true(all(ex$checks$result == "PASS"))
  v <- sheet(out, "Variables")
  row <- function(ds, var) v[v$Dataset == ds & v$Variable == var, ]
  # Computation -> Derived + Method
  expect_equal(unlist(row("ADAE", "AERELFL")[c("Origin", "Method", "Comment")], use.names = FALSE),
               c("Derived", "ADAE.AERELFL", "ADAE.AERELFL"))
  # Imputation -> Derived + Method
  expect_equal(row("ADSL", "TRTSDT")$Origin, "Derived"); expect_equal(row("ADSL", "TRTSDT")$Method, "ADSL.TRTSDT")
  # Predecessor -> Origin + Predecessor, no Method
  expect_equal(unlist(row("ADAE", "AETERM")[c("Origin", "Predecessor")], use.names = FALSE),
               c("Predecessor", "AE.AETERM"))
  expect_true(is.na(row("ADAE", "AETERM")$Method))
  # Assigned via variable-only tag applies in every dataset
  expect_equal(v$Origin[v$Variable == "STUDYID"], rep("Assigned", 3))
  # parameter-level methods touch Methods only
  m <- sheet(out, "Methods")
  expect_true(all(c("AVAL.ADVS.PARAMCD.EQ.SYSBP", "ADVS.AVAL.PULSE") %in% m$ID))
  expect_false(any(grepl("PARAMCD.EQ", v$Method)))
  # multiline description consolidated in order
  expect_equal(m$Description[m$ID == "ADAE.AERELFL"],
               "Y if AE.AEREL=\"RELATED\" N if AE.AEREL=\"NOT RELATED\" otherwise set to missing")
  expect_equal(m$Type[m$ID == "ADAE.ASTDT"], "Imputation")
  # comments
  cm <- sheet(out, "Comments")
  expect_setequal(cm$ID, c("ADAE", "ADAE.AERELFL", "ADSL", "ADSL.ITTFL", "ADVS"))
  ds <- sheet(out, "Datasets")
  expect_equal(ds$Comment, ds$Dataset)
  # every Method / Comment reference resolves to a row on the Methods / Comments sheet
  refs_m <- v$Method[!is.na(v$Method)]; refs_c <- c(v$Comment[!is.na(v$Comment)], ds$Comment)
  expect_gt(length(refs_m), 0); expect_true(all(refs_m %in% m$ID))
  expect_true(all(refs_c %in% cm$ID))
  expect_equal(nrow(ex$diagnostics), 0)                         # no V013 dangling references
})

test_that("unrelated sheets, columns, rows and sentinel values are preserved", {
  skip_without_repo(); skip_if_not_installed("readxl")
  d <- new_tmp(); out <- file.path(d, "filled.xlsx")
  tpl <- example_path("define_like_template.xlsx")
  md5_before <- unname(tools::md5sum(tpl))
  export_valid(out)
  expect_equal(unname(tools::md5sum(tpl)), md5_before)          # template untouched
  expect_equal(readxl::excel_sheets(out), readxl::excel_sheets(tpl))
  expect_identical(sheet(out, "PreserveMe"), sheet(tpl, "PreserveMe"))
  expect_identical(sheet(out, "Study"), sheet(tpl, "Study"))
  expect_equal(sheet(out, "PreserveMe")$Value[1], "DO_NOT_CHANGE")
  expect_equal(sheet(out, "PreserveMe")$Value[4], "µg/mL ≤ 5")
  vo <- sheet(out, "Variables"); vt <- sheet(tpl, "Variables")
  keep <- setdiff(names(vt), c("Origin", "Predecessor", "Method", "Comment"))
  expect_identical(vo[keep], vt[keep])                           # Label, Codelist, Developer Notes, ...
  sex <- vo$Dataset == "ADSL" & vo$Variable == "SEX"              # untagged manual row
  expect_identical(vo[sex, ], vt[sex, ])
  m <- sheet(out, "Methods")
  expect_equal(m$`Expression Code`[m$ID == "ADAE.AERELFL"], "DO_NOT_CHANGE")
  expect_false(grepl("STALE", m$Description[m$ID == "ADAE.AERELFL"]))
  expect_false("MANUAL.LEGACY" %in% m$ID)                         # KEEPTAGS=N behaviour
})

test_that("--keep-unmatched retains manual Methods/Comments rows", {
  skip_without_repo(); skip_if_not_installed("readxl")
  d <- new_tmp(); out <- file.path(d, "keep.xlsx")
  export_valid(out, keep_unmatched = TRUE)
  expect_true("MANUAL.LEGACY" %in% sheet(out, "Methods")$ID)
  expect_true("COM.MANUAL" %in% sheet(out, "Comments")$ID)
})

test_that("repeated exports from identical inputs are logically equivalent", {
  skip_without_repo(); skip_if_not_installed("readxl")
  d <- new_tmp()
  a <- file.path(d, "a.xlsx"); b <- file.path(d, "b.xlsx")
  export_valid(a); export_valid(b)
  expect_true(workbooks_equivalent(a, b))
  r1 <- run_pipeline(example_path("valid"), example_path("spec.csv"))
  r2 <- run_pipeline(example_path("valid"), example_path("spec.csv"))
  expect_identical(r1$records, r2$records)
  c1 <- file.path(d, "1.csv"); c2 <- file.path(d, "2.csv")
  write_csv_det(r1$records, c1); write_csv_det(r2$records, c2)
  expect_identical(unname(tools::md5sum(c1)), unname(tools::md5sum(c2)))
  # and the comparison really detects a difference
  export_valid(b, keep_unmatched = TRUE)
  expect_false(workbooks_equivalent(a, b))
})

test_that("export refuses to overwrite the template", {
  skip_without_repo()
  res <- run_pipeline(example_path("valid"), example_path("spec.csv"))
  tpl <- example_path("define_like_template.xlsx")
  expect_error(export_defx_workbook(res$records, tpl, tpl), class = "defx_input_error")
})

test_that("V009: a tagged target missing from the template blocks the workbook", {
  skip_without_repo()
  d <- new_tmp(); out <- file.path(d, "x.xlsx")
  # DM.AGE is in the spec (validation scope) but not in the define-like template
  write_src(d, "src/a.R", c("# DEFX | DM.AGE | Predecessor | ADSL.AGE"))
  res <- run_pipeline(file.path(d, "src"), example_path("spec.csv"))
  expect_equal(nrow(errors(res)), 0)
  ex <- export_defx_workbook(res$records, example_path("define_like_template.xlsx"), out)
  expect_null(ex$out)
  expect_equal(ex$diagnostics$code, "V009")
  expect_false(file.exists(out))
  expect_length(list.files(d, pattern = "^\\.defx-"), 0)        # temp file cleaned up
})

test_that("a template without the DEFX sheets is rejected", {
  d <- new_tmp()
  p <- file.path(d, "bad.xlsx")
  wb <- openxlsx::createWorkbook(); openxlsx::addWorksheet(wb, "Datasets")
  openxlsx::writeData(wb, "Datasets", data.frame(Dataset = "ADSL", Comment = NA))
  openxlsx::saveWorkbook(wb, p)
  expect_error(load_template(p), "missing sheet\\(s\\): Variables, Methods, Comments",
               class = "defx_input_error")
})
