macro drop _all 
capture program drop mpcest
capture program drop redplot
capture program drop redmoments

version 	14.0

clear
set more off
set graphics on
capture log close 
log using "/Users/nithkosal/Dropbox/Research Projects/HouseholdIncome/empirical/CSES2017/Codes/cses2017_appendix", replace text

/*******************************
cses2017_appendix.do

created: 12 September 2021 
last modified: 25 October 2021

Written by Nith Kosal and Filippo Pallotti

Appendix figures for CSES 2017

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

*Choose number of points in interval [0,1] to evaluate exclusion of durable expenditure for computation of URE
global evalpoints=100 /*100 is my benchmark, decrease this number to speed up the code and get only the overall pattern*/		   

*Choose number of bins for benchmark plot and results 
global agebins=8  /*8 is my benchmark for distribution of redistribution channels and APC by age and income (section  B.6.1 - B.6.2) */


*****
****** Assemble the SHIW and construct redistribution channels as a starting point
*****

*Use the program shiw_exp defined in shiw_exposures to construct measures of the redistribution channels. 

do "$code/cses2017_aux.do"
qui cses2017_exp $maturity $epsilon 

***
*** (1) Summary statistics in levels, Table C1
***
	
quietly{
	
	log using "$appendix/tables/tablec1.smcl", replace
	
	noi di "Table C.1"
	
	noi di " "
	
	noi tabstat ytotal ctotal atotal ltotal URE nom_asset nom_liab NNP INC [aw=hweight], stat(count mean p5 p25 median p75 p95) col(stat) format(%3.0f %9.0fc)

	noi tabstat APCn [aw=hweight], stat(count mean p5 p25 median p75 p95) col(stat) format(%3.2f)
	
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
	qui cses2017_exp $maturity `epsilon' 
	
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

	grstyle init
	grstyle set plain, horizontal grid
	grstyle set legend, nobox	
	grstyle set color #ff4500 #449d44 #31b0d5 #ec971f #c9302c

	grstyle linewidth plineplot .8
	
	twoway (line values2 values1), graphregion(fcolor(white)) plotregion(lcolor(black)) xtitle("epsilon") yl( , grid) ytitle("eps_R") name(epsrepsilon, replace)
	graph export "$appendix/graphs/figc1.pdf", as(pdf) replace 


*Export the graph in txt for TikZ
*export delimited using "$txtapp/figc1_CESE2017.txt", delimiter(tab) novarnames replace

	
clear

*Restore benchmark scenario and data
qui cses2017_exp $maturity $epsilon


***
***** (3) Exposure measures and APC by age and income - Figures C2(a) an C3(a)
***

*Use age of head (wife age often noisy)


*Average redistributive channel components and MPC by age
	grstyle init
	grstyle set plain, horizontal grid
	grstyle set color Set1
	grstyle set legend, nobox
	grstyle linewidth plineplot .8
	
foreach var in agehead NINC {

		preserve
		
		*Obtain percentiles cutoffs for redistribution channels 
		xtile x`var'=`var' [pw=hweight], nquantiles($agebins)	
		
		collapse NY NC NB ND NURE Nnom_asset Nnom_liab NNNP NINC APCn agehead [pw=hweight], by(x`var')
		
		twoway (line NY `var') (line NC `var') (line NB `var') (line ND `var') (line NURE `var'), name(URE`var', replace) graphregion(fcolor(white)) plotregion(lcolor(black)) xtitle("") ytitle("") legend(label(1 "Income") label(2 "Consumption") label(3 "Maturing Assets") label(4 "Maturing liabilities") label(5 "NURE")) // saving("$appendix/`var'/NURE by `bin' `var' bins, maturities $maturity", replace) 
		graph export "$appendix/graphs/figc23_URE_`var'.pdf", as(pdf) replace

		twoway (line Nnom_asset `var') (line  Nnom_liab `var') (line NNNP `var'), name(NNP`var', replace) graphregion(fcolor(white)) plotregion(lcolor(black)) xtitle("") ytitle("") legend(label(1 "Nom Assets") label(2 "Nom Liabilities") label(3 "Normalized NNP")) // saving("$appendix/`var'/NNNP by `bin' `var' bins", replace) 
		graph export "$appendix/graphs/figc23_NNP_`var'.pdf", as(pdf) replace
		
		twoway (line NINC `var'), name(INC`var', replace) graphregion(fcolor(white)) plotregion(lcolor(black)) xtitle("`var'") ytitle("INC") // saving("$appendix/`var'/NINC by `bin' `var' bins", replace)
		graph export "$appendix/graphs/figc23_INC_`var'.pdf", as(pdf) replace

		twoway (line APCn `var'), name(APC`var', replace) graphregion(fcolor(white)) plotregion(lcolor(black)) xtitle("`var'") ytitle("APC") // saving("$appendix/`var'/APC by `bin' `var' bins", replace)
		graph export "$appendix/graphs/figc23_APC_`var'.pdf", as(pdf) replace

		restore

}

* Graphs in txt for tikz
tempfile temp
save "`temp'"

foreach var in agehead NINC {
			
		use "`temp'", replace
		
		xtile x`var'=`var' [pw=hweight], n($agebins)

		collapse NY NC NB ND NURE Nnom_asset Nnom_liab NNNP NINC APCn agehead [pw=hweight], by(x`var')

		foreach credc in NY NC NB ND NURE Nnom_asset Nnom_liab NNNP NINC APCn{
		
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



quietly{ 	

	log using "$appendix/tables/tablec7.smcl", replace
	noi di "Table C7 for URE in CSES 2017" 
	noi covdecomp NURE "agejpbin genderhead hmarried educhead nmember unemp region"
	log close
	
	log using "$appendix/tables/tablec8.smcl", replace
	noi di "Table C8 for URE, CSES 2017" 
	noi covdecomp NNNP "agejpbin genderhead hmarried educhead nmember unemp region"
	log close
	
	log using "$appendix/tables/tablec9.smcl", replace
	noi di "Table C9 for Y, CSES 2017" 
	noi covdecomp NINC "agejpbin genderhead hmarried educhead nmember unemp region"
	log close

}
	
***
***** (8)  Household income and consumption 
***	
	gen y = ytotal/1000
	gen cc = ctotal/1000
	gen asset = nom_asset/1000 
	gen liab = nom_liab/1000

	
	
foreach var of varlist educhead earner nmember region agejpbin {	
	table `var', c(mean ytotal)
	
	grstyle set color #31b0d5
	graph bar y, over(`var') ytitle ("") plotregion(lcolor(black)) name(inc_`var', replace)
	
	graph export "$appendix/graphs/inc_`var'.pdf", as(pdf) replace

	grstyle set color #286090
	graph bar cc, over(`var') ytitle ("") plotregion(lcolor(black)) name(cons_`var', replace)

	graph export "$appendix/graphs/cons_`var'.pdf", as(pdf) replace

 }

***
***** (5)  Household income vs education level by gender 
***
	grstyle init
	grstyle set plain, horizontal grid
	grstyle set legend, nobox	
	grstyle set color #286090 #449d44 #31b0d5 #ec971f #c9302c
	
foreach var of varlist y cc asset liab {
	tab educ genderhead, summ(`var')
	table educ genderhead, c(mean `var')

	cibar `var', over1(educ) over2(genderhead) graph(ytitle("") plotregion(lcolor(black)) name(educ_`var', replace))
	
	graph export "$appendix/graphs/educ_`var'.pdf", as(pdf) replace
}
		
***
***** (8)  Household income vs total hour of work   
***	

	gen ln_hwork = ln(twork)
	gen ln_y = ln(ytotal)
	gen ln_c = ln(ctotal)
	
	grstyle set color #286090 #c9302c
	grstyle set linewidth 2.5pt: plineplot
	
foreach var of varlist ln_hwork ln_c {
	
	twoway (scatter ln_y `var') (fpfitci ln_y `var' [pweight = hweight], bcolor(538y) plotregion(lcolor(black)) name(ln_y_`var', replace)), ///
		xtitle("") legend(order(1 "ln(income)" 2 "95% CI" 3 "predicted ln(income)"))
	
	graph export "$appendix/graphs/ln_y_`var'.pdf", as(pdf) replace
}		
	
*** 
***** Kdensity 	plots 
***	
		 		 
foreach x of varlist y cc asset liab {
	tab region, summ(`x')
	
	grstyle init
	grstyle set plain, horizontal grid
	grstyle set legend, nobox
	grstyle set color Set1
	grstyle set linewidth 2pt: plineplot
	
	twoway histogram `x', color(538y) || kdensity `x' ||, by(region) plotregion(lcolor(black)) name(kdensity_`x', replace)
 	
	graph export "$appendix/graphs/kdensity_`var'.pdf", as(pdf) replace
}	
* Kensity income, consumption, asset and liability
		 
	su y,de
	local med=r(p50)
	local p5=r(p5)
	local p95=r(p95)

	kdensity y,  xline(`p5', lcolor(orange) lpattern(short_dash) ) ///
                 xline(`med', lcolor(blue) lpattern(longdash_dot_dot)) ///
                 xline(`p95', lcolor(red) lpattern(dash)) plotregion(lcolor(black))	
	graph export "$appendix/graphs/t_kden_y.pdf", as(pdf) replace
	
	su cc,de
	local med=r(p50)
	local p5=r(p5)
	local p95=r(p95)

	kdensity cc,  xline(`p5', lcolor(orange) lpattern(short_dash) ) ///
                 xline(`med', lcolor(blue) lpattern(longdash_dot_dot)) ///
                 xline(`p95', lcolor(red) lpattern(dash)) plotregion(lcolor(black))
	graph export "$appendix/graphs/t_kden_cc.pdf", as(pdf) replace
	
	su asset,de
	local med=r(p50)
	local p5=r(p5)
	local p95=r(p95)

	kdensity asset,  xline(`p5', lcolor(orange) lpattern(short_dash) ) ///
                 xline(`med', lcolor(blue) lpattern(longdash_dot_dot)) ///
                 xline(`p95', lcolor(red) lpattern(dash)) plotregion(lcolor(black))
	graph export "$appendix/graphs/t_kden_asset.pdf", as(pdf) replace
	
	su liab,de
	local med=r(p50)
	local p5=r(p5)
	local p95=r(p95)

	kdensity liab,  xline(`p5', lcolor(orange) lpattern(short_dash) ) ///
                 xline(`med', lcolor(blue) lpattern(longdash_dot_dot)) ///
                 xline(`p95', lcolor(red) lpattern(dash)) plotregion(lcolor(black))				 
	graph export "$appendix/graphs/t_kden_liab.pdf", as(pdf) replace

*** 
***** Percentiles income plots 
***	
	
	pshare estimate ytotal if region<=5, percent percentiles(20 40 60 80 100) over(region) total gini
	pshare stack, plabels("P0–P20" "P20–P40" "P40–P60" "P60–P80" "P80–P100") xtitle("Income Distribution (Percent)")

	graph export "$appendix/graphs/percentiles_inc.pdf", as(pdf) replace	
	
	pshare estimate ytotal, p(5 10(10)90 95) over(educ) density
	pshare histogram, yline(1) plotregion(lcolor(black)) xtitle("Pupulation Percentage") ///
		ytitle("Outcome Share (Density)") legend(order(1 "Outcome Share" 2 "95% CI"))
	
	graph export "$appendix/graphs/percentiles_inc_educ.pdf", as(pdf) replace	

	
	
*** 
***** Descriptive statistics
***	

	gen dasset = dgoodsasset/4045
	gen hasset = houseasset/4045
	gen lasset = landasset/4045
	gen basset = buildasset/4045
		
	gen wage = wages/4045
	
	gen nonagri = nonagriinc/4045
	
	egen agriinc = rowtotal(cropsinc cropinc riceinc seedinc liveinc fishinc pondinc forestryinc)
	gen agri= agriinc/4045
	
	egen other = rowtotal(landinc buildinc otherinc)
	gen otherincs = other/4045
	
	gen food = foodc/4045
	
	gen nonfood = nonfoodc/4045
	
	egen housecon = rowtotal(housec houserentc dwellingc)
	gen house = housecon/4045
	
	gen dgood = dgoodsc/4045
	
	egen otherc = rowtotal(buildc educc illnessc tax livec forestryc landc landbuy2016 landbuy2017)
	
	gen othercon = otherc/4045
	
	global xlist agehead genderhead educhead hmarried nmember earner twork retired unemp ytotal wage nonagri agri otherincs ctotal food nonfood house dgood othercon assettotal nom_asset dasset hasset lasset basset nom_liab
	quietly estpost sum $xlist, de
	
	esttab, cell("mean sd p10 p25 p50 p75 p90")
	quietly esttab using "$appendix/Tables/des_stat.tex", cell((mean(fmt(%10.2f)) sd(fmt(%10.2f)) p10(fmt(%10.2f)) p25(fmt(%10.2f)) p50(fmt(%10.2f)) p75(fmt(%10.2f)) p90(fmt(%10.2f)))) 


	
*** 
***** Asset plots 
***		
	 
	replace dasset = dasset/1000
	replace hasset = hasset/1000 
	replace lasset = lasset/1000 
	replace basset = basset/1000 
	
	cibar dasset, over1(region) graph(ytitle("") plotregion(lcolor(black)))
	graph export "$appendix/graphs/region_dgoodsasset.pdf", as(pdf) replace

	cibar hasset, over1(region) graph(ytitle("") plotregion(lcolor(black)))
	graph export "$appendix/graphs/region_houseasset.pdf", as(pdf) replace
	
	cibar lasset, over1(region) graph(ytitle("") plotregion(lcolor(black)))
	graph export "$appendix/graphs/region_landasset.pdf", as(pdf) replace
	
	cibar basset, over1(region) graph(ytitle("") plotregion(lcolor(black)))
	graph export "$appendix/graphs/region_buildasset.pdf", as(pdf) replace
	
*Drawing a Lorenz curve of income 
	
	glcurve y [aw = hweight], xtitle("Cumulative Population Proportion") lwidth(thick) plotregion(lcolor(black))
	graph export "$appendix/graphs/inc_lorez.pdf", as(pdf) replace	

	*inequality indices
	
	lorenz estimate y, percentiles(60(2)94 95(1)100) graph(recast(connect) ytitle("Cumulative Population Proportion") xtitle("Population Percentage") plotregion(lcolor(black))) 
	graph export "$appendix/graphs/inc_lorez_per.pdf", as(pdf) replace	

	*Subpopulation estimation
	
	lorenz estimate y, over(region) contrast(1) graph(plotregion(lcolor(black)))
	graph export "$appendix/graphs/inc_lorez_region_con.pdf", as(pdf) replace	

	lorenz estimate y, over(region) generalized graph(plotregion(lcolor(black))) 
	graph export "$appendix/graphs/inc_lorez_region_gen.pdf", as(pdf) replace	

	 
	lorenz estimate wage nonagri agri otherincs, pvar(ytotal)
	lorenz graph, aspectratio(1) plotregion(lcolor(black)) ytitle("Cumulative Outcome Proportion") ///
	xtitle("Population Percentage (Ordered by Total Income)") xlabels(, grid) overlay ysize(4.8) xsize(4) ///
	legend(cols(2) order(6 "Wages" 7 "Business Incomes" 8 "Agricultural Incomes" 9 "Other Incomes")) ///
	ciopts(recast(rline) lpattern(dash)) 
	
	graph export "$appendix/graphs/lorez_inc.pdf", as(pdf) replace	

	
	lorenz estimate food nonfood house dgood othercon, pvar(ctotal)
	lorenz graph, aspectratio(1) plotregion(lcolor(black)) ytitle("Cumulative Outcome Proportion") ///
	xtitle("Population Percentage (Ordered by Total Consumption)") xlabels(, grid) overlay ysize(4.8) xsize(4) ///
	legend(cols(2) order(7 "Foods" 8 "Non Foods" 9 "Housing" 10 "Durable Goods" 11 "Other Consumptions")) ///
	ciopts(recast(rline) lpattern(dash)) 
	
	graph export "$appendix/graphs/lorez_con.pdf", as(pdf) replace	

	
	lorenz estimate nom_asset dasset hasset lasset basset, pvar(assettotal)
	lorenz graph, aspectratio(1) plotregion(lcolor(black)) ytitle("Cumulative Outcome Proportion") ///
	xtitle("Population Percentage (Ordered by Maturing Assets)") xlabels(, grid) overlay ysize(4.8) xsize(4) ///
	legend(cols(2) order(7 "Nominal Assets" 8 "Durable Goods Assets" 9 "Home Assets" 10 "Land assets" 11 "Building Assets")) ///
	ciopts(recast(rline) lpattern(dash))
	
	graph export "$appendix/graphs/lorez_ass.pdf", as(pdf) replace	


log close
exit
