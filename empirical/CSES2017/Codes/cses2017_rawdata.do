/***
CSES2017_rawdata.do

created 16 September 2021 
last modified 30 September 2021
version: 5.0

Written by Nith Kosal and Phay Thonnimith

NOTE:

***You should change the path in the global variable "home" to run this code

***/

macro drop _all /*drop all macros from CSES2017 dofiles if running them in the same Stata session */

clear
set more off

* Set directory
global home "/Users/nithkosal/Documents/Kosal Documents/Research Projects/2021/HouseholdIncome/empirical"

global CSES2017 "$home/CSES2017"
global rawdata "$CSES2017/Rawdata"
global data "$CSES2017/Data"
global code "$CSES2017/Codes"

****

/*
OUTPUT: CSES2017.DTA

	Definition of variables:
	1. Income
		wages 		is the total wages per household 
		nonagriinc  is incomes from non agricultural economic activities
		cropsinc  	is crops net income
		cropinc 	is net income from crops production per households both for shocks and sales	
		riceinc	  	is incomes from rice production 
		seedinc 	is incomes from seeds rent out 
		liveinc		is income from livestock sell
		fishinc   	is incomes from fishing and trapping 
		pondinc   	is incomes from pont rent out 
		forestryinc is incomes from forestry and hunting 	
		landinc 	is incomes from land rent out 
		buildinc	is incomes from buiding rent of household 
		otherinc 	is incomes receive from social wefare, pensions, fund, remittances, cash transfers, interest rate, dividents, saving accounts, and sold assets  

	2. Consumption
		foodc 		is total food consumption per houeshold 
		livec		is used his own livestock for consumption in households, for gifts, charity and barter
		forestryc  	is used his own forestry for consumption in households, for gifts, charity and barter
		nonfoodc 	is non food consumption
		dgoodsc		is durable goods consumption in 2016 and 2017
		housec 		is house expenditure 
		houserentc	is expenditure on house rent 
		dwellingc	is house expenditure 
		landbuy2016 is total expenditure on land purchase in 2016
		landbuy2017 is total expenditure on land purchase in 2017
		buildc 		is expenditures on buiding  
		educc 		is expenditure on education per household  
		illnessc	is expenditure on healthcare
		tax 		is expenditure on tax both salary and property 
				
	3. Asset
		dgoodsasset	is durable goods asset if sell in the current price 
		houseasset 	is house asset if sell in the current price 
		pondasset 	is pond asset in the current market price 	
		landasset 	is land asset in the current market price
		landrasset   is land asset if rent out in the current market price
		buildasset	is asset from building if purchase in the current price 
		buildrasset is asset from buiding if rent out in the current price 
		nonagriinv 	is non agricultural economic activities investment 
		cropinv		is total expenditure on crops investment 
		liveinv1	is expenditure on livestock investment
		liveinv2	is expenditure on livestock investment
		fishinv   	is expenditure on fishing investment 
		forestryinv is is expenditure on forestry investment 
		livestock 	is livestock stocks in the current market price
		ricestock 	is rices for stock per household 		
		
	4. Liability
		loans 		is total amount borrowed 
		irates		is total amount interest rate per year 
		landc		is expenditures on land rent for agricultural investment 

	5. Household Structure
		hhid 		is the household identification 
		hweight 	is unit sampling weight defined at household level
		province	is province
		urban		is urban or rural region 
		agehead 	is age of head of household 
		genderhead 	is sex of head of household 
		educhead 	is the year of schooling of the head of household
		married 	is marital status 
		hmarried 	is married status per household 
		agemajearn	is age of marjor earner per household, in particular, head of household defined as the major income earner
		single 		is single or non partner status
		divorced 	is divorced status
		nmember 	is the total member of household 
		hmainwork 	is the total hour of work in the main economic activities of the household 
		haddwork 	is the total hour of work in the second economic activities 
		seaswork 	is the household experienced to work in the seasonal economic activities 
		twork 		is the total hour of work both in the main and second economic activities 
		workers 	is household members work for paid and unpaid receptions
		earner 		is household members work for paid receptions 
		retired 	is the number of retired, too old and too young per household 
		unemp 		is unemployed status 
		landcol 	is household experienced to use lands as the collateral to purchase and take something 
*/	

