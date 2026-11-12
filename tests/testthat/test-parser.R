# Extraction, parsing, normalization ------------------------------------------

test_that("SAS tags are extracted with name, type, description and line", {
  d <- new_tmp()
  p <- write_src(d, "makeadae.sas", c(
    "data adae; set ae;",
    "/* DEFX | ADAE.AERELFL | Y if AE.AEREL=\"RELATED\" */",
    "/* DEFX | ADAE.ASTDT | Imputation | day 1 imputed */",
    "run;"))
  s <- extract_sas_tags(p)$segments
  expect_equal(nrow(s), 2)
  expect_equal(s$name, c("ADAE.AERELFL", "ADAE.ASTDT"))
  expect_equal(s$type, c("Computation", "Imputation"))
  expect_equal(s$description, c("Y if AE.AEREL=\"RELATED\"", "day 1 imputed"))
  expect_equal(s$source_line, c(2L, 3L))
  expect_equal(s$language, c("SAS", "SAS"))
  expect_equal(s$raw_tag[1], "/* DEFX | ADAE.AERELFL | Y if AE.AEREL=\"RELATED\" */")
})

test_that("R tags are extracted, including trailing comments after code", {
  d <- new_tmp()
  p <- write_src(d, "makeadsl.R", c(
    "# DEFX | ADAE.AERELFL | Y if AE.AEREL=\"RELATED\"",
    "x <- 1  # DEFX | ADSL.AGE | Predecessor | DM.AGE",
    "#' DEFX | ADAE.ASTDT | Imputation | roxygen-style comment"))
  s <- extract_r_tags(p)$segments
  expect_equal(s$name, c("ADAE.AERELFL", "ADSL.AGE", "ADAE.ASTDT"))
  expect_equal(s$type, c("Computation", "Predecessor", "Imputation"))
  expect_equal(s$source_line, 1:3)
  expect_equal(unique(s$language), "R")
})

test_that("equivalent SAS and R tags normalize to the same schema", {
  tags <- c("DEFX | ADAE.AERELFL | Y if related", "DEFX | ADAE.AERELFL | N otherwise",
            "DEFX | ADAE.AETERM | Predecessor | AE.AETERM",
            "DEFX | ADAE.PARAMCD | Assigned",
            "DEFX | ADAE.ASTDT | Imputation | first of month",
            "DEFX | ADAE.AERELFL | Comments | synthetic note",
            "DEFX | ADAE | Comments | dataset note",
            "DEFX | STUDYID | Assigned")
  d1 <- new_tmp(); d2 <- file.path(d1, "r"); dir.create(d2); d1s <- file.path(d1, "sas"); dir.create(d1s)
  write_src(d1s, "x.sas", paste0("/* ", tags, " */"))
  write_src(d2, "x.R", paste0("# ", tags))
  spec <- load_spec(mini_spec(d1))
  ns <- normalize_defx_metadata(extract_sas_tags(file.path(d1s, "x.sas"))$segments, spec)
  nr <- normalize_defx_metadata(extract_r_tags(file.path(d2, "x.R"))$segments, spec)
  drop <- c("source_file", "language", "raw_tag")
  expect_equal(nrow(ns), 7)
  expect_identical(ns[, setdiff(names(ns), drop)], nr[, setdiff(names(nr), drop)])
  expect_equal(unique(ns$language), "SAS"); expect_equal(unique(nr$language), "R")
})

test_that("tag classification: computation, imputation, predecessor, assigned", {
  expect_equal(parse_defx_tag(" DEFX | adae.aerelfl | Y if related ")$type, "Computation")
  expect_equal(parse_defx_tag("DEFX | ADAE.X | computation | explicit")$type, "Computation")
  p <- parse_defx_tag("DEFX | ADAE.ASTDT | Imputation | Derived using documented imputation rule")
  expect_equal(p[c("type", "description")], list(type = "Imputation",
                                                  description = "Derived using documented imputation rule"))
  p <- parse_defx_tag("DEFX | ADAE.AETERM | Predecessor | AE.AETERM")
  expect_equal(p$type, "Predecessor"); expect_equal(p$description, "AE.AETERM")
  p <- parse_defx_tag("defx|ADAE.PARAMCD|assigned")
  expect_equal(p$type, "Assigned"); expect_equal(p$description, "")
  expect_equal(p$name, "ADAE.PARAMCD")
})

test_that("normalized origins follow type", {
  d <- new_tmp()
  write_src(d, "a.R", c("# DEFX | ADAE.AERELFL | Y", "# DEFX | ADAE.ASTDT | Imputation | x",
                        "# DEFX | ADAE.AETERM | Predecessor | AE.AETERM",
                        "# DEFX | ADAE.PARAMCD | Assigned",
                        "# DEFX | ADAE.AERELFL | Comments | c"))
  r <- run_dir(d)$records
  expect_equal(r$origin, c("Derived", "Derived", "Predecessor", "Assigned", ""))
  expect_equal(r$predecessor[3], "AE.AETERM"); expect_equal(r$description[3], "")
})

