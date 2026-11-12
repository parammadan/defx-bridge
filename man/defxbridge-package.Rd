\name{defxbridge-package}
\alias{defxbridge-package}
\alias{defxbridge}
\alias{defxbridge_main}
\alias{discover_sources}
\alias{extract_sas_tags}
\alias{extract_r_tags}
\alias{parse_defx_tag}
\alias{normalize_defx_metadata}
\alias{load_spec}
\alias{validate_defx_metadata}
\alias{run_pipeline}
\alias{export_defx_workbook}
\alias{verify_export}
\alias{workbook_content}
\alias{workbooks_equivalent}
\alias{write_validation_report}
\title{DEFX Bridge: DEFX documentation tags from SAS and R programs}
\description{Independent prototype inspired by Bartley and Hinger, PharmaSUG 2026 AP-220. Extracts DEFX tags from SAS and R source without executing it, consolidates multi-line tags with line-level provenance, validates them against a specification, and fills a copy of a synthetic define-like workbook. Not affiliated with or endorsed by CBAR or PharmaSUG. See README.md and docs/ in the source repository; the command-line entry point is bin/defxbridge.}
\usage{
defxbridge_main(args = commandArgs(trailingOnly = TRUE))
discover_sources(sources, recursive = TRUE)
extract_sas_tags(path, source_file = basename(path))
extract_r_tags(path, source_file = basename(path))
parse_defx_tag(body)
normalize_defx_metadata(segments, spec = NULL)
load_spec(path)
validate_defx_metadata(records, spec)
run_pipeline(sources, spec_path = NULL, recursive = TRUE)
export_defx_workbook(records, template_path, out_path, keep_unmatched = FALSE)
verify_export(template_path, out_path, touched, sentinel = "DO_NOT_CHANGE")
workbook_content(path)
workbooks_equivalent(a, b)
write_validation_report(path, result, command = "validate", extra = NULL)
}
\arguments{
\item{args}{Command-line arguments.}
\item{sources}{Directories and/or .sas/.R files.}
\item{recursive}{Search sub-directories.}
\item{path}{Path to a source file, specification CSV or workbook.}
\item{source_file}{Provenance label for the file.}
\item{body}{Text of one DEFX comment without comment delimiters.}
\item{segments}{Tag segments from extraction.}
\item{spec}{Specification from load_spec().}
\item{records}{Normalized records.}
\item{spec_path}{Path to the specification CSV.}
\item{template_path}{Define-like template workbook (never modified).}
\item{out_path}{Output workbook path.}
\item{keep_unmatched}{Keep Methods/Comments rows that no tag matches.}
\item{touched}{Row indices targeted by tags.}
\item{sentinel}{Value whose count must not change.}
\item{a}{Workbook path.}
\item{b}{Workbook path.}
\item{result}{run_pipeline() result.}
\item{command}{Command line shown in the report.}
\item{extra}{Extra Markdown lines.}
}
\value{See README.md. defxbridge_main() returns an exit status: 0 success, 2 validation errors, 1 usage or runtime error.}
\keyword{package}
