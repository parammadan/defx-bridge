# ------------------------------------------------------------------------------
# PROGRAM : makeadsl.R
# PURPOSE : Create a SYNTHETIC subject-level analysis dataset (ADSL) in R.
#           Illustrative only - no real participant data.
# NOTES   : Uses the same DEFX tag syntax as the SAS programs, written as R
#           comments. DEFX Bridge reads these comments without running the code.
# ------------------------------------------------------------------------------

# DEFX | ADSL | Comments | Synthetic subject-level analysis dataset; one record per subject
# DEFX | STUDYID | Assigned

make_adsl <- function(dm, ex) {
  adsl <- dm[, c("STUDYID", "USUBJID", "SUBJID", "SITEID", "AGE", "SEX", "RACE", "ARM", "ACTARM")]
  # DEFX | ADSL.USUBJID | Predecessor | DM.USUBJID
  # DEFX | ADSL.SUBJID  | Predecessor | DM.SUBJID
  # DEFX | ADSL.SITEID  | Predecessor | DM.SITEID
  # DEFX | ADSL.AGE     | Predecessor | DM.AGE
  # DEFX | ADSL.RACE    | Predecessor | DM.RACE

  # DEFX | ADSL.AGEGR1 | "<65" if AGE < 65;
  # DEFX | ADSL.AGEGR1 | ">=65" if AGE >= 65;
  # DEFX | ADSL.AGEGR1 | missing if AGE is missing
  adsl$AGEGR1 <- ifelse(is.na(adsl$AGE), NA_character_,
                        ifelse(adsl$AGE < 65, "<65", ">=65"))

  # DEFX | ADSL.TRT01P | DM.ARM
  # DEFX | ADSL.TRT01A | DM.ACTARM
  adsl$TRT01P <- adsl$ARM
  adsl$TRT01A <- adsl$ACTARM

  # DEFX | ADSL.TRTSDT | Imputation | earliest EX.EXSTDTC as a date; if only the day is
  # DEFX | ADSL.TRTSDT | Imputation | missing, impute day 1 of the month (synthetic rule)
  # DEFX | ADSL.TRTEDT | Imputation | latest EX.EXENDTC as a date; partial dates are not imputed
  first_dose <- tapply(as.Date(ex$EXSTDTC), ex$USUBJID, min)
  last_dose  <- tapply(as.Date(ex$EXENDTC), ex$USUBJID, max)
  adsl$TRTSDT <- as.Date(first_dose[adsl$USUBJID])
  adsl$TRTEDT <- as.Date(last_dose[adsl$USUBJID])

  # DEFX | ADSL.SAFFL | Y if the participant received any dose (EX.EXDOSE > 0); otherwise N
  dosed <- unique(ex$USUBJID[ex$EXDOSE > 0])
  adsl$SAFFL <- ifelse(adsl$USUBJID %in% dosed, "Y", "N")

  # DEFX | ADSL.ITTFL | Y if DM.ARM is not missing; otherwise N
  # DEFX | ADSL.ITTFL | Comments | Synthetic definition of the intent-to-treat population
  adsl$ITTFL <- ifelse(is.na(adsl$ARM) | adsl$ARM == "", "N", "Y")

  # This string is deliberately DEFX-like. It is code, not a comment, so
  # this tool must ignore it (ADSL.NOTAVAR is not in the spec).
  demo_note <- "# DEFX | ADSL.NOTAVAR | inside a string, not a comment"

  adsl[, setdiff(names(adsl), c("ARM", "ACTARM"))]
}