*1. Import derived variable file 
/*******************************************************************************/

cd "$rawdata"

use "personecocurrent", replace 
	sort hhid 
	by hhid: egen wages = total(q15_c20)
	replace wages = wages * 12 

	by hhid: egen hmainwork = total(q15_c09) 
	replace hmainwork = hmainwork * 52 

	by hhid: egen haddwork = total(q15_c16)
	replace haddwork = haddwork * 52 

	gen seaswork = 1 if haddwork > 0 
	replace seaswork = 0 if haddwork == 0

	gen twork = hmainwork + haddwork
	gen workers = (q15_c08 == 1) | (q15_c08 == 2) | (q15_c08 == 3) | (q15_c08 == 4)
	gen retired = (q15_c31==6)
	gen earner = (q15_c08 == 1) | (q15_c08 == 2) | (q15_c08 == 3) // the number of household earners

keep hhid persid wages hmainwork haddwork seaswork twork workers retired earner  
save "cleaning/workingstatus.dta", replace

u "personeducation", replace // education and literacy expenditures in section 2C
	sort hhid 
	rename q02c16h educc1 // individus 
	by hhid: egen educc = total(educc1)
	rename q02c05 educ

keep hhid persid educ educc   
save "cleaning/educ.dta"

use "hhmembers", replace
	sort hhid
	gen agehead = q01ac05a if q01ac06 == 1  
	gen age = q01ac05a
	gen gender = 1 if q01ac03 == 1 // male
	replace gender = 0 if q01ac03 == 2 // female

	gen married = q01ac09 == 1 
	gen single = 1 if q01ac09 == 4
	gen divorced = 1 if q01ac09 == 2
	by hhid: generate nmember = _n // the number of household members
	gen genderhead = gender if q01ac06 == 1 
	gen reltohead = q01ac06

keep hhid persid nmember agehead gender age married single divorced genderhead reltohead
save "cleaning/hhinfo.dta"

use "weightpersons", replace
	rename urbrura urban
	rename hw16a hweight 
	rename pw16a pweight
	
	keep hhid persid urban hweight pweight 

save "cleaning/wight"

u "cleaning/hhinfo", replace 
	merge 1:1 persid using "cleaning/workingstatus.dta"
	drop _merge
	
	merge 1:1 persid using "cleaning/educ.dta"
	drop _merge
	
	merge 1:1 persid using "cleaning/wight"
	drop _merge

	gen agemajearn = age if (agehead > 1) & (workers == 1)
	gen educhead = educ if reltohead == 1 
                  
collapse urban agehead genderhead educhead educc wages hmainwork haddwork seaswork twork (count)nmember (sum)workers (sum)earner (sum)retired (max)agemajearn (mean)ageavg = age (max)agemax = age (min)agemin = age (sum)single (sum)divorced (sum)married (sum)hweight, by (hhid)

	gen unemp = nmember - workers - retired if agemin >= 18
	gen hmarried = 1 if (married >= 2) & (married <= 8)
	replace hmarried = 0 if married == 0

save "cleaning/hhstructure"
	
*Erase the intermediate dataset
	erase "cleaning/workingstatus.dta"
	erase "cleaning/educ.dta"
	erase "cleaning/hhinfo.dta"
	erase "cleaning/wight.dta"

use "hhincomeothersource", replace
	drop if q07_c06 == .
	bysort hhid : egen otherinc = total(q07_c06) // by households in section 7

collapse otherinc, by(hhid) 
save "cleaning/otherinc.dta", replace

