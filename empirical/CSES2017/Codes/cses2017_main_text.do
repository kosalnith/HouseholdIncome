/*******************************

shiw_main_text.do

created 2 October 2021  
last modified 2 October 2021

Written by Nith Kosal and Phay Thunnimith 

INPUTS: 

1) CSES2017.dta (from cses2017_rawdata.do)

OVERVIEW:

(1) Construct exposure measures: URE, NNP, INC -- program: CSES2017_exp declared in cses2017_aux.do
(2) Summary statistics 
(3) Graph of average MPC in each bin of URE, NNP, INC
(4) Report moments of URE, NNP, INC
(5) Sensitivity with respect to duration for URE 
(6) Covariance decomposition


NOTE:

*** Change the path in the "home" global to run this code

********************************/

macro drop _all 
capture program drop mpcest
capture program drop redplot
capture program drop redmoments

clear
set more off
set graphics on
capture log close 

*Paths for data and results

global home "/Users/nithkosal/Dropbox/Research Projects/HouseholdIncome/empirical"

global CSES2017 "$home/CSES2017"
global rawdata "$CSES2017/Rawdata"
global data "$CSES2017/Data"
global code "$CSES2017/Codes"
global tables "$CSES2017/Tables"
global graphs "$CSES2017/Graphs"
							  
*Choose duration scenario
global maturity=3 /* 1 quarterly maturity
				     2 short maturity
				     3 benchmark
				     4 long maturity
				     5 yearly maturity*/

				
*Choose fraction of durable expenditure excluded from the URE consumption measure
global epsilon=0  /* benchmark: 0 (ie including all durable expenditures) */ 			


* Treat FRMs as ARMs? Used to evaluate potential for asymmetric effects			  
* global frmasarm=0 /* 0 treats them separately, benchmark
*					 1 treats fixed rate mortgage as adjustable rate mortgages*/
					
****
******* (1) Construct exposure measures: URE, NNP, INC using shiw_exposures
****

do "$code/cses2017_aux.do"

*Execute the program for baseline assumptions
cses2017_exp $maturity $epsilon 
*$frmasarm

***
*** (2) Summary statistics for Table 1
***
	
quietly{
	*log using "$tables/table1.smcl", replace			
	noi di "Table 1, CSES2017"
	noi di " "
	noi tabstat NY NC NB ND NURE Nnom_asset Nnom_liab NNNP NINC MPCn [aw=hweight], stat(mean sd) col(stat) format(%5.2f)
	noi di " "
	noi di "Number of households in the sample"   "   " households
	noi di " "
	*log close
}	

****
***** (3) Percentile plot of MPC against each exposure measure
****

foreach var in NURE NNNP NINC {

	*Obtain percentiles cutoffs for exposure measures
	xtile x`var'=`var' [pw=hweight], nquantiles(100)
	label var x`var' "Percentiles of `var'"
	
	preserve

	*Obtain mean value of MPC and exposure measure at each percentile
	collapse MPCn NURE NNNP NINC [pw=hweight], by(x`var') // Note: necessary to collapse all 3 exposure measures and not just the one being analyzed in `var' to allow at the end of the program "if `var'==NURE"..else and distinguish among maturities only for URE

	*Obtain quintiles mean value of exposure measures to label xaxis
	forvalues ctl=1(1)100{
			summarize `var' if x`var'==`ctl', meanonly
			local lab`ctl' : di %3.2f r(mean)
		}

	* Plot and save scatter 
	grstyle init
	grstyle set plain, horizontal grid
	grstyle symbolsize p large

	twoway (scatter MPCn x`var'), name(MPC`var', replace) legend(off)  graphregion(fcolor(white)) xtitle("") ytitle("") xlabel(1 "`lab1'" 21 "`lab21'"  41 "`lab41'"  61 "`lab61'"  81 "`lab81'" 100 "`lab100'", labsize(large)) ylabel(,labsize(large))
	*graph export "$graphs/fig2_MPC_`var'.pdf", as(pdf) replace

	** Text file for paper export 
	gen index=_n
	keep index MPCn
	order index MPCn
	*export delimited using "$graphs/txt/fig2_MPC_`var'_SHIW.txt", delimiter(tab) novarnames replace

	*Export average value of exposure measure in percentile, for xtick labels
	clear
	mat av`var'=J(100,2,.)
	forvalues i=1/100{
	
		matrix av`var'[`i',1] = `i'	
		matrix av`var'[`i',2] = `lab`i''
	}
	
	svmat av`var'	
	keep if _n==1 | _n==21 | _n==41 | _n==61 | _n==81 | _n==100
	*export delimited using "$graphs/txt/fig2_pc_`var'_SHIW.txt", delimiter(tab) replace	
	
	restore
		
}


