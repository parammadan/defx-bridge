# Regenerates man/defxbridge-package.Rd with usage taken from the real function
# signatures (run from the repository root: Rscript scripts/make_rd.R).
env <- new.env()
for (f in sort(list.files("R", full.names = TRUE))) sys.source(f, env)
ex <- sub("^export\\((.*)\\)$", "\\1", grep("^export\\(", readLines("NAMESPACE"), value = TRUE))
us <- vapply(ex, function(f) {
  a <- deparse(args(env[[f]]))
  a <- paste(trimws(a[-length(a)]), collapse = " ")
  sub("^function ", f, a)
}, "")
argdoc <- c(
  sources = "Directories and/or .sas/.R files.",
  path = "Path to a source file, specification CSV or workbook.",
  source_file = "Provenance label for the file.",
  body = "Text of one DEFX comment without comment delimiters.",
  segments = "Tag segments from extraction.", spec = "Specification from load_spec().",
  records = "Normalized records.", spec_path = "Path to the specification CSV.",
  template_path = "Define-like template workbook (never modified).",
  out_path = "Output workbook path.",
  keep_unmatched = "Keep Methods/Comments rows that no tag matches.",
  touched = "Row indices targeted by tags.", sentinel = "Value whose count must not change.",
  a = "Workbook path.", b = "Workbook path.", result = "run_pipeline() result.",
  command = "Command line shown in the report.", extra = "Extra Markdown lines.",
  args = "Command-line arguments.")
argdoc[["recursive"]] <- "Search sub-directories."  # not inside c(): c() has its own recursive argument
used <- unique(unlist(lapply(ex, function(f) names(formals(env[[f]])))))
missing <- setdiff(used, names(argdoc))
if (length(missing)) stop("document these arguments: ", paste(missing, collapse = ", "))
rd <- c("\\name{defxbridge-package}", "\\alias{defxbridge-package}", "\\alias{defxbridge}",
        paste0("\\alias{", ex, "}"),
        "\\title{DEFX Bridge: DEFX documentation tags from SAS and R programs}",
        paste("\\description{Independent prototype inspired by Bartley and Hinger, PharmaSUG 2026",
              "AP-220. Extracts DEFX tags from SAS and R source without executing it, consolidates",
              "multi-line tags with line-level provenance, validates them against a specification,",
              "and fills a copy of a synthetic define-like workbook. Not affiliated with or endorsed",
              "by CBAR or PharmaSUG. See README.md and docs/ in the source repository; the",
              "command-line entry point is bin/defxbridge.}"),
        "\\usage{", us, "}",
        "\\arguments{", sprintf("\\item{%s}{%s}", used, argdoc[used]), "}",
        paste("\\value{See README.md. defxbridge_main() returns an exit status: 0 success,",
              "2 validation errors, 1 usage or runtime error.}"),
        "\\keyword{package}")
dir.create("man", showWarnings = FALSE)
writeLines(rd, "man/defxbridge-package.Rd")
cat("wrote man/defxbridge-package.Rd for", length(ex), "functions\n")
