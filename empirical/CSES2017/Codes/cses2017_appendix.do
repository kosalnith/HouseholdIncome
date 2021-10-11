/*******************************
shiw_appendix.do

created 12/15/2016  
last modified 10/11/2018

Written by Adrien Auclert and Filippo Pallotti

Appendix figures for SHIW

INPUTS: 

CSES2017.dta (from cses2017_rawdata.do)

OVERVIEW:

(1) Summary statistics in levels - Table C.1
(2) Excluding durables from URE computation - Figure C.1(a)
(3) Exposure measures by age and income - Figures C.2(a) and C.3(a)
(4) Covariance decomposition - Tables C.7, C.8, C.9

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
global appendix "$CSES2017/Appendix"
global txtapp "$appendix/txt" 

*Choose duration scenario (see the appendix for definitions)
global maturity=3 /* 1 quarterly maturity
				   2 short maturity
				   3 benchmark
				   4 long maturity
				   5 yearly */

				
*Choose fraction of durable expenditure excluded from URE's consumption measure
global epsilon=0  /* 0, not excluding any durable expenditures in the calculations of URE is my benchmark */ 			

***** Choose asymmetric effect: whether counting fixed rate mortgages as adjustable rate ones				  
global frmasarm=0 /* 0 treats them separately, benchmark
					 1 treats fixed rate mortgage as adjustable rate mortgages*/

*Choose number of points in interval [0,1] to evaluate exclusion of durable expenditure for computation of URE
global evalpoints=100 /*100 is my benchmark, decrease this number to speed up the code and get only the overall pattern*/		   

*Choose number of bins for benchmark plot and results 
global agebins=8  /*8 is my benchmark for distribution of redistribution channels and MPC by age and income (section  B.6.1 - B.6.2) */


*****
****** Assemble the SHIW and construct redistribution channels as a starting point
*****

*Use the program shiw_exp defined in shiw_exposures to construct measures of the redistribution channels. 

do "$code/cses2017_aux.do"
qui cses2017_exp $maturity $epsilon $frmasarm 

***
*** (1) Summary statistics in levels, Table C1
***
	
quietly{
	
	log using "$appendix/tables/tablec1.smcl", replace
	
	noi di "Table C.1"
	
	noi di " "
	
	noi tabstat ytotal ctotal atotal ltotal URE nom_asset nom_liab NNP INC [aw=hweight], stat(count mean p5 p25 median p75 p95) col(stat) format(%3.0f %9.0fc)

	noi tabstat MPCn [aw=hweight], stat(count mean p5 p25 median p75 p95) col(stat) format(%3.2f)
	
	noi di " "

	noi di "Number of households in the sample"   "   " households
	
	log close
}	

***
***** (2) Excluding durables from URE computation - Figure C.1 (left column)
***

*Choose denominator of fraction epsilon of durables excluded from measurment of URE 
local evalpoints=$evalpoints /*benchmark is 100, defined above*/