u "hhconstruction", replace
	replace q08_c05 = 0 if (q08_c05 == .)
	replace q08_c06 = 0 if (q08_c06 == .)
	replace q08_c08 = 0 if (q08_c08 == .)
	replace q08_c14 = 0 if (q08_c14 == .)
	replace q08_c15 = 0 if (q08_c15 == .)
	replace q08_c16 = 0 if (q08_c16 == .)
	replace q08_c17 = 0 if (q08_c17 == .)
	replace q08_c18 = 0 if (q08_c18 == .)
	replace q08_c19 = 0 if (q08_c19 == .)

	sort hhid

	by hhid: egen buildasset = total(q08_c05) 
	by hhid: egen buildrasset = total(q08_c06)  
	by hhid: egen buildinc = total(q08_c08) 
	replace buildinc = buildinc * 12 

	by hhid: egen buildc1 = total(q08_c14)
	gen constcost = q08_c15 + q08_c16 + q08_c17 + q08_c18 + q08_c19 
	by hhid: egen constc1 = total(constcost) // the cost of construction activities
	gen buildc = buildc1 + constc1

collapse buildasset buildrasset buildinc buildc, by(hhid) 
save "cleaning/building.dta", replace

u "hhlandownership", replace 
	sort hhid 
	replace q05ac04a = 0 if (q05ac04a == .)
	replace q05ac05a = 0 if (q05ac05a == .)
	replace q05ac06a = 0 if (q05ac06a == .)
	replace q05ac08 = 0 if (q05ac08 == .)
	replace q05ac10 = 0 if (q05ac10 == .)
	replace q05ac11 = 0 if (q05ac11 == .)
	replace q05ac20 = 0 if (q05ac20 == .)

	gen landassetrent1 = q05ac04a * 950 if (q05ac04b == 2) & (q05ac04c == 3) 
	replace landassetrent1 = q05ac04a if (q05ac04b == 1) & (q05ac04c == 3) 
	replace landassetrent1 = q05ac04a * 2 if (q05ac04b == 1) & (q05ac04c == 2) 
	replace landassetrent1 = (q05ac04a * 950)* 2 if (q05ac04b == 2) & (q05ac04c == 2) 
	by hhid: egen landrasset = total(landassetrent1) 

	gen landinc1 = q05ac05a if (q05ac05b == 1) & (q05ac05c == 3)
	replace landinc1 = q05ac05a * 2 if (q05ac05b ==1) & (q05ac05c == 2)
	replace landinc1 = q05ac05a * 950 if (q05ac05b ==2) & (q05ac05c == 3)
	replace landinc1 = (q05ac05a * 950)* 2 if (q05ac05b ==2) & (q05ac05c == 2)
	by hhid: egen landinc = total(landinc1) 

	gen landc1 = q05ac06a * 950 if (q05ac06b == 2) & (q05ac06c == 3) 
	replace landc1 = q05ac06a if (q05ac06b == 1) & (q05ac06c == 3) 
	replace landc1 = q05ac06a * 2 if (q05ac06b == 1) & (q05ac06c == 2) 
	replace landc1 = (q05ac06a * 950)* 2 if (q05ac06b == 2) & (q05ac06c == 2)
	by hhid: egen landc = total(landc1) 

	gen landbuy2016 = q05ac10 if q05ac08 == 2016
	gen landbuy2017 = q05ac10 if q05ac08 == 2017

	by hhid: egen landasset = total(q05ac11)

	gen landcollateral1 = 1 if q05ac20 == 1
	replace landcollateral1 = 0 if q05ac20 == 2

	by hhid : egen landcollateral = total(landcollateral1)
	gen landcol = 1 if landcollateral > 0
	replace landcol = 0 if landcollateral == 0

collapse landasset landrasset landinc landc landbuy2016 landbuy2017 landcol, by(hhid) 
save "cleaning/land.dta", replace