test_that("variable and dataset comments resolve with a specification", {
  d <- new_tmp()
  write_src(d, "a.sas", c("/* DEFX | ADAE.AERELFL | Comments | Synthetic example documentation */",
                          "/* DEFX | ADAE | Comments | Synthetic adverse event analysis dataset */",
                          "/* DEFX | STUDYID | Assigned */"))
  res <- run_dir(d, mini_spec(d))
  r <- res$records
  expect_equal(r$scope, c("dataset_variable", "dataset", "variable_all"))
  expect_equal(r$type, c("Comments", "Comments", "Assigned"))
  expect_equal(r$dataset[2], "ADAE"); expect_equal(r$variable[3], "STUDYID")
  expect_equal(nrow(errors(res)), 0)
  # without a spec a single name is reported as unresolved, not guessed
  expect_equal(run_dir(d)$records$scope[2], "dataset_or_variable")
})

test_that("multiline descriptions consolidate into one record in source order", {
  d <- new_tmp()
  write_src(d, "a.sas", c("/* DEFX | ADAE.AERELFL | Y if related */",
                          "/* DEFX | ADAE.AERELFL | N if not related */",
                          "/* DEFX | ADAE.AERELFL | Otherwise missing */"))
  res <- run_dir(d, mini_spec(d))
  expect_equal(nrow(res$records), 1)
  r <- res$records
  expect_equal(r$description, "Y if related N if not related Otherwise missing")
  expect_equal(r$source_lines, "1;2;3"); expect_equal(r$source_line, 1L)
  expect_equal(r$segment_count, 3L)
  expect_equal(strsplit(r$raw_tag, "\n")[[1]],
               c("/* DEFX | ADAE.AERELFL | Y if related */",
                 "/* DEFX | ADAE.AERELFL | N if not related */",
                 "/* DEFX | ADAE.AERELFL | Otherwise missing */"))
  expect_equal(nrow(res$diagnostics), 0)   # NOT a duplicate
})

test_that("non-contiguous segments keep original source order", {
  d <- new_tmp()
  write_src(d, "a.R", c("# DEFX | ADAE.ASTDT | Imputation | first",
                        "x <- 1", "# DEFX | ADAE.AERELFL | other target", "y <- 2",
                        "# DEFX | ADAE.ASTDT | Imputation | second",
                        "# DEFX | ADAE.ASTDT | Imputation | third"))
  r <- run_dir(d)$records
  a <- r[r$name == "ADAE.ASTDT", ]
  expect_equal(a$description, "first second third")
  expect_equal(a$source_lines, "1;5;6")
  expect_equal(r$name, c("ADAE.ASTDT", "ADAE.AERELFL"))  # first-appearance order
})

test_that("the paper's long AESAECAT example consolidates to one method", {
  d <- new_tmp()
  body <- c("Group by reason for serious adverse event;",
            "if participant has more than 1 reason,",
            "then prioritize by death, life threatening,", "hospitalization, other:",
            "if AE.AESDTH=\"Y\" then", "AESAECAT='Results in Death';",
            "else if AE.AESLIFE='Y' then", "AESAECAT='Is Life Threatening';")
  write_src(d, "a.sas", sprintf("/* DEFX | ADAE.AESAECAT | %-50s */", body))
  r <- run_dir(d)$records
  expect_equal(nrow(r), 1)
  expect_equal(r$description, paste(body, collapse = " "))
})

test_that("provenance: relative file paths and line numbers across folders", {
  d <- new_tmp()
  write_src(d, "sub dir/b.sas", c("", "", "/* DEFX | ADAE.AERELFL | Y */"))
  write_src(d, "a.R", c("# header", "# DEFX | ADSL.AGE | Predecessor | DM.AGE"))
  res <- run_dir(d)
  expect_equal(res$records$source_file, c("a.R", "sub dir/b.sas"))
  expect_equal(res$records$source_line, c(2L, 3L))
  expect_equal(res$records$language, c("R", "SAS"))
})

test_that("ordinary comments and non-tag DEFX mentions are ignored", {
  d <- new_tmp()
  write_src(d, "a.sas", c("/* ordinary comment */", "/* see the DEFX | README */",
                          "* statement comment;", "/* DEFXIT | not a tag */",
                          "/* run defxit later */"))
  write_src(d, "b.R", c("# ordinary", "# uses DEFX | tags", "x <- 1 # DEFXIT"))
  res <- run_dir(d)
  expect_equal(nrow(res$records), 0)
  expect_equal(nrow(res$segments), 0)
  expect_false(any(res$diagnostics$code %in% c("V001", "V010")))
})

