# Validation engine ------------------------------------------------------------

test_that("V002: unknown target variable is reported with location", {
  d <- new_tmp()
  write_src(d, "u.R", c("# ok", "# DEFX | ADAE.DOESNOTEXIST | Invalid example"))
  res <- run_dir(d, mini_spec(d))
  e <- errors(res)
  expect_equal(e$code, "V002")
  expect_equal(e$source_file, "u.R"); expect_equal(e$source_line, 2L)
  expect_equal(e$name, "ADAE.DOESNOTEXIST")
  expect_match(e$suggestion, "ADAE is a known dataset")
  expect_equal(res$records$status, "error")
})

test_that("V002: unknown dataset and unknown single-name tags", {
  d <- new_tmp()
  write_src(d, "u.sas", c("/* DEFX | ADXX.AGE | x */", "/* DEFX | NOTHING | x */"))
  e <- errors(run_dir(d, mini_spec(d)))
  expect_equal(e$code, c("V002", "V002"))
  expect_match(e$message[2], "matches neither a dataset nor a variable")
})

test_that("V003: the same target in two programs is a conflict, with both locations", {
  d <- new_tmp()
  write_src(d, "conflict/first.sas", c("/* DEFX | ADAE.AERELFL | Y if related */"))
  write_src(d, "conflict/second.R", c("", "# DEFX | ADAE.AERELFL | Y if AEREL == 'RELATED'"))
  e <- errors(run_dir(d, mini_spec(d)))
  expect_equal(e$code, c("V003", "V003"))
  expect_equal(e$source_file, c("conflict/first.sas", "conflict/second.R"))
  expect_equal(e$related, c("conflict/second.R:2", "conflict/first.sas:1"))
})

test_that("V003: different origin types for one target in two programs also conflict", {
  d <- new_tmp()
  write_src(d, "a.sas", "/* DEFX | ADAE.AETERM | Predecessor | AE.AETERM */")
  write_src(d, "b.R", "# DEFX | ADAE.AETERM | Assigned")
  expect_true(all(errors(run_dir(d, mini_spec(d)))$code == "V003"))
})

test_that("V003: comments for the same target in two programs conflict", {
  d <- new_tmp()
  write_src(d, "a.sas", "/* DEFX | ADAE | Comments | one */")
  write_src(d, "b.R", "# DEFX | ADAE | Comments | two")
  expect_equal(errors(run_dir(d, mini_spec(d)))$code, c("V003", "V003"))
})

test_that("no false duplicate for repeated description lines in one program", {
  d <- new_tmp()
  write_src(d, "a.sas", c("/* DEFX | ADAE.AERELFL | Y if related */",
                          "/* DEFX | ADAE.AERELFL | N if not related */",
                          "/* DEFX | ADAE.AERELFL | Otherwise missing */",
                          "/* DEFX | ADAE.ASTDT | Imputation | a */",
                          "/* DEFX | ADAE.ASTDT | Imputation | b */"))
  res <- run_dir(d, mini_spec(d))
  expect_equal(nrow(res$diagnostics), 0)
  expect_equal(nrow(res$records), 2)
})

test_that("Computation and Comments for the same variable coexist", {
  d <- new_tmp()
  write_src(d, "a.sas", c("/* DEFX | ADAE.AERELFL | Y if related */",
                          "/* DEFX | ADAE.AERELFL | Comments | Synthetic example documentation */",
                          "/* DEFX | ADAE.AETERM | Predecessor | AE.AETERM */",
                          "/* DEFX | ADAE.AETERM | Comments | verbatim term */"))
  res <- run_dir(d, mini_spec(d))
  expect_equal(nrow(res$diagnostics), 0)
  expect_equal(res$records$type, c("Computation", "Comments", "Predecessor", "Comments"))
})

test_that("V006: conflicting origins in one program", {
  d <- new_tmp()
  write_src(d, "a.sas", c("/* DEFX | ADAE.AERELFL | Y if related */",
                          "/* DEFX | ADAE.AERELFL | Assigned */"))
  e <- errors(run_dir(d, mini_spec(d)))
  expect_equal(e$code, c("V006", "V006"))
  expect_equal(e$related, c("a.sas:2", "a.sas:1"))
})