u "hhproductioncrops", replace
	sort hhid 
	gen netcropinc = q05bc06 * q05bc09
	by hhid : egen cropinc = total(netcropinc)
	
	gen croprent = q05bc08 * q05bc09 
	by hhid : egen seedinc = total(croprent)
	
	gen lossesrotted = q05bc07 * q05bc09
	by hhid : egen croprotted = total(lossesrotted) // crops losses rotted as the reason of weater and other situations in production process 
		

collapse cropinc seedinc croprotted, by(hhid) 
save "cleaning/cropinc.dta"

u "hhinventorycrops", replace 
	sort hhid
	gen prices = q05dc03
	replace prices = 950 if prices == 0 

	gen riceinc1 = q05dc02a * prices
	by hhid : egen riceinc = total(riceinc1)

	gen ricestock1 = q05dc02b * prices 
	by hhid : egen ricestock = total(ricestock1)

collapse riceinc ricestock, by(hhid) 
save "cleaning/riceinc.dta"

u "hhsalescrops", replace 
	sort hhid
	gen salecropsinc = q05d1c3 * q05d1c4
	by hhid : egen cropsinc = total(salecropsinc)

collapse cropsinc, by(hhid) 
save "cleaning/cropsinc.dta"

u "hhlivestock1", replace 
	sort hhid
	replace q05e1c06 = 0 if (q05e1c06 == .)
	replace q05e1c09 = 0 if (q05e1c09 == .)
	replace q05e1c13 = 0 if (q05e1c13 == .)
	replace q05e1c10 = 0 if (q05e1c10 == .)
	replace q05e1c11 = 0 if (q05e1c11 == .)
	replace q05e1c12 = 0 if (q05e1c12 == .)
	replace q05e1c14 = 0 if (q05e1c14 == .)
	replace q05e1c15 = 0 if (q05e1c15 == .)

	by hhid: egen livestock = total(q05e1c06)
	
	gen livestockinc1 = q05e1c09 + q05e1c13
	by hhid: egen liveinc = total(livestockinc1)
	
	by hhid: egen liveinv1 = total(q05e1c10)
	
	gen livec1 = q05e1c11 + q05e1c12 + q05e1c14 + q05e1c15
	by hhid: egen livec = total(livec1) 
 
collapse livestock liveinc liveinv1 livec, by(hhid) 
save "cleaning/livestockinc.dta"
 
u "hhlivestock2", replace 
	sort hhid
	by hhid: egen liveinv2 = total(q05e2c03)

collapse liveinv2, by(hhid) 
save "cleaning/livestockinv.dta"

u "hhfishcultivation1", replace // net income from pond rent per households in section 5F1
	sort hhid
	by hhid : egen pondasset = total(q05f1c04) // prices of pond if buying 
	gen pondinc1 = q05f1c05 * 12 if q05f1c02 == 2
	by hhid : egen pondinc = total(pondinc1) // from rent 

collapse pondasset pondinc, by(hhid) 
save "cleaning/pondasset.dta"

u "hhfishcultivation2", replace // net expense from fish cultivation and fishing in section 5F3
	sort hhid 
	by hhid: egen fishinv = total(q05f2c03) // household spend on fish cultivation

collapse fishinv, by(hhid) 
save "cleaning/fishinv.dta" 

u "hhfishcultivation3", replace // net income from fish cultivation and fishing in section 5F3
	sort hhid 
	by hhid: egen fishinc = total(q05f3c03)

collapse fishinc, by(hhid) 
save "cleaning/fishinc.dta"

u "hhforestryhunting1", replace // net income from foresty per households in section 5G1
	sort hhid 
	by hhid: egen forestryinc = total(q05g1c03)
	
	gen forestryc1 = q05g1c04 + q05g1c05
	by hhid: egen forestryc = total(forestryc1) // household consumes forestry products in the last 12 months, household gives for gifts of forestry products in the last 12 months

