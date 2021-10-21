/*******************************
cses2017_aux.do

declares three functions
* CSES2017_exp generates my main exposure measures URE, NNP and INC
* redmoments reports the covariance between APCs and these exposures
* covdecomp performs a covariance decomposition 

these programs are called from shiw_main_text.do and shiw_appendix.do

*/ 

capture program drop cses2017_exp
program define cses2017_exp

	*version 1.0
	
	args maturity epsilon 
	*frmasarm			
	*maturity is the duration scenario
	*epsilon is the fraction of durable expenditures excluded from URE
	*frmasarm=1 if FRMs treated as ARMs
	
	
	*NOTE: if you want to run the code step by step, comment the "program" line above and set the following local variables
	local maturity=$maturity
	local epsilon=$epsilon
	*local frmasarm=$frmasarm

	
	
	*Import duration values				   
	import excel "$home/duration.xlsx", sheet("duration") firstrow clear
					
						 
	*Automatically set maturity for each asset and liability class
	scalar sc_deposits = 1/deposits in `maturity'
	scalar sc_credcard = 1/cc in `maturity'
		
	**** Import CSES 2017 survey previously assembled by make_raw_cses

	clear
	
	use "$data/CSES2017.dta"
		   
	******
	********* (1) Construct redistribution channels: URE, NNP, INC
	*******

	*
	****** 1.1) URE: Y - C + A - L
	*
	
	
	**** 1.1.1) Income

	* Income = total disposable income
	egen ytotal = rowtotal(wages nonagriinc cropsinc cropinc riceinc seedinc liveinc fishinc pondinc forestryinc landinc buildinc otherinc)
	replace ytotal = ytotal/4045 
	
	**** 1.1.2) Consumption: 

	* Durable consumption (c is total consumption, cn is non durables)
	egen cn = rowtotal(foodc nonfoodc housec dwellingc buildc houserentc livec forestryc illnessc tax) 
	   
	egen c = rowtotal(dgoodsc landc landbuy2016 landbuy2017 educc cn)	
	replace c = c/4045
	
	replace cn = cn/4045
	gen dur = c - cn
		
	* Consumption measure for URE: total expenditure, excluding a fraction epsilon of durables (epsilon=0 in benchmark)
	gen ctotal = cn + (1 - `epsilon') * dur

	**** 1.1.3) Maturing assets:
	
	/*
	As we don't saving account, bond, cash value of life insurance, collection, in here we 
	assume that cash the rest after expenditure can use as maturing assets. 
	*/
	
	gen assettotal = ytotal - ctotal
	
	*egen nasset = rowtotal(dgoodsasset houseasset pondasset landasset buildasset)
	

	gen atotal = assettotal * sc_deposits
	
	**** 1.1.4) Maturing liabilities, L
	gen liabilitistotal = loans
	replace liabilitistotal = liabilitistotal/4045
	gen ltotal = liabilitistotal * sc_credcard
	

	****1.1.5) Generate annual URE 

	gen URE= ytotal - ctotal + atotal - ltotal
	
	*
	****** 1.2) NNP: nominal assets - nominal liabilities
	*

	*1.2.1) Nominal assets:

	*Generate total nominal assets 
	/*
	Only to the extent invested in nominal assets
	*/
	
	egen nom_asset =  rowtotal(nonagriinv ricestock cropinv liveinv1 liveinv2 fishinv forestryinv livestock)
	replace nom_asset = nom_asset/4045
	
	*1.2.2) Nominal liabilities:

	*Generate total nominal liabilities (pf is total liabilities)
	gen nom_liab = loans
	replace nom_liab = nom_liab/4045
	
	*1.2.3) Generate NNP

	*Generate NNP
	gen NNP= nom_asset - nom_liab

	*Many observations have exactly zero value. To construct quantiles, add to all nnp a random value between -1 and 1 dollar.
	replace NNP= (2*runiform() - 1) + NNP  
		
	*
	****1.3) INC: gross income
	*

	gen inctax = wage + nonagriinc
	replace inctax = inctax/4045
	replace inctax = inctax + (inctax * 0.1)
	
	egen INC = rowtotal(cropsinc cropinc riceinc seedinc liveinc fishinc pondinc forestryinc landinc buildinc otherinc tax)
	replace INC = INC/4045
	replace INC = INC + inctax
	*
	******* Normalization
	*
	
	*Record APC from the survey question	
	
	gen stotal = ytotal - ctotal
	
	gen ytotal_new = ctotal + 0 if stotal <0
	replace ytotal_new = ytotal if ytotal_new == .
	
	gen APC = ctotal/ytotal_new
		
	* Normalize by mean annual consumption
	svyset hhid [pweight = hweight]
	svy: mean ctotal ytotal INC
	mat meanc=e(b)
	local mc=meanc[1,1]

	gen NY = ytotal/`mc'
	gen NC = ctotal/`mc'
	gen NB = atotal/`mc'
	gen ND = ltotal/`mc'
	gen NURE = URE/`mc'

	gen Nnom_asset = nom_asset/`mc'
	gen Nnom_liab = nom_liab/`mc'
	gen NNNP = NNP/`mc'

	gen NINC = INC/`mc'

	*Express APC in decimals
	gen APCn = APC
	
	*Count number of households
	count
	scalar households=r(N)		
	
end


** Calculate covariances between APCs and exposures

capture program drop redmoments
program redmoments, rclass
	version 13.0

	*Declare the arguments of the program
	args var 

	* Normalized statistics for redistribution channels by annual consumption
	qui svyset hhid [pweight=hweight]
	qui svy: mean ctotal
	qui mat meanc=e(b)
	qui local mc=meanc[1,1]

	*Obtain mean of redistributive channels and difference from the mean for each observation
	qui svy: mean `var'
	mat mean`var'=e(b)
	local m`var'=mean`var'[1,1]
	qui gen `var'centered=`var'-`m`var''

	*Normalize by average consumption
	qui gen N`var'c=`var'centered/`mc'

	*Obtain partial equilibrium and full redistribution elasticities for each observation
	qui gen redPE_`var'=APCn*N`var'
	qui gen red_`var'=APCn*N`var'c
	
	*Obtain full redistriution elasticity and confidence intervals
	qui svy: mean red_`var'
	*Save results in a matrix
	mat meanr=r(table)
	
	*Obtain partial equilibrium redistribution elasticity and confidence intervals
	qui svy: mean redPE_`var'
	*Save results in a matrix
	mat meanPE=r(table)
	
	*Additional term for URE redistribution
	if `var'==URE{
	
		*Normalize consumption 
		qui gen cm=ctotal/`mc'

		*Scaling factor S
		qui gen subst=(1-APCn)*cm

		*Mean scaling factor and confidence intervals
		qui svy: mean subst
		*Save results in a matrix
		mat meanS=r(table)
		
		/*
		*Sigma 
		local sigmabreakeven=-`mr_URE'/`ms'
		gen minred=-red_URE
		svy: ratio minred/subst
		*/	
		
	}
	

