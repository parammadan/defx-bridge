/*******************************************************************************
* PROGRAM : makeadae.sas
* PURPOSE : Create a SYNTHETIC adverse-event analysis dataset (ADAE) from AE
*           and ADSL. Illustrative only - no real participant data.
* NOTES   : Documentation tags follow the published DEFX syntax
*           (Bartley & Hinger, PharmaSUG 2026 AP-220). This file was written
*           for DEFX Bridge and is not taken from any production program.
*******************************************************************************/

/* DEFX | ADAE | Comments | Synthetic adverse event analysis dataset; one record per AE */

* Ordinary statement comment: merge AE with subject-level treatment dates;
data adae;
  merge ae (in = inae)
        adsl (keep = usubjid trt01a trtsdt);
  by usubjid;
  if inae;

  /* DEFX | ADAE.USUBJID  | Predecessor | AE.USUBJID  */
  /* DEFX | ADAE.AETERM   | Predecessor | AE.AETERM   */
  /* DEFX | ADAE.AEDECOD  | Predecessor | AE.AEDECOD  */
  /* DEFX | ADAE.AEBODSYS | Predecessor | AE.AEBODSYS */
  /* DEFX | ADAE.AESER    | Predecessor | AE.AESER    */
  /* DEFX | ADAE.AEREL    | Predecessor | AE.AEREL    */
  /* DEFX | ADAE.TRT01A   | Predecessor | ADSL.TRT01A */

  /* DEFX | ADAE.AERELFL | Y if AE.AEREL="RELATED"     */
  /* DEFX | ADAE.AERELFL | N if AE.AEREL="NOT RELATED" */
  /* DEFX | ADAE.AERELFL | otherwise set to missing    */
  length aerelfl $1;
  if upcase(aerel) = "RELATED" then aerelfl = "Y";
  else if upcase(aerel) = "NOT RELATED" then aerelfl = "N";
  /* DEFX | ADAE.AERELFL | Comments | Synthetic example: relatedness as recorded on the CRF */

  /* DEFX | ADAE.AESAECAT | Group by reason for serious adverse event;         */
  /* DEFX | ADAE.AESAECAT | if more than 1 reason, prioritize death, then      */
  /* DEFX | ADAE.AESAECAT | life threatening, then hospitalization, then other */
  length aesaecat $60;
  if aesdth = "Y" then aesaecat = 'Results in Death';
  else if aeslife = 'Y' then aesaecat = 'Is Life Threatening';
  else if aeshosp = 'Y' then aesaecat = 'Requires or Prolongs Hospitalization';
  else if aesmie = 'Y' then aesaecat = 'Other Medically Important Serious Event';

  /* DEFX | ADAE.ASTDT | Imputation | AE.AESTDTC as a SAS date; if only the day is */
  /* DEFX | ADAE.ASTDT | Imputation | missing, impute day 1 of the month (synthetic rule) */
  /* DEFX | ADAE.AENDT | Imputation | AE.AEENDTC as a SAS date; partial dates are not imputed */
  /* DEFX | ADAE.ASTDY | ASTDT - ADSL.TRTSDT + 1 if ASTDT >= ADSL.TRTSDT, else ASTDT - ADSL.TRTSDT */
  /* DEFX | ADAE.TRTEMFL | Y if ASTDT >= ADSL.TRTSDT; otherwise missing */

  /* The string below is deliberately DEFX-like. It is code, not a comment, */
  /* so DEFX Bridge must ignore it (ADAE.NOTAVAR is not in the spec).       */
  length demo_note $80;
  demo_note = "/* DEFX | ADAE.NOTAVAR | inside a string, not a comment */";
  drop demo_note;
run;