test_that("DEFX-like text inside strings is ignored (SAS and R)", {
  d <- new_tmp()
  write_src(d, "a.sas", c(
    "x = \"/* DEFX | ADAE.FAKE1 | in double quotes */\";",
    "y = '/* DEFX | ADAE.FAKE2 | in single quotes */';",
    "z = 'it''s /* DEFX | ADAE.FAKE3 | doubled quote */';",
    "w = \"multi",
    "/* DEFX | ADAE.FAKE4 | inside a multi-line string */",
    "\";",
    "/* DEFX | ADAE.REAL | the only real tag */"))
  write_src(d, "b.R", c(
    "a <- \"# DEFX | ADSL.FAKE5 | double\"",
    "b <- '# DEFX | ADSL.FAKE6 | single'",
    "c <- \"escaped \\\" # DEFX | ADSL.FAKE7 | still a string\"",
    "e <- r\"(# DEFX | ADSL.FAKE8 | raw string)\"",
    "f <- \"multi",
    "# DEFX | ADSL.FAKE9 | inside multi-line string",
    "\"",
    "# DEFX | ADSL.REAL | the only real R tag"))
  res <- run_dir(d)
  expect_setequal(res$records$name, c("ADAE.REAL", "ADSL.REAL"))
  expect_equal(nrow(errors(res)), 0)
})

test_that("SAS DATALINES blocks are not scanned for comments", {
  d <- new_tmp()
  write_src(d, "a.sas", c("data x; input t $40.; datalines;",
                          "/* DEFX | ADAE.FAKE | raw data line */",
                          ";", "run;",
                          "data y; input t $40.; datalines4;",
                          "a;b /* DEFX | ADAE.FAKE2 | raw */", ";;;;",
                          "/* DEFX | ADAE.REAL | after the data */"))
  r <- run_dir(d)$records
  expect_equal(r$name, "ADAE.REAL")
  expect_equal(r$source_line, 8L)
})

test_that("whitespace and case variation are normalized; descriptions are kept intact", {
  long <- paste(rep("abc;def*ghi \"q\" 'q' (x) <= 5 µg ", 60), collapse = "")
  d <- new_tmp()
  write_src(d, "a.sas", c("/*defx|adae.aerelfl|Y*/",
                          "/*   DeFx   |   Adae.Astdt   |   IMPUTATION   |   keep   inner   spaces   */",
                          sprintf("/* DEFX | ADAE.AETERM | %s */", long),
                          "/* DEFX | ADAE.X1 | one */ /* DEFX | ADAE.X2 | two on the same line */"))
  r <- run_dir(d)$records
  expect_equal(r$name, c("ADAE.AERELFL", "ADAE.ASTDT", "ADAE.AETERM", "ADAE.X1", "ADAE.X2"))
  expect_equal(r$type[2], "Imputation")
  expect_equal(r$description[2], "keep   inner   spaces")
  expect_equal(r$description[3], trimws(long))
  expect_equal(nchar(r$description[3]), nchar(trimws(long)))
  expect_equal(r$source_line[4:5], c(4L, 4L))
})

test_that("source code is never executed", {
  d <- new_tmp()
  marker <- file.path(d, "EXECUTED")
  write_src(d, "evil.R", c(sprintf("file.create(%s)", deparse(marker)),
                           "stop('this must not run')",
                           "# DEFX | ADSL.AGE | system('touch /tmp/x') is just text"))
  res <- run_dir(d)
  expect_false(file.exists(marker))
  expect_equal(res$records$description, "system('touch /tmp/x') is just text")
})

test_that("unparseable files produce V008 instead of guesses", {
  d <- new_tmp()
  write_src(d, "bad.R", c("# DEFX | ADSL.AGE | ok", "x <- (", "y <- 2"))
  write_src(d, "bad.sas", c("/* DEFX | ADAE.ASTDT | ok */", "/* never closed"))
  res <- run_dir(d)
  v8 <- res$diagnostics[res$diagnostics$code == "V008", ]
  expect_equal(sort(v8$source_file), c("bad.R", "bad.sas"))
  expect_true(all(v8$severity == "error"))
  expect_equal(v8$source_line[v8$source_file == "bad.sas"], 2L)
  # tags before the SAS problem are kept; R file yields nothing (parser failed)
  expect_equal(res$records$name, "ADAE.ASTDT")
})

test_that("files are processed in a stable, deterministic order", {
  d <- new_tmp()
  for (f in c("b.sas", "A.R", "a.sas", "c/z.R", "B.r"))
    write_src(d, f, sprintf("%s DEFX | ADAE.X%d | t %s", if (grepl("sas$", f)) "/*" else "#",
                            nchar(f), if (grepl("sas$", f)) "*/" else ""))
  s1 <- discover_sources(d); s2 <- discover_sources(d)
  expect_identical(s1, s2)
  expect_equal(s1$source_file, c("A.R", "B.r", "a.sas", "b.sas", "c/z.R"))
  expect_equal(s1$language, c("R", "R", "SAS", "SAS", "R"))
})
