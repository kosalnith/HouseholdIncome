/*******************************
CSES2017_aux.do

declares three functions
* CSES2017_exp generates my main exposure measures URE, NNP and INC
* redmoments reports the covariance between MPCs and these exposures
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
	gen ytotal = wages + nonagriinc + cropsinc + cropinc + riceinc + seedinc + liveinc + fishinc + pondinc + forestryinc + landinc + buildinc + otherinc
	replace ytotal = ytotal/4000
	
	**** 1.1.2) Consumption: 

	* Durable consumption (c is total consumption, cn is non durables)
	egen cn = rowtotal(foodc nonfoodc housec)
	egen c = rowtotal(dgoodsc cn)	
	replace c = c/4000
	
	replace cn = cn/4000
	gen dur = c - cn
		
	* Consumption measure for URE: total expenditure, excluding a fraction epsilon of durables (epsilon=0 in benchmark)
	gen ctotal = cn + (1 - `epsilon') * dur

	**** 1.1.3) Maturing assets:
	
	/*
	As we don't saving account, bond, cash value of life insurance, collection, in here we 
	assume that cash the rest after expenditure can use as maturing assets. 
	*/
	
	gen assettotal = ytotal - ctotal
	gen atotal = assettotal * sc_deposits
	
	**** 1.1.4) Maturing liabilities, L
	gen liabilitistotal = loans + landc
	replace liabilitistotal = liabilitistotal/4000
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
	
	gen nom_asset =  nonagriinv + cropinv + liveinv1 + liveinv2 + fishinv + forestryinv
	replace nom_asset = nom_asset/4000
	
	*1.2.2) Nominal liabilities:

	*Generate total nominal liabilities (pf is total liabilities)
	gen nom_liab = loans + landc
	replace nom_liab = nom_liab/4000
	
	*1.2.3) Generate NNP

	*Generate NNP
	gen NNP= nom_asset - nom_liab

	*Many observations have exactly zero value. To construct quantiles, add to all nnp a random value between -1 and 1 dollar.
	replace NNP= (2*runiform() - 1) + NNP  
		
	*
	****1.3) INC: gross income
	*

	gen INC = wages + nonagriinc + cropsinc + cropinc + riceinc + seedinc + liveinc + fishinc + pondinc + forestryinc + landinc + buildinc + otherinc + tax 
	replace INC = INC/4000 + (INC/4000)*0.1

	*
	******* Normalization
	*
	
	*Record MPC from the survey question
	gen MPC= ctotal/ytotal
	
	* Normalize by mean annual consumption
	svyset hhid [pweight = hweight]
	svy: mean ctotal ytotal INC
	mat meanc=e(b)
	local mc=meanc[1,1]

	gen NY=ytotal/`mc'
	gen NC=ctotal/`mc'
	gen NB=atotal/`mc'
	gen ND=ltotal/`mc'
	gen NURE=URE/`mc'

	gen Nnom_asset=nom_asset/`mc'
	gen Nnom_liab=nom_liab/`mc'
	gen NNNP=NNP/`mc'

	gen NINC=INC/`mc'

	*Express MPC in decimals
	gen MPCn=MPC
	
	*Count number of households
	count
	scalar households=r(N)		
	
end


** Calculate covariances between MPCs and exposures

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
	qui gen redPE_`var'=MPCn*N`var'
	qui gen red_`var'=MPCn*N`var'c
	
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
		qui gen subst=(1-MPCn)*cm

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
	* covvar is variable whose covariance with MPC we want to decompose (eg NURE)
	* expvar is list of variables to use in decomposition
	
	* Estimate the correlation coefficient for MPC and covvar
	qui correlate MPCn `covvar' [w=hweight], cov
	local covMPCX=`r(cov_12)'

	* Step 1 regress MPC on explanatory variables
	qui reg MPCn `expvar' [pweight=hweight]
	predict MPChat, xb
	predict MPCeps, residuals
	matrix bMPC=e(b)

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
			 matrix codec[`i',`j']= 100*bMPC[1,`i']*bX[1,`j']*corr[`i',`j']/`covMPCX'
		}
	}
	
	* First variable contribution (most useful if univariate, but not only)
	local bMPCY1=bMPC[1,1]
	local bX1=bX[1,1]
	local var1=corr[1,1]
	local frac1=codec[1,1]
	
	qui correlate MPChat Xhat [w=hweight], cov
	local covhat=`r(cov_12)'
	local pcexp=100*`covhat'/`covMPCX'
	
	qui correlate MPCeps Xeps [w=hweight], cov
	local coveps=`r(cov_12)'
	local pcunexp=100*`coveps'/`covMPCX'
	
	
	disp ""
	disp ""
	disp "X  = `covvar' |  Explanatory variable(s) = `expvar'"
	disp "********************************************************"
	*disp "Corr(MPC, X)           = " %3.2f `covMPCX'
	disp ""
	disp "var(Y1)                = " %4.2f `var1'
	disp "beta(MPC, Y1)          = " %4.3f `bMPCY1'
	disp "beta(X,Y1)             = " %4.3f `bX1'
	disp "Covariance explained = " %3.0f `pcexp' "%"
	disp "Decomposition of explained fraction: "
	mat list codec, format(%04.2f)
	disp ""
	disp ""


	drop Xhat Xeps MPChat MPCeps
	
	return scalar covMPCX=`covMPCX'
	return scalar pcexp=`pcexp'
	return scalar pcunexp=`pcunexp'
	return matrix codec=codec
	
end