collapse forestryinc forestryc, by(hhid) 
save "cleaning/forestryinc.dta"

u "hhforestryhunting2", replace 
	sort hhid 
	by hhid: egen forestryinv = total(q05g2c03) // household spend on forestry activities

collapse forestryinv, by(hhid) 
save "cleaning/forestryinv.dta"

u "hhnonagriculture2", replace // net investment per households (do bussiness in section 5H3
	sort hhid 
	replace q05h2c03 = 0 if (q05h2c03 == .)
	replace q05h2c04 = 0 if (q05h2c04 == .)
	replace q05h2c05 = 0 if (q05h2c05 == .)
	replace q05h2c06 = 0 if (q05h2c06 == .)
	replace q05h2c07 = 0 if (q05h2c07 == .)
	replace q05h2c08 = 0 if (q05h2c08 == .)
	
	gen inv = q05h2c03 + q05h2c04 + q05h2c05 + q05h2c06 + q05h2c07 + q05h2c08
	by hhid: egen nonagriinv = total(inv)

collapse nonagriinv, by(hhid) 
save "cleaning/nonagriinv.dta"

u "hhnonagriculture3", replace // net incomes from investment per households (do bussiness in section 5H3
	sort hhid 
	replace q05h3c03 = 0 if (q05h3c03 == .)
	replace q05h3c04 = 0 if (q05h3c04 == .)
	replace q05h3c05 = 0 if (q05h3c05 == .)
	replace q05h3c06 = 0 if (q05h3c06 == .)
	replace q05h3c07 = 0 if (q05h3c07 == .)
	replace q05h3c08 = 0 if (q05h3c08 == .)

	gen incomes = q05h3c03 + q05h3c04 + q05h3c05 + q05h3c06 + q05h3c07 + q05h3c08
	by hhid: egen nonagriinc = total(incomes)

collapse nonagriinc, by(hhid) 
save "cleaning/nonagriinc.dta"

u "hhfoodconsumption", replace // food, beverages and tobacco consumption per househoulds during the last 7 days in section 1B
	sort hhid 
	by hhid: egen foodc = total(q01bc03) // both purchased and own production
	replace foodc = foodc * 52 // food consumption per year 

collapse foodc, by(hhid) // need to check with the Italy Survey 
save "cleaning/foodc.dta"

u "hhrecallnonfood", replace // non-food expenditures per households in section 1C
	sort hhid 
	by hhid: egen c1 = total(q01cc04) if q01cc01 <= 7

	by hhid: egen c2 = total(q01cc04) if q01cc01 == 8
	replace c2 = c2 * 12 // per year 

	by hhid: egen c3 = total(q01cc04) if (q01cc01 == 9) | (q01cc01 == 10)
	replace c3 = c3 * 3 // per year 

	by hhid: egen c4 = total(q01cc04) if (q01cc01 >= 11) & (q01cc01 <= 15)

	by hhid: egen c5 = total(q01cc04) if (q01cc01 >= 16) & (q01cc01 <= 23)
	replace c5 = c5 * 12 // per year 

	by hhid: egen c6 = total(q01cc04) if (q01cc01 >= 24) & (q01cc01 <= 27)
	replace c6 = c6 * 2 // per year 

	by hhid: egen c7 = total(q01cc04) if (q01cc01 == 28)
	
	by hhid: egen c8 = total(q01cc04) if (q01cc01 >= 29) & (q01cc01 <= 31)
	replace c8 = c8 * 12 // per year 

	by hhid: egen c9 = total(q01cc04) if (q01cc01 >= 32) & (q01cc01 <= 33)
	replace c9 = c9 * 2 // per year 

	by hhid: egen c10 = total(q01cc04) if q01cc01 == 34
	
	by hhid: egen tax = total(q01cc04) if (q01cc01 >= 35) & (q01cc01 <= 36)
	
	by hhid: egen c11 = total(q01cc04) if (q01cc01 >= 37) & (q01cc01 <= 40)
	
	replace c1 = 0 if (c1 == .)
	replace c2 = 0 if (c2 == .)
	replace c3 = 0 if (c3 == .)
	replace c4 = 0 if (c4 == .)
	replace c5 = 0 if (c5 == .)
	replace c6 = 0 if (c6 == .)
	replace c7 = 0 if (c7 == .)
	replace c8 = 0 if (c8 == .)
	replace c9 = 0 if (c9 == .)
	replace c10 = 0 if (c10 == .)
	replace tax = 0 if (tax == .)
	replace c11 = 0 if (c11 == .)

	gen nonfoodc = c1 + c2 + c3 + c4 + c5 + c6 + c7 + c8 + c9 +c10 + c11

