*! Version 1.0.0 Mehrab Ali 25Nov2020

* change of delimit and make lines - done
* Comment block "/*" - done
* inside comment block /* */ - done
* Drop /// from second line - done
* Program define drop and drop from install list - done
* : after capture qui etc - done
* if `dataprep' 		do "${dos}/01_data.do" - This is tricky. 
			/* The current commands can only consider command only if the exp followed by if command is one word */
* Include and do files/ado files - tricky

version 	12.0

cap pr drop findcmd
prog def findcmd, rclass
	
	syntax using/

	qui {
	tempfile currentdata
	save `currentdata', emptyok

	local path `"`c(sysdir_plus)'"'
	
	insheet using "`path'/f/findcmd_commands.txt", clear 
	levelsof v1, loc(bcmdlist) clean

	import delim using "`using'", stringcols(_all) clear 

		* Split and find out the commands
			g command = ""
			ds command, not
			foreach var of varlist `r(varlist)' {
				replace command = command + `var' + " " 
			}

			replace command = subinstr(command, ":", "", .) 			 // Get rid of : after commands
			replace command = regexr(command, "\/\*(.)+\*\/", "") 		 // Get rid of in line comments
			replace command = substr(command, 1, strpos(command, "// ") - 2)  if strpos(command, "//") & !strpos(command, "///") // Get rid of in line comments 		

			split command, gen(var)
			replace var1 = trim(var1)
			replace var1 = trim(var2) if inlist(var1, "cap", "capture", "qui", "quitely", "n", "noi", "noisily")


		* Comment block
			gen start = 1 if regex(var1, "^\/\*")
			gen end = 1 if regex(command, "\*\/")
			g startcount = .
			g endcount 	 = .

			loc i = 1
			forval x=1/`=_N' {
				if start[`x']==1 {
					replace startcount = `i' in `x' 
					loc ++i
				}			
			}

			loc i = 1
			forval x=1/`=_N' {
				if end[`x']==1 {
					replace endcount = `i' in `x' 
					loc ++i
				}
			}

			gen grp_var 		= .
			gen begin_row 		= .
			gen begin_fieldname = .
			gen end_row			= .
			gen end_fieldname 	= .
			gen _sn 			= _n

			levelsof _sn if start==1,	loc (_sns) clean

					foreach _sn in `_sns' {	

						loc b 1
						loc e 0
						loc curr_sn `_sn'
						loc stop 0
						while `stop' == 0 {
							loc ++curr_sn 
						
							if end[`curr_sn']==1  {
								loc ++e
								if `b' == `e' {
									loc end `curr_sn'
									loc stop 1
								}
							}
							else {
								replace grp_var = 1 in `curr_sn'
								if start[`curr_sn']==1 loc ++b
							}
						}

						replace begin_row 		= 	_sn[`_sn']			in `_sn'
						replace begin_fieldname =	startcount[`_sn']	in `_sn'
						replace end_row 		= 	_sn[`end']			in `_sn'
						replace end_fieldname 	=	endcount[`end']		in `_sn'
					}

					replace grp_var 	= 0 if missing(grp_var)		

		* Change of delimit
			replace var1 = "#delimit" if inlist(var1, "#d", "#delim") 

			* Create identifier for the block
				gen delim = ""

				replace delim = ";" if var1 == "#delimit" & var2==";"
				replace delim = "cr" if var1 == "#delimit" & var2=="cr"
				replace delim = delim[_n-1] if mi(delim)

			* Add the in line commands 
				split command, p(";") gen(spvar)

				if `r(nvars)'>1 {
					ds spvar*
					
					forval i = 2(2)1000 {
						cap confirm var spvar`i'
						if _rc {
							continue, break
						}
						split spvar`i', gen(spcmd`i'_)
					}	
					
					ds spcmd*_1 
					foreach var in `r(varlist)' {
						levelsof `var', clean loc(`var'list)

						foreach cmd of local `var'list {
							set obs `=_N+1'
							replace var1 = "`cmd'" in `=_N'
						}
					}
				}

			* Drop the delimit change line 
				drop if inlist(var1, "#d", "#delimit", "#delim") 

		* Drop unnecessary lines
			drop if inlist(var1, "{", "}", "//", "") | delim==";" | grp_var==1 | start==1 | end==1 ///
					| regex(command[_n-1], "///")==1 | regex(var1, "^(\*)") ==1

		* In line cmd combining with if 
			gen varif = ""
			replace varif = trim(command) if var1=="if" & !regexm(command, "{")
			cap split varif, gen(cmdif)
			cap conf v cmdif3
			if !_rc {
				levelsof cmdif3, clean loc(ifs)
				foreach ifcmd of local ifs {
					set obs `=_N+1'
					replace var1 = "`ifcmd'" in `=_N'
				}
			}
			

		* Clean the cmd list
			replace var1 = subinstr(var1, ",", "", .)
			replace var1 = subinstr(var1, "+", "", .)
			replace var1 = subinstr(var1, "=", "", .)
		
		* User defined programs 
			replace var1 = "program" if inlist(var1, "pr", "prog")
			replace var2 = "define"	 if var1=="program" & !inlist(var2, "dir", "di", "drop", "list", "l")
			
			count if var1 == "program" & var2 == "define"

			if r(N)>0 {
				split command if var1 == "program" & var2 == "define",	gen (userp)  
				cap replace userp3 = "end" if var1=="end"
				replace userp3 = userp3[_n-1] if mi(userp3)
				levelsof userp3 if userp3!="end", clean loc(defined)
				return loc defined = "`defined'"
				drop if (userp3 != "end" & !mi(userp3)) | var1 == "end"
			}

		* Bring in the cmd list
			levelsof var1, clean loc(cmdlist)
			loc notfound : list cmdlist - bcmdlist
			loc usercmd  : list notfound - defined
			loc abuiltin : list cmdlist - usercmd
			loc abuiltin : list abuiltin - defined

			
			return scalar builtin_N = wordcount("`abuiltin'")
			return scalar usercmd_N = wordcount("`usercmd'")
			return scalar defined_N = wordcount("`defined'")

			return loc builtin  "`abuiltin'"
			return loc usercmd  "`usercmd'"

		* Listing down do and ado included
		replace command = regexr(command, `""(.)+do+(.)+""', "") //  Get rid of in line strings insdie quotes
			cap split command, p("do " "include ") gen(dof)
			if `r(nvars)'>1 {
				//replace dof2 = subinstr(dof2, `"""', "",.)
				replace dof2 = regexr(dof2, "\.$", "")
				levelsof dof2, clean loc(indos)	
				return scalar do_N = `r(N)'
				return loc indos  `indos'
			}
			else {
				return scalar do_N = 0
			}		
	}

	u `currentdata', clear 
	noi di `"The do file "`using'" is successfully parsed."', _n
	if "`abuiltin'" != "" noi di `"		Built-in commands: `abuiltin'"'
	if "`usercmd'" != ""  noi di `"		User written commands: `usercmd'"'
	if "`defined'" != ""  noi di `"		Defined programs: `defined'"'
	noi di `"{stata "return list":{it:click to see return list}}"'
end 