end

****Covariance decomposition module

capture program drop covdecomp
program covdecomp, rclass
	version 13.0
	
	* Arguments
	args covvar expvar
	* covvar is variable whose covariance with APC we want to decompose (eg NURE)
	* expvar is list of variables to use in decomposition
	
	* Estimate the correlation coefficient for APC and covvar
	qui correlate APCn `covvar' [w=hweight], cov
	local covAPCX=`r(cov_12)'

	* Step 1 regress APC on explanatory variables
	qui reg APCn `expvar' [pweight=hweight]
	predict APChat, xb
	predict APCeps, residuals
	matrix bAPC=e(b)

	* Step 2 regress URE on explanatory variables
	qui reg `covvar' `expvar' [pweight=hweight]
	predict Xhat, xb
	predict Xeps, residuals
	matrix bX=e(b)

	* Step 3 obtain covariance matrix of explanatory variables
	qui correlate `expvar'  [w=hweight], cov
	matrix corr=r(C)
	

	* Get back the contribution-to-covariance decomposition
	local dim=rowsof(corr)
	matrix codec=corr
	forvalues i = 1/`dim' {
		forvalues j = 1/`dim' {
			 matrix codec[`i',`j']= 100*bAPC[1,`i']*bX[1,`j']*corr[`i',`j']/`covAPCX'
		}
	}
	
	* First variable contribution (most useful if univariate, but not only)
	local bAPCY1=bAPC[1,1]
	local bX1=bX[1,1]
	local var1=corr[1,1]
	local frac1=codec[1,1]
	
	qui correlate APChat Xhat [w=hweight], cov
	local covhat=`r(cov_12)'
	local pcexp=100*`covhat'/`covAPCX'
	
	qui correlate APCeps Xeps [w=hweight], cov
	local coveps=`r(cov_12)'
	local pcunexp=100*`coveps'/`covAPCX'
	
	
	disp ""
	disp ""
	disp "X  = `covvar' |  Explanatory variable(s) = `expvar'"
	disp "********************************************************"
	*disp "Corr(APC, X)           = " %3.2f `covAPCX'
	disp ""
	disp "var(Y1)                = " %4.2f `var1'
	disp "beta(APC, Y1)          = " %4.3f `bAPCY1'
	disp "beta(X,Y1)             = " %4.3f `bX1'
	disp "Covariance explained = " %3.0f `pcexp' "%"
	disp "Decomposition of explained fraction: "
	mat list codec, format(%04.2f)
	disp ""
	disp ""


	drop Xhat Xeps APChat APCeps
	
	return scalar covAPCX=`covAPCX'
	return scalar pcexp=`pcexp'
	return scalar pcunexp=`pcunexp'
	return matrix codec=codec
	
end