*Create a matrix to record epsilon and the value of URE full redistribution elasticity 
mat values=J(`evalpoints'+1,2,.)

forvalues i=0(1)`evalpoints'{ 
	
	*Gradually increase epsilon from 0 (benchmark) to 1 
	local epsilon=`i' / `evalpoints'
	
	di "Excluding  " `epsilon' *100 " percent of durable consumption in URE measurment"
	
	*Reconstruct URE position using the program shiw_exp excluding epsilon fraction of durable consumption
	qui cses2017_exp $maturity `epsilon' $frmasarm
	
	*Run the program to estimate redistribution elasticity
	qui redmoments URE

	*Record the share of durable expenditures excluded and the full redistribution elasticity estimate calculated by redmoments
	mat values[`i'+1,1]=`epsilon'
	mat values[`i'+1,2]=meanr[1,1]
		
}

*Save the results in a graph
clear

svmat values

*Save as pdf
twoway (line values2 values1), graphregion(fcolor(white)) xtitle("epsilon") ytitle("eps_R") name(epsrepsilon, replace)
graph export "$appendix/graphs/figc1.pdf", as(pdf) replace 


*Export the graph in txt for TikZ
export delimited using "$txtapp/figc1_SHIW.txt", delimiter(tab) novarnames replace

	
clear

*Restore benchmark scenario and data
qui cses2017_exp $maturity $epsilon $frmasarm


***
***** (3) Exposure measures and MPC by age and income - Figures C2(a) an C3(a)
***

*Use age of head (wife age often noisy)


*Average redistributive channel components and MPC by age

foreach var in agehead NINC {

		preserve
		
		*Obtain percentiles cutoffs for redistribution channels 
		xtile x`var'=`var' [pw=hweight], nquantiles($agebins)	
		
		collapse NY NC NB ND NURE Nnom_asset Nnom_liab NNNP NINC MPCn agehead [pw=hweight], by(x`var')
		
		twoway (line NY `var') (line NC `var') (line NB `var') (line ND `var') (line NURE `var'), name(URE`var', replace) graphregion(fcolor(white)) xtitle("") ytitle("") legend(label(1 "Income") label(2 "Consumption") label(3 "Maturing Assets") label(4 "Maturing liabilities") label(5 "NURE")) // saving("$appendix/`var'/NURE by `bin' `var' bins, maturities $maturity", replace) 
		graph export "$appendix/graphs/figc23_URE_`var'.pdf", as(pdf) replace

		twoway (line Nnom_asset `var') (line  Nnom_liab `var') (line NNNP `var'), name(NNP`var', replace) graphregion(fcolor(white)) xtitle("") ytitle("") legend(label(1 "Nom Assets") label(2 "Nom Liabilities") label(3 "Normalized NNP")) // saving("$appendix/`var'/NNNP by `bin' `var' bins", replace) 
		graph export "$appendix/graphs/figc23_NNP_`var'.pdf", as(pdf) replace
		
		twoway (line NINC `var'), name(INC`var', replace) graphregion(fcolor(white)) xtitle("`var'") ytitle("INC") // saving("$appendix/`var'/NINC by `bin' `var' bins", replace)
		graph export "$appendix/graphs/figc23_INC_`var'.pdf", as(pdf) replace

		twoway (line MPCn `var'), name(MPC`var', replace) graphregion(fcolor(white)) xtitle("`var'") ytitle("MPC") // saving("$appendix/`var'/MPC by `bin' `var' bins", replace)
		graph export "$appendix/graphs/figc23_MPC_`var'.pdf", as(pdf) replace

		restore

}

* Graphs in txt for tikz
tempfile temp
save "`temp'"

foreach var in agehead NINC {
			
		use "`temp'", replace
		
		xtile x`var'=`var' [pw=hweight], n($agebins)

		collapse NY NC NB ND NURE Nnom_asset Nnom_liab NNNP NINC MPCn agehead [pw=hweight], by(x`var')

		foreach credc in NY NC NB ND NURE Nnom_asset Nnom_liab NNNP NINC MPCn{
		
			preserve	
			keep `var' `credc'
			order `var' `credc' 
			
			export delimited using "$txtapp/figc23_`credc'_`var'_CSES2017.txt", delimiter(tab) novarnames replace
			restore
		
	}
	
}


qui cses2017_exp $maturity $epsilon 

***
***** (4)  Full covariance decomposition - tables C7-C9
***


*Age
generate agejpbin=.
replace agejpbin=1 if agehead<=30
replace agejpbin=2 if agehead>30 & agehead<=45
replace agejpbin=3 if agehead>45 & agehead<=60
replace agejpbin=4 if agehead>60 


quietly{ 	

	log using "$appendix/tables/tablec7.smcl", replace
	noi di "Table C7 for URE in SHIW" 
	noi covdecomp NURE "agejpbin genderhead hmarried educhead nmember unemp"
	log close
	
	log using "$appendix/tables/tablec8.smcl", replace
	noi di "Table C8 for URE, SHIW" 
	noi covdecomp NNNP "agejpbin genderhead hmarried educhead nmember unemp"
	log close
	
	log using "$appendix/tables/tablec9.smcl", replace
	noi di "Table C9 for Y, SHIW" 
	noi covdecomp NINC "agejpbin genderhead hmarried educhead nmember unemp"
	log close

}