test_that("V006: forgetting the type on a continuation line is caught", {
  d <- new_tmp()
  write_src(d, "a.R", c("# DEFX | ADAE.ASTDT | Imputation | first part",
                        "# DEFX | ADAE.ASTDT | second part without the type"))
  e <- errors(run_dir(d, mini_spec(d)))
  expect_equal(unique(e$code), "V006")
  expect_match(e$suggestion[1], "repeat the same type")
})

test_that("V006: variable-only tag overlapping a dataset-specific tag", {
  d <- new_tmp()
  write_src(d, "a.R", c("# DEFX | STUDYID | Assigned", "# DEFX | ADSL.STUDYID | Predecessor | AE.AETERM"))
  e <- errors(run_dir(d, mini_spec(d)))
  expect_equal(e$code, c("V006", "V006"))
})

test_that("variable-only tags validate against all datasets", {
  d <- new_tmp()
  write_src(d, "a.R", c("# DEFX | STUDYID | Assigned", "# DEFX | AGE | Comments | years"))
  res <- run_dir(d, mini_spec(d))
  expect_equal(nrow(res$diagnostics), 0)
  expect_equal(res$records$scope, c("variable_all", "variable_all"))
})

test_that("V001 / V004 / V005: malformed tags are reported, never guessed", {
  d <- new_tmp()
  write_src(d, "m.sas", c(
    "/* DEFX | | no name */",                                         # 1 V001
    "/* DEFX | ADAE.AERELFL */",                                       # 2 V001 no description
    "/* DEFX | ADAE.AERELFL | Y | N | Z */",                           # 3 V001 too many |
    "/* DEFX | ADAE.A,B | comma */",                                   # 4 V001
    "/* DEFX | ADAE.A-B | bad identifier */",                          # 5 V001
    "/* DEFX | A.B.C.D | four parts */",                               # 6 V001
    "/* DEFX | ADAE.AERELFL | Derivation | not a type */",             # 7 V004
    "/* DEFX | ADAE.AERELFL | Assigned | with text */",                # 8 V004
    "/* DEFX | ADAE.AETERM | Predecessor */",                          # 9 V005
    "/* DEFX | ADAE.AETERM | Predecessor | AE AETERM */",              # 10 V005
    "/* DEFX | ADAE.AERELFL | Imputation | */",                        # 11 V001 empty
    "/* DEFX | ADAE | Assigned */",                                    # 12 V004 dataset scope
    "/* DEFX | AVAL.ADVS.PARAMCD.EQ.X | Predecessor | VS.X */",        # 13 V004
    "/* DEFX x | ADAE.AERELFL | text before first pipe */",            # 14 V001
    "/* DEFX\n | ADAE.AERELFL | multi-line */",                        # 15 V001 multi-line block
    "/* DEFX | ADAE.ASTDT | Predecessor | ADAE.ASTDT */"))             # 17 V005 self
  res <- run_dir(d, mini_spec(d))
  e <- errors(res)
  got <- setNames(e$code, e$source_line)
  expect_equal(unname(got[as.character(c(1:6, 11, 14, 15))]), rep("V001", 9))
  expect_equal(unname(got[as.character(c(7, 8, 12, 13))]), rep("V004", 4))
  expect_equal(unname(got[as.character(c(9, 10, 17))]), rep("V005", 3))
  expect_true(all(nzchar(e$suggestion)))
  # malformed tags never become computation descriptions
  expect_false(any(res$records$type == "Computation" & res$records$status == "ok"))
})

test_that("V010 / V012: DEFX-like comments that are not tags are warned, not used", {
  d <- new_tmp()
  write_src(d, "w.sas", c("/* DEFX ADAE.ASTDT missing every delimiter */",
                          "* DEFX | ADAE.ASTDT | statement comment ;"))
  res <- run_dir(d, mini_spec(d))
  expect_equal(res$diagnostics$code, c("V014", "V010", "V012"))  # V014: zero usable tags
  expect_true(all(res$diagnostics$severity == "warning"))
  expect_equal(nrow(res$records), 0)
})

