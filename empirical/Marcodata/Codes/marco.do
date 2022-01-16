macro drop _all /*drop all macros from CSES2017 dofiles if running them in the same Stata session */

clear
set more off
capture log close 


* Set directory
global home "/Users/nithkosal/Dropbox/Research Projects/HouseholdIncome/empirical"

global Macro "$home/Marcodata"
global data "$Macro/Data"
global code "$Macro/Codes"
global graphs "$Macro/Graphs"
global tables "$Macro/Tables"


cd "$data"

	u "gdp_inflation", replace 					
	
	tsset year
	
	grstyle init
	grstyle set plain, horizontal grid
	grstyle set color Set1
	grstyle set legend, nobox
	grstyle linewidth plineplot .6
	
	gen linflation = log(inflation) 

	tssmooth ma minflation = linflation, window(1 1 1)
	tssmooth ma mgdp = gdp, window(1 1 1)

	twoway (tsline mgdp minflation), xlabel(1988(3)2021) ylabel(0(3)12) plotregion(lcolor(black)) xtitle("") ytitle("") legend(label(1 "GDP Growth") label(2 "Log(Inflation Growth)"))
	graph export "$graphs/moving_gdp.pdf", as(pdf) replace

	varbasic D.gdp D.linflation 
	

	irf graph fevd, lstep(1)

******

	
	u "macrodata", replace 					
	gen quarters = tq(2010q1) + _n-1
	format %tq quarters
	tsset quarters
	
	rename cpi inf
	rename m2 bm2 
	rename gdp output


	gen cpi = log(cpi_average)
	gen m2 = log(bm2)
	
	gen ex_rate = (exrate_p+exrate_s)/2
	gen erate = log(ex_rate)
	
	gen erate_o = log(exrate_off)
	
	gen irate_d = irate_deposits_usd
	replace irate_d = .7955 if irate_d == .
	
	gen irate_l = irate_loans_usd
	replace irate_l = 9.7170 if irate_l == .
	
	gen irate = (irate_d + irate_l)/2
	
	global xlist inf output unemp irate ex_rate bm2 
	quietly estpost sum $xlist, de
	
	esttab, cell("count mean sd min max")
	quietly esttab using "$Macro/Tables/des_stat.tex", cell((count mean(fmt(%10.2f)) sd(fmt(%10.2f)) min(fmt(%10.2f)) max(fmt(%10.2f)))) 

	
	replace inf = log(inf)
	replace irate = log(irate)
	replace unemp = log(unemp)
	replace output = log(output)
		
foreach var of varlist inf cpi_food cpi_oil cpi_tran m2_growth inf_growth exrate_off ex_rate {
	
	tssmooth ma t_`var' = `var', window(1 1 1)
	
}
	

	twoway (tsline t_m2_growth), plotregion(lcolor(black)) xtitle("") ytitle("")
	graph export "$graphs/moving_m2.pdf", as(pdf) replace

	
	twoway (tsline t_inf_growth), plotregion(lcolor(black)) xtitle("") ytitle("")
	graph export "$graphs/moving_inflation'.pdf", as(pdf) replace

	
	tsline t_inf t_cpi_food t_cpi_oil t_cpi_tran, plotregion(lcolor(black)) xtitle("") ytitle("") legend(label(1 "CPI") label(2 "CPI Food") label(3 "CPI Oil") label(4 "CPI Transportation"))
	graph export "$graphs/moving_cpi.pdf", as(pdf) replace
	 
	twoway tsline t_exrate_off t_ex_rate, tlabel(2010Q4 2012Q4 2014Q4 2016Q4 2018q4 2020q4) plotregion(lcolor(black)) xtitle("") ytitle("") legend(label(1 "Official exchange rate") label(2 "Market exchange rate"))
	graph export "$graphs/moving_exrate.pdf", as(pdf) replace
 
	 
