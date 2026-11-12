/* SYNTHETIC invalid example: ADAE.AERELFL is also defined in second.R */
/* DEFX | ADAE.AERELFL | Y if AE.AEREL="RELATED"; otherwise missing */
data adae; set ae; if aerel = "RELATED" then aerelfl = "Y"; run;
