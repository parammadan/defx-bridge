# ------------------------------------------------------------------------------
# PROGRAM : makeadvs.R
# PURPOSE : Create a SYNTHETIC vital-signs analysis dataset (ADVS) in R.
#           Demonstrates parameter-level (AVAL by PARAMCD) DEFX methods.
#           Illustrative only - no real participant data.
# ------------------------------------------------------------------------------

# DEFX | ADVS | Comments | Synthetic vital signs analysis dataset; one record per subject, parameter and visit

make_advs <- function(vs) {
  # DEFX | ADVS.USUBJID | Predecessor | VS.USUBJID
  # DEFX | ADVS.PARAMCD | Predecessor | VS.VSTESTCD
  # DEFX | ADVS.PARAM   | Predecessor | VS.VSTEST
  # DEFX | ADVS.AVISIT  | Predecessor | VS.VISIT
  advs <- data.frame(STUDYID = vs$STUDYID, USUBJID = vs$USUBJID,
                     PARAMCD = vs$VSTESTCD, PARAM = vs$VSTEST, AVISIT = vs$VISIT)

  # DEFX | ADVS.AVAL | VS.VSSTRESN; see the parameter-level methods for each PARAMCD
  # DEFX | AVAL.ADVS.PARAMCD.EQ.SYSBP | VS.VSSTRESN where VS.VSTESTCD = "SYSBP" (mmHg)
  # DEFX | AVAL.ADVS.PARAMCD.EQ.DIABP | VS.VSSTRESN where VS.VSTESTCD = "DIABP" (mmHg)
  # DEFX | ADVS.AVAL.PULSE | VS.VSSTRESN where VS.VSTESTCD = "PULSE" (beats/min)
  advs$AVAL <- vs$VSSTRESN

  # DEFX | ADVS.ADT | Imputation | VS.VSDTC as a date; time part dropped; no imputation of missing days
  advs$ADT <- as.Date(substr(vs$VSDTC, 1, 10))
  advs
}
