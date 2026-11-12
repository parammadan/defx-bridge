# SYNTHETIC invalid example: ADAE.AERELFL is also defined in first.sas
# DEFX | ADAE.AERELFL | "Y" when AE.AEREL == "RELATED", else "N"
adae$AERELFL <- ifelse(adae$AEREL == "RELATED", "Y", "N")
