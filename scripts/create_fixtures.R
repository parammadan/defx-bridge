# Regenerates examples/spec.csv and examples/define_like_template.xlsx.
# Run from the repository root:  Rscript scripts/create_fixtures.R
#
# ALL CONTENT IS SYNTHETIC. The workbook imitates the general shape of a
# define.xlsx (Datasets / Variables / Methods / Comments) but is NOT a
# Pinnacle 21 template and has not been validated against one.
suppressPackageStartupMessages(library(openxlsx))

v <- function(ds, var, label, type = "text", len = 8, codelist = NA, origin = NA,
              pred = NA, method = NA, comment = NA, notes = NA)
  data.frame(Dataset = ds, Variable = var, Label = label, `Data Type` = type,
             Length = len, Codelist = codelist, Origin = origin, Predecessor = pred,
             Method = method, Comment = comment, `Developer Notes` = notes,
             check.names = FALSE, stringsAsFactors = FALSE)

adam <- rbind(
  v("ADSL", "STUDYID", "Study Identifier", len = 12),
  v("ADSL", "USUBJID", "Unique Subject Identifier", len = 20),
  v("ADSL", "SUBJID",  "Subject Identifier for the Study"),
  v("ADSL", "SITEID",  "Study Site Identifier"),
  v("ADSL", "AGE",     "Age", "integer", 3),
  v("ADSL", "AGEGR1",  "Pooled Age Group 1", len = 5, codelist = "AGEGR1"),
  v("ADSL", "SEX",     "Sex", len = 1, codelist = "SEX", origin = "Predecessor",
    pred = "DM.SEX", notes = "manually entered - no DEFX tag; must survive export"),
  v("ADSL", "RACE",    "Race", len = 40, codelist = "RACE"),
  v("ADSL", "TRT01P",  "Planned Treatment for Period 01", len = 20),
  v("ADSL", "TRT01A",  "Actual Treatment for Period 01", len = 20),
  v("ADSL", "TRTSDT",  "Date of First Exposure to Treatment", "integer", 8),
  v("ADSL", "TRTEDT",  "Date of Last Exposure to Treatment", "integer", 8),
  v("ADSL", "SAFFL",   "Safety Population Flag", len = 1, codelist = "NY"),
  v("ADSL", "ITTFL",   "Intent-To-Treat Population Flag", len = 1, codelist = "NY",
    notes = "DO_NOT_CHANGE"),
  v("ADAE", "STUDYID", "Study Identifier", len = 12),
  v("ADAE", "USUBJID", "Unique Subject Identifier", len = 20),
  v("ADAE", "AESEQ",   "Sequence Number", "integer", 4, origin = "Predecessor",
    pred = "AE.AESEQ", notes = "manually entered - no DEFX tag; must survive export"),
  v("ADAE", "AETERM",  "Reported Term for the Adverse Event", len = 200),
  v("ADAE", "AEDECOD", "Dictionary-Derived Term", len = 200),
  v("ADAE", "AEBODSYS","Body System or Organ Class", len = 200),
  v("ADAE", "AESER",   "Serious Event", len = 1, codelist = "NY"),
  v("ADAE", "AEREL",   "Causality", len = 20),
  v("ADAE", "AERELFL", "Related Flag (synthetic)", len = 1, codelist = "NY",
    origin = "Assigned", notes = "stale Origin on purpose: DEFX should replace it"),
  v("ADAE", "AESAECAT","Serious Event Category (synthetic)", len = 60),
  v("ADAE", "ASTDT",   "Analysis Start Date", "integer", 8),
  v("ADAE", "AENDT",   "Analysis End Date", "integer", 8),
  v("ADAE", "ASTDY",   "Analysis Start Relative Day", "integer", 8),
  v("ADAE", "TRTEMFL", "Treatment Emergent Analysis Flag", len = 1, codelist = "NY",
    notes = "DO_NOT_CHANGE"),
  v("ADAE", "TRT01A",  "Actual Treatment for Period 01", len = 20),
  v("ADVS", "STUDYID", "Study Identifier", len = 12),
  v("ADVS", "USUBJID", "Unique Subject Identifier", len = 20),
  v("ADVS", "PARAMCD", "Parameter Code", len = 8, codelist = "PARAMCD"),
  v("ADVS", "PARAM",   "Parameter", len = 40),
  v("ADVS", "AVAL",    "Analysis Value", "float", 8),
  v("ADVS", "ADT",     "Analysis Date", "integer", 8),
  v("ADVS", "AVISIT",  "Analysis Visit", len = 20)
)
adam$Order <- ave(seq_len(nrow(adam)), adam$Dataset, FUN = seq_along)
adam <- adam[, c("Order", setdiff(names(adam), "Order"))]