***
****** (4) Calculate redistribution elasticities for each exposure measure
***


*** Run the program above for all three redistributive channels

foreach var in URE NNP INC{

quietly{
	redmoments `var'
	
	log using "$tables/table4_`var'.smcl", replace

	noi di "Table 4 for `var', CSES2017" 
	
	*Display mean values and confidence intervals
	if "`var'"=="URE"{
		noi disp ""
		noi disp ""
		noi disp "red" "    " %3.2f meanr[1,1] "  " "[" %3.2f meanr[5,1] "," %3.2f meanr[6,1] "]"
		noi disp ""
		noi disp "redNR" "  " %3.2f meanPE[1,1] "  " "[" %3.2f meanPE[5,1] "," %3.2f meanPE[6,1] "]"
		noi disp ""
		noi disp "S" "      " %3.2f meanS[1,1] "  " "[" %3.2f meanS[5,1] "," %3.2f meanS[6,1] "]"
		noi disp ""
		noi disp ""
	}
	if "`var'"=="NNP"{
		noi disp ""
		noi disp ""
		noi disp "red" "    " %3.2f meanr[1,1] "  " "[" %3.2f meanr[5,1] "," %3.2f meanr[6,1] "]"
		noi disp ""
		noi disp "redNR" "  " %3.2f meanPE[1,1] "  " "[" %3.2f meanPE[5,1] "," %3.2f meanPE[6,1] "]"
		noi disp ""
		noi disp ""

	}
	if "`var'"=="INC"{
		noi disp ""
		noi disp ""
		noi disp "M" "    " %3.2f meanPE[1,1] "  " "[" %3.2f meanPE[5,1] "," %3.2f meanPE[6,1] "]"
		noi disp ""
		noi disp "red" "  " %3.2f meanr[1,1] "  " "[" %3.2f meanr[5,1] "," %3.2f meanr[6,1] "]"
		noi disp ""
		noi disp ""	
	}
	
	capture log close
}
	
}
	


***
******** (5) Sensitivity with respect to duration for URE - Table 5
***

foreach mat in 1 2 3 4 5{
	quietly{
		*Reconstruct URE position using the program shiw_exp with the alternative duration scenario
		cses2017_exp `mat' $epsilon 
		*$frmasarm
		
		redmoments URE
		
		*Save the results in a log
		log using "$tables/table5_`mat'.smcl", replace
		
		*Display mean values and confidence intervals for full redistribution elasticity for URE
		noi disp "Table 5 for maturity scenario `mat'"
		noi disp ""
		noi disp ""
		noi disp "red" "    " %3.2f meanr[1,1] "  " "[" %3.2f meanr[5,1] "," %3.2f meanr[6,1] "]"
		noi disp ""
		noi disp ""

		
		log close
	}
	}

	
*Restore benchmark scenario and data
qui cses2017_exp $maturity $epsilon 
*$frmasarm

***** (6) Covariance decomposition
*****

*Age
generate agejpbin=.
replace agejpbin=1 if agehead<=30
replace agejpbin=2 if agehead>30 & agehead<=45
replace agejpbin=3 if agehead>45 & agehead<=60
replace agejpbin=4 if agehead>60 


**** Apply the program to the three redistribution channels on Jappelli and Pistaferri controls for MPC 


foreach redc in NURE NNNP NINC{

quietly{ 	

	log using "$tables/table6_`redc'.smcl", replace
	noi di "Table 6 for `redc', SHIW" 
		
	noi covdecomp `redc' agejpbin
	noi covdecomp `redc' genderhead
	noi covdecomp `redc' hmarried
	noi covdecomp `redc' educhead
	noi covdecomp `redc' nmember
	noi covdecomp `redc' unemp
	
	log close
}
}