collapse nonfoodc tax, by(hhid)
save "cleaning/nonfoodc.dta"

u "hhhousing", replace // expenditures on the dwelling last month in section 4
	sort hhid
	gen housec1 = q04_16 + q04_20 + q04_21 + q04_27a + q04_27b + q04_27c + q04_27d + q04_27e + q04_27f + q04_27g
	// waterc + sewagec + garbagec + energyc	
	replace housec1 = housec * 12 // per year 
	by hhid: egen housec = total(housec)
	by hhid: egen houserentc = total(q04_29a)
	replace houserentc = houserentc * 12

	by hhid: egen houseasset = total(q04_29b)
	replace houseasset = houseasset * 12

	by hhid: egen dwellingc = total(q04_30)

collapse housec houserentc houseasset dwellingc, by(hhid)
save "cleaning/house.dta"

u "hhcostcultivationcrops", replace 
	sort hhid
	by hhid: egen cropinv = total(q05cc16)

collapse cropinv, by(hhid)
save "cleaning/cropinv.dta"

u "hhliabilities", replace 
	sort hhid 
	by hhid: egen loans = total(q06_c06) // total credits from the bank and others
	by hhid: egen irate = total(q06_c08) 
	gen irates = irate * 12 // the interest rate per year as credits 

collapse loans irates, by(hhid)
save "cleaning/loans.dta"

u "hhdurablegoods", replace 
	sort hhid 
	by hhid: egen dgoodsc = total(q09_c07) // bought or received durable goods in the last 12 months
	by hhid: egen dgoodsasset = total(q09_c08) // bought or received durable goods before the last 12 months

collapse dgoodsc dgoodsasset, by(hhid)
save "cleaning/dgood.dta"

u "personillness", replace 
	sort hhid 
	gen illnessc1 = q13bc10 + q13bc11
	by hhid: egen illnessc = total(illnessc1)
	replace illnessc = illnessc * 5 // we asumme 5 month 

collapse illnessc, by(hhid)
save "cleaning/illnessc.dta"

u "weighthouseholds", replace
	sort psu
	merge m:1 psu using "psulisting"
	rename province_name province
	keep hhid province 
save "cleaning/province"	

*2. Merge all datasets into a file 
/*******************************************************************************/