# SDTM-like source datasets: in the validation scope (so explicit Predecessor
# references can be verified) but not part of the define-like workbook.
sdtm <- rbind(
  data.frame(Dataset = "DM", Variable = c("STUDYID", "USUBJID", "SUBJID", "SITEID", "AGE",
                                          "SEX", "RACE", "ARM", "ACTARM", "RFXSTDTC")),
  data.frame(Dataset = "AE", Variable = c("STUDYID", "USUBJID", "AESEQ", "AETERM", "AEDECOD",
                                          "AEBODSYS", "AESER", "AEREL", "AESTDTC", "AEENDTC",
                                          "AESDTH", "AESLIFE", "AESHOSP", "AESMIE")),
  data.frame(Dataset = "VS", Variable = c("STUDYID", "USUBJID", "VSTESTCD", "VSTEST",
                                          "VSSTRESN", "VSDTC", "VISIT")),
  data.frame(Dataset = "EX", Variable = c("USUBJID", "EXSTDTC", "EXENDTC", "EXDOSE"))
)

spec <- rbind(adam[, c("Dataset", "Variable")], sdtm)
write.csv(spec, "examples/spec.csv", row.names = FALSE, quote = FALSE)

datasets <- data.frame(
  Dataset = c("ADSL", "ADAE", "ADVS"),
  Description = c("Subject-Level Analysis Dataset", "Adverse Events Analysis Dataset",
                  "Vital Signs Analysis Dataset"),
  Class = c("SUBJECT LEVEL ANALYSIS DATASET", "OCCURRENCE DATA STRUCTURE",
            "BASIC DATA STRUCTURE"),
  Structure = c("One record per subject", "One record per adverse event",
                "One record per subject per parameter per visit"),
  `Key Variables` = c("STUDYID, USUBJID", "STUDYID, USUBJID, AESEQ",
                      "STUDYID, USUBJID, PARAMCD, AVISIT"),
  Comment = NA_character_,
  `Developer Notes` = c(NA, "DO_NOT_CHANGE", NA),
  check.names = FALSE, stringsAsFactors = FALSE)

methods <- data.frame(
  ID = c("ADAE.AERELFL", "MANUAL.LEGACY"),
  Name = c("ADAE.AERELFL", "MANUAL.LEGACY"),
  Type = c("Computation", "Computation"),
  Description = c("STALE draft text typed by hand - DEFX should replace it",
                  "Manually entered method with no DEFX tag"),
  `Expression Context` = c("SAS 9.4", NA),
  `Expression Code` = c("DO_NOT_CHANGE", NA),
  Document = NA_character_, Pages = NA_character_,
  check.names = FALSE, stringsAsFactors = FALSE)

comments <- data.frame(ID = "COM.MANUAL", Description = "Manually entered comment with no DEFX tag",
                       Document = NA_character_, Pages = NA_character_,
                       stringsAsFactors = FALSE)

study <- data.frame(Attribute = c("StudyName", "StudyDescription", "ProtocolName", "Note"),
                    Value = c("SYNTHETIC-001", "Synthetic study for DEFX Bridge demos",
                              "SYN-001", "NOT a Pinnacle 21 template; synthetic data only"))

preserve <- data.frame(Key = c("sentinel", "number", "date_text", "unicode"),
                       Value = c("DO_NOT_CHANGE", "42", "2026-11-13", "µg/mL ≤ 5"),
                       stringsAsFactors = FALSE)

wb <- createWorkbook(creator = "DEFX Bridge fixtures")
hs <- createStyle(textDecoration = "bold", fgFill = "#DDEBF7")
add <- function(name, df) {
  addWorksheet(wb, name)
  writeData(wb, name, df, headerStyle = hs, keepNA = FALSE)
  setColWidths(wb, name, cols = seq_len(ncol(df)), widths = "auto")
}
add("Study", study)
add("Datasets", datasets)
add("Variables", adam)
add("Methods", methods)
add("Comments", comments)
add("PreserveMe", preserve)
saveWorkbook(wb, "examples/define_like_template.xlsx", overwrite = TRUE)
cat(sprintf("wrote examples/spec.csv (%d rows) and examples/define_like_template.xlsx\n",
            nrow(spec)))