*****

	sum inf m2 output unemp erate irate

	varbasic D.inf D.output D.unemp D.erate 
	

	irf graph fevd, lstep(1)
	
	 irf graph fevd, impulse(D.inf D.m2 D.output) response(D.inf D.m2 D.output) lstep(1)
	
	
	varsoc D.inf D.output D.unemp D.erate D.irate D.m2
	
	*Johansen tests for cointegration 
	vecrank D.inf D.output D.unemp D.erate D.m2 D.irate, trend(constant) lags(4)
	
	*Vector error-correction model
	vec inf m2 output unemp erate irate, trend(constant) 

	*Autocorrelation test
	veclmar
	
	*Normally distribution test 
	vecnorm, jbera skewness kurtosis


   *Eigenvalue stability condition
	vecstable
	
	*Dickey-Fuller test for unit root    
	dfuller inf
	
	* vargranger

	var D.inf D.m2 D.output D.unemp D.erate D.irate, lags(1/4)
	
	log using "$tables/table_3.smcl", replace
		vargranger
	log close
	 
	irf table sirf
	irf table oirf fevd, impulse(D.inf) response(D.output) noci std
	
	
****

**Sample:  2011q2 - 2021q2     

	matrix A1 = (1,0,0,0 \ .,1,0,0 \ .,.,1,0 \ .,.,.,1)
	matrix list A1


	matrix B1 = (.,0,0,0 \ 0,.,0,0 \ 0,0,.,0 \ 0,0,0,.)
	matrix list B1

	svar D.inf D.output D.unemp D.erate, lags(1/4) aeq(A1) beq(B1)
	
	matlist e(A)
	matlist e(B)

	irf create Impulse, set(svar1.irf) replace step(40)
		
	grstyle linewidth plineplot 1.1
		
	*Structural impulse response function
	irf graph sirf, xlabel(0(5)40) irf(Impulse) yline(0,lcolor(black)) byopts(yrescale)
	graph export "$graphs/impulse_svar1.pdf", as(pdf) replace

	*Structural forecast error variance decomposition 
	irf graph sfevd,  xlabel(0(5)40) irf(Impulse) yline(0,lcolor(black)) byopts(yrescale)
	graph export "$graphs/var_svar1.pdf", as(pdf) replace

 
****	 
	matrix A2 = (1,0,0,0 \ .,1,0,0 \ .,.,1,0 \ .,.,.,1)
	matrix list A2


	matrix B2 = (.,0,0,0 \ 0,.,0,0 \ 0,0,.,0 \ 0,0,0,.)
	matrix list B2

	svar D.inf D.m2 D.output D.irate, lags(1/4) aeq(A2) beq(B2)
	
	matlist e(A)
	matlist e(B)

	irf create Impulse, set(svar2.irf) replace step(40)
	
	grstyle linewidth plineplot 1.1
		
	irf graph sirf, xlabel(0(5)40) irf(Impulse) yline(0,lcolor(black)) byopts(yrescale)
	graph export "$graphs/impulse_svar2.pdf", as(pdf) replace

	irf graph sfevd,  xlabel(0(5)40) irf(Impulse) yline(0,lcolor(black)) byopts(yrescale)
	graph export "$graphs/var_svar2.pdf", as(pdf) replace

	
	
	
	
	
	
****
	*Table 


	
	irf set "$data/svar1.irf"

foreach var in inf output erate unemp{ 	
quietly{
	log using "$tables/table_a1_`var'.smcl", replace
	noi di "Table_A1 for `var'" 
			
	noi irf table sfevd, irf(Impulse) impulse(D.`var') response(D.inf D.output D.erate D.unemp) individual noci

	log close
}
}


	irf set "$data/svar2.irf"

foreach var in inf output m2 irate{ 	
quietly{
	log using "$tables/table_a2_`var'.smcl", replace
	noi di "Table_A2 for `var'" 
			
	noi irf table sfevd, irf(Impulse) impulse(D.`var') response(D.inf D.output D.m2 D.irate) individual noci

	log close
}
}