test_that("V005 / V011: predecessor checked against spec only when in scope", {
  d <- new_tmp()
  write_src(d, "p.R", c("# DEFX | ADAE.AETERM | Predecessor | AE.AETERM",
                        "# DEFX | ADSL.AGE | Predecessor | AE.NOPE",
                        "# DEFX | ADAE.STUDYID | Predecessor | EXTERNAL.STUDYID"))
  res <- run_dir(d, mini_spec(d))
  expect_equal(res$diagnostics$code, c("V005", "V011"))
  expect_equal(res$diagnostics$severity, c("error", "info"))
  expect_equal(res$records$status, c("ok", "error", "ok"))
})

test_that("parameter-level AVAL/PARAMCD methods validate their dataset/variable", {
  d <- new_tmp()
  write_src(d, "v.R", c("# DEFX | AVAL.ADVS.PARAMCD.EQ.SYSBP | VS.VSSTRESN where SYSBP",
                        "# DEFX | ADVS.AVAL.PULSE | VS.VSSTRESN where PULSE",
                        "# DEFX | AVAL.ADXX.PARAMCD.EQ.X | unknown dataset"))
  res <- run_dir(d, mini_spec(d))
  expect_equal(res$records$scope, rep("parameter", 3))
  expect_equal(res$records$dataset, c("ADVS", "ADVS", "ADXX"))
  expect_equal(res$records$parameter, c("SYSBP", "PULSE", "X"))
  expect_equal(errors(res)$code, "V002")
  expect_equal(errors(res)$source_line, 3L)
})

test_that("identifier casing is normalized consistently in tags and spec", {
  d <- new_tmp()
  sp <- file.path(d, "spec.csv")
  writeLines(c("dataset,variable,Label", "adae , aerelfl,flag"), sp)
  write_src(d, "a.R", "# DEFX | Adae.AeRelFl | y")
  res <- run_dir(file.path(d, "a.R"), sp)
  expect_equal(nrow(res$diagnostics), 0)
  expect_equal(res$records$name, "ADAE.AERELFL")
})

test_that("V007: missing or invalid specifications fail clearly", {
  d <- new_tmp()
  write_src(d, "a.R", "# DEFX | ADAE.AERELFL | y")
  expect_error(run_dir(d, file.path(d, "missing.csv")), "V007 specification not found",
               class = "defx_input_error")
  writeLines(c("Domain,Var", "ADAE,X"), f <- file.path(d, "cols.csv"))
  expect_error(run_dir(d, f), "must have columns Dataset and Variable", class = "defx_input_error")
  writeLines("Dataset,Variable", f2 <- file.path(d, "empty.csv"))
  expect_error(run_dir(d, f2), "has no rows", class = "defx_input_error")
  writeLines(c("Dataset,Variable", "ADAE,", "ADAE,OK"), f3 <- file.path(d, "blank.csv"))
  expect_error(run_dir(d, f3), "blank or invalid Dataset/Variable on data row\\(s\\) 1",
               class = "defx_input_error")
})

test_that("empty and missing source locations are handled", {
  d <- new_tmp()
  expect_error(run_dir(file.path(d, "nope")), "source path does not exist",
               class = "defx_input_error")
  dir.create(file.path(d, "empty"))
  expect_error(run_dir(file.path(d, "empty")), "no .sas, .R or .r programs found",
               class = "defx_input_error")
  write_src(d, "notags/a.R", "x <- 1")
  res <- run_dir(file.path(d, "notags"))
  expect_equal(res$diagnostics$code, "V014")
  expect_equal(res$diagnostics$severity, "warning")
  expect_equal(nrow(res$records), 0)
})

test_that("paths containing spaces and punctuation work", {
  d <- new_tmp()
  write_src(d, "My Programs (v2)/make adae & co.sas", "/* DEFX | ADAE.AERELFL | Y */")
  res <- run_dir(file.path(d, "My Programs (v2)"), mini_spec(d))
  expect_equal(res$records$source_file, "make adae & co.sas")
  expect_equal(nrow(res$diagnostics), 0)
})

test_that("the shipped valid example validates cleanly; invalid example fails", {
  skip_without_repo()
  ok <- run_pipeline(example_path("valid"), example_path("spec.csv"))
  expect_equal(nrow(ok$diagnostics), 0)
  expect_setequal(unique(ok$records$language), c("SAS", "R"))
  bad <- run_pipeline(example_path("invalid"), example_path("spec.csv"))
  expect_true(all(c("V001", "V002", "V003", "V004", "V005", "V006") %in% codes(bad)))
})