u "cleaning/hhstructure", replace 
	merge 1:1 hhid using "cleaning/building.dta"
	drop _merge
	merge 1:1 hhid using "cleaning/cropinc.dta"
	drop _merge
	merge 1:1 hhid using "cleaning/cropinv.dta"
	drop _merge
	merge 1:1 hhid using "cleaning/cropsinc.dta"
	drop _merge
	merge 1:1 hhid using "cleaning/dgood.dta"
	drop _merge
	merge 1:1 hhid using "cleaning/fishinc.dta"
	drop _merge
	merge 1:1 hhid using "cleaning/fishinv.dta"
	drop _merge
	merge 1:1 hhid using "cleaning/foodc.dta"
	drop _merge
	merge 1:1 hhid using "cleaning/forestryinc.dta"
	drop _merge
	merge 1:1 hhid using "cleaning/forestryinv.dta"
	drop _merge
	merge 1:1 hhid using "cleaning/forestryinv.dta"
	drop _merge	
	merge 1:1 hhid using "cleaning/house.dta"
	drop _merge
	merge 1:1 hhid using "cleaning/illnessc.dta"
	drop _merge
	merge 1:1 hhid using "cleaning/land.dta"
	drop _merge
	merge 1:1 hhid using "cleaning/livestockinc.dta"
	drop _merge
	merge 1:1 hhid using "cleaning/livestockinv.dta"
	drop _merge
	merge 1:1 hhid using "cleaning/loans.dta"
	drop _merge
	merge 1:1 hhid using "cleaning/nonagriinc.dta"
	drop _merge
	merge 1:1 hhid using "cleaning/nonagriinv.dta"
	drop _merge
	merge 1:1 hhid using "cleaning/nonfoodc.dta"
	drop _merge
	merge 1:1 hhid using "cleaning/otherinc.dta"
	drop _merge
	merge 1:1 hhid using "cleaning/pondasset.dta"
	drop _merge
	merge 1:1 hhid using "cleaning/loans.dta"
	drop _merge
	merge 1:1 hhid using "cleaning/nonagriinc.dta"
	drop _merge
	merge 1:1 hhid using "cleaning/riceinc.dta"
	drop _merge
	merge 1:1 hhid using "cleaning/province.dta"
	drop _merge

	replace wages = 0 if (wages == .)
	replace nonagriinc = 0 if (nonagriinc == .)
	replace cropsinc = 0 if (cropsinc == .)
	replace cropinc = 0 if (cropinc == .)
	replace riceinc = 0 if (riceinc == .)
	replace seedinc = 0 if (seedinc == .)
	replace liveinc = 0 if (liveinc == .)
	replace fishinc = 0 if (fishinc == .)
	replace pondinc = 0 if (pondinc == .)
	replace forestryinc = 0 if (forestryinc == .)
	replace landinc = 0 if (landinc == .)
	replace buildinc = 0 if (buildinc == .)
	replace otherinc = 0 if (otherinc == .)
	
	replace foodc = 0 if (foodc == .)
	replace livec = 0 if (livec == .)
	replace forestryc = 0 if (forestryc == .)
	replace nonfoodc = 0 if (nonfoodc == .)
	replace dgoodsc = 0 if (dgoodsc == .)
	replace housec = 0 if (housec == .)
	replace dwellingc = 0 if (dwellingc == .)
	replace landbuy2016 = 0 if (landbuy2016 == .)
	replace landbuy2017 = 0 if (landbuy2017 == .)
	replace buildc = 0 if (buildc == .)
	replace educc = 0 if (educc == .)
	replace illnessc = 0 if (illnessc == .)

	replace dgoodsasset = 0 if (dgoodsasset == .)
	replace houseasset = 0 if (houseasset == .)
	replace pondasset = 0 if (pondasset == .)
	replace landasset = 0 if (landasset == .)
	replace landrasset = 0 if (landrasset == .)
	replace buildasset = 0 if (buildasset == .)
	replace buildrasset = 0 if (buildrasset == .)
	replace nonagriinv = 0 if (nonagriinv == .)
	replace cropinv = 0 if (cropinv == .)
	replace liveinv1 = 0 if (liveinv1 == .)
	replace liveinv2 = 0 if (liveinv2 == .)
	replace fishinv = 0 if (fishinv == .)
	replace forestryinv = 0 if (forestryinv == .)
	replace livestock = 0 if (livestock == .)
	replace ricestock = 0 if (ricestock == .)
	
	replace loans = 0 if (loans == .)
	replace irates = 0 if (irates == .)
	replace landc = 0 if (landc == .)
		 	
	encode hhid, generate(hhid1)
	order hhid1 hhid
	drop hhid
	rename hhid1 hhid
	order hhid province
	
save "$data/CSES2017"	
/*******************************************************************************/
