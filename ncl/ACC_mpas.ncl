; ACC.ncl
;==========================================================================
; Compute Anomaly Correlation Coefficient (ACC) as the centered correlation
; between forecast and analysis (or observed) anomalies.
; 
; For a certain foreacast lead time,
; 
; Input files: xa (Analysis)     ex) mpas_init.nc
;              xf (Forecast)     ex) mpas_diag.nc
;               C (Climatology)  ex) hgt.4Xday.1981-2010.ltm.nc
;           => xc at the same time and space as in xa and xf
; 
;    fp = xf - xc at each mpas grid point m
;    ap = xa - xc at each mpas grid point m
;    fave = mean(fp) as area-weighted forecast anomaly mean
;    aave = mean(ap) as area-weighted analysis anomaly mean
;    fprime = fp - fave
;    aprime = ap - aave
;    fstd = stddev(fprime) as area-weighted standard deviation of forecast anomaly
;    astd = stddev(aprime) as area-weighted standard deviation of analysis anomaly
;
; Output:        area_weighted_sum((fp - fave)*(ap - aave))
;         ACC = --------------------------------------------
;                       sum(area) * fstd * astd 
; 
; Note: The climate data is provided at 2.5 x 2.5 degree resolution,
;       thus projected onto the MPAS unstructured mesh before computing
;       anomaly correlation coefficient.
;
; Soyoung Ha (MMM/NCAR) Sep-1-2016
;==========================================================================
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"

;--------------------------------------------------------------------------
; User defined parameters
;--------------------------------------------------------------------------
    xgrid = "x4.535554"				; mpas grid
    fcsth = 120					; forecast time to compute ACC in [hr]
    ifcst = 21					; Process the {ifcst}th file at each cycle (1-based index)
    x_var = "height"				; field name
    p_lev = 500.				; isobaric level
   p_unit = "hPa"				; level unit
     xvar = x_var + "_" + p_lev + p_unit	; mpas forecast variable name
     cvar = "HGT_3_ISBL_S51"				; climate data variable name
     pvar = "pressure_diag"
     yyyy = 2016	; year for the case
     zulu = "00"	; UTC time to compute ACC

  iregion = 0					; 0-based index
  regions = (/"NH","Tropics","Globe"/)	
     lat1 = (/ 20.,   -20.,    -90. /)
     lat2 = (/ 80.,    20.,     90. /)
   region = regions(iregion)

  sub_dir = "cold"	; "warm" from EnKF analyses, "cold" from FNL analyses
 work_dir = "/glade/p/mmm/syha/ACC/"
 work_dir = "/glade/scratch/ahijevyc/mpas50_3/"
 clim_dir = "/glade/p/mmm/syha/ACC/"
; anal_dir = "/glade/p/nmmm0024/syha/MPAS_DART/FNL/" + xgrid + "/"
; fcst_dir = "/glade/scratch/syha/MPAS_DART/x4.133890.LSFC.CUT2/EXT_FCST_IAUfix.6dx/"
expn_name = xgrid + "." + sub_dir

   F_file = "diag"			; mpas forecast
   C_file = clim_dir+"hgt.4Xday.1959-1988.ltm.nc"	; climate data
     ;fmap = "/glade/p/nmmm0024/syha/MPAS_DART/FNL/" + xgrid + "/" + xgrid + ".init.2012052500.nc"		; mpas static info
     fmap = work_dir + "2015050100/init.nc"		; mpas static info
     if(yyyy.eq.2016)then
       fmap = "/glade/p/work/ahijevyc/mpas_plots/mpas15_3/init.nc"		; mpas static info
     end if

; OUTPUT
 fout_asc = "ACC." + region + "." + xvar + ".David." + xgrid + "." + sub_dir + ".txt" ;+ zulu + "Z.txt"
  if_plot = True	; Plot ACC in time series? True or False
     ffmt = "png"	; figure format
     ffig = "ACC." + region + "." + xvar + ".David." + xgrid + "." + sub_dir ;+ "." + zulu + "Z"
;--------------------------------------------------------------------------
; End user defined parameters
;--------------------------------------------------------------------------
print("")
print("ACC.ncl: Computing anomaly correlation coefficient in MPAS forecasts")	;"+fcsth+" h forecast")
print("         for " + xvar + " in " + expn_name)
print("")

; Map info in MPAS unstructured grid
;--------------------------------------------------------------------------
fm = addfile(fmap,"r")
r2d = 57.29579
xlat = fm->latCell * r2d
xlon = fm->lonCell * r2d
area = fm->areaCell
 ndx = dimsizes(area)

if(region.eq."Globe") then
   idx = ispan(0,ndx-1,1)
else
   idx = ind(xlat.ge.lat1(iregion).and.xlat.le.lat2(iregion))
   ndx = num(xlat.ge.lat1(iregion).and.xlat.le.lat2(iregion))
   area := area(idx)
end if
print("         processed over "+region+" ("+ndx+" cells)")

; MPAS analysis and forecast files
;--------------------------------------------------------------------------
;cycle  = systemfunc("ls -d " + fcst_dir + yyyy + "*")	; + zulu)
;cycles = cycle(:)
;ncycle = dimsizes(cycles)	; sample time period
;print("Processing " + ncycle + " cycles...")
;print(cycles+"")
;print("")
; listA = new(ncycle,string)
; listF = new(ncycle,string)
;do icyc = 0, ncycle-1
;   flist := systemfunc("csh -c 'cd " + cycles(icyc) + "/" + sub_dir + "; ls " + F_file + "*.nc'")
;   if(dimsizes(flist).ne.ifcst) then
;      print("We assume " + ifcst + " forecast files. Check " + F_file + " files in " + fcst_dir)
;      exit
;   end if 
;   listA(icyc) = anal_dir + flist(ifcst-1)
;   listF(icyc) = cycles(icyc) + "/" + sub_dir + "/" + flist(ifcst-1)
;end do
listA = (/ "/glade/scratch/ahijevyc/mpas50_3/2015050600/diagnostics.2015-05-06_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas50_3/2015050700/diagnostics.2015-05-07_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas50_3/2015050800/diagnostics.2015-05-08_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas50_3/2015050900/diagnostics.2015-05-09_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas50_3/2015051000/diagnostics.2015-05-10_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas50_3/2015051100/diagnostics.2015-05-11_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas50_3/2015051200/diagnostics.2015-05-12_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas50_3/2015051300/diagnostics.2015-05-13_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas50_3/2015051400/diagnostics.2015-05-14_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas50_3/2015051500/diagnostics.2015-05-15_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas50_3/2015051600/diagnostics.2015-05-16_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas50_3/2015051700/diagnostics.2015-05-17_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas50_3/2015051800/diagnostics.2015-05-18_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas50_3/2015051900/diagnostics.2015-05-19_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas50_3/2015052000/diagnostics.2015-05-20_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas50_3/2015052100/diagnostics.2015-05-21_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas50_3/2015052200/diagnostics.2015-05-22_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas50_3/2015052300/diagnostics.2015-05-23_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas50_3/2015052400/diagnostics.2015-05-24_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas50_3/2015052500/diagnostics.2015-05-25_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas50_3/2015052600/diagnostics.2015-05-26_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas50_3/2015052700/diagnostics.2015-05-27_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas50_3/2015052800/diagnostics.2015-05-28_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas50_3/2015052900/diagnostics.2015-05-29_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas50_3/2015053000/diagnostics.2015-05-30_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas50_3/2015053100/diagnostics.2015-05-31_00.00.00.nc" /)

listF = (/ "/glade/scratch/ahijevyc/mpas50_3/2015050100/diagnostics.2015-05-06_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas50_3/2015050200/diagnostics.2015-05-07_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas50_3/2015050300/diagnostics.2015-05-08_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas50_3/2015050400/diagnostics.2015-05-09_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas50_3/2015050500/diagnostics.2015-05-10_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas50_3/2015050600/diagnostics.2015-05-11_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas50_3/2015050700/diagnostics.2015-05-12_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas50_3/2015050800/diagnostics.2015-05-13_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas50_3/2015050900/diagnostics.2015-05-14_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas50_3/2015051000/diagnostics.2015-05-15_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas50_3/2015051100/diagnostics.2015-05-16_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas50_3/2015051200/diagnostics.2015-05-17_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas50_3/2015051300/diagnostics.2015-05-18_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas50_3/2015051400/diagnostics.2015-05-19_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas50_3/2015051500/diagnostics.2015-05-20_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas50_3/2015051600/diagnostics.2015-05-21_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas50_3/2015051700/diagnostics.2015-05-22_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas50_3/2015051800/diagnostics.2015-05-23_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas50_3/2015051900/diagnostics.2015-05-24_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas50_3/2015052000/diagnostics.2015-05-25_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas50_3/2015052100/diagnostics.2015-05-26_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas50_3/2015052200/diagnostics.2015-05-27_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas50_3/2015052300/diagnostics.2015-05-28_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas50_3/2015052400/diagnostics.2015-05-29_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas50_3/2015052500/diagnostics.2015-05-30_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas50_3/2015052600/diagnostics.2015-05-31_00.00.00.nc" /)

if(yyyy.eq.2016)then
listA := (/"/glade/scratch/ahijevyc/mpas15_3/2016050100/diag.2016-05-01_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016050200/diag.2016-05-02_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016050300/diag.2016-05-03_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016050400/diag.2016-05-04_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016050500/diag.2016-05-05_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016050600/diag.2016-05-06_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016050700/diag.2016-05-07_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016050800/diag.2016-05-08_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016050900/diag.2016-05-09_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016051000/diag.2016-05-10_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016051100/diag.2016-05-11_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016051200/diag.2016-05-12_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016051300/diag.2016-05-13_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016051400/diag.2016-05-14_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016051500/diag.2016-05-15_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016051600/diag.2016-05-16_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016051700/diag.2016-05-17_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016051800/diag.2016-05-18_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016051900/diag.2016-05-19_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016052000/diag.2016-05-20_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016052100/diag.2016-05-21_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016052200/diag.2016-05-22_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016052300/diag.2016-05-23_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016052400/diag.2016-05-24_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016052500/diag.2016-05-25_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016052600/diag.2016-05-26_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016052700/diag.2016-05-27_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016052800/diag.2016-05-28_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016052900/diag.2016-05-29_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016053000/diag.2016-05-30_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016053100/diag.2016-05-31_00.00.00.nc" /)

listF :=(/ "/glade/scratch/ahijevyc/mpas15_3/2016042600/diag.2016-05-01_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016042700/diag.2016-05-02_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016042800/diag.2016-05-03_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016042900/diag.2016-05-04_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016043000/diag.2016-05-05_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016050100/diag.2016-05-06_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016050200/diag.2016-05-07_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016050300/diag.2016-05-08_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016050400/diag.2016-05-09_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016050500/diag.2016-05-10_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016050600/diag.2016-05-11_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016050700/diag.2016-05-12_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016050800/diag.2016-05-13_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016050900/diag.2016-05-14_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016051000/diag.2016-05-15_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016051100/diag.2016-05-16_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016051200/diag.2016-05-17_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016051300/diag.2016-05-18_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016051400/diag.2016-05-19_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016051500/diag.2016-05-20_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016051600/diag.2016-05-21_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016051700/diag.2016-05-22_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016051800/diag.2016-05-23_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016051900/diag.2016-05-24_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016052000/diag.2016-05-25_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016052100/diag.2016-05-26_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016052200/diag.2016-05-27_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016052300/diag.2016-05-28_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016052400/diag.2016-05-29_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016052500/diag.2016-05-30_00.00.00.nc", \
           "/glade/scratch/ahijevyc/mpas15_3/2016052600/diag.2016-05-31_00.00.00.nc" /)
end if


ncycle = dimsizes(listA)
xtimes = ispan(0,ncycle-1,1)
 acc_t = new(ncycle,float)	; final output - Anomaly Correlation Coefficient (ACC)
fa = addfiles(listA, "r")
ff = addfiles(listF, "r")
ta = str_strip(tostring(fa[:]->xtime))
tf = str_strip(tostring(ff[:]->xtime))
print(ta)
print(tf)
if(any(tf.ne.ta)) then
   print("Time mismatch: "+ta+" vs. "+tf)
   exit
end if

; Read the forecast field (F)
;--------------------------------------------------------------------------
if(isfilevar(ff[0],xvar)) then
   xa = fa[:]->$xvar$
   xf = ff[:]->$xvar$
else
   xv = x_var + "_diag"
    p = ff[0]->$pvar$
    k = ind(p.eq.p_lev)
   xa = fa[:]->$xv$(:,:,k)	; [Time | 30] x [nCells | 40962]
   xf = ff[:]->$xv$(:,:,k)	; [Time | 30] x [nCells | 40962]
end if
printVarSummary(xf)
 
; Read the climate data
;--------------------------------------------------------------------------
fc = addfile(C_file,"r")
clon = fc->lon		;   [lon | 144]  (  0, 357.5 )
clat = fc->lat		;   [lat | 73]   ( 90, -90 )
clev = fc->level	; [level | 17] ( 1000, 10 )
ctim = fc->time		;  [time | 1460] [-15769752..-15760998]
xclm = fc->$cvar$	;  [time | 1460] x [level | 17] x [lat | 73] x [lon | 144]
print(xclm@long_name + " in " + xclm@units)

ck = -1
if(clev@units.eq.p_unit) then
  ck = ind(clev.eq.p_lev)
end if

; Find the time matched with MPAS forecast time (in UTC),
; matching up to the time and the day of the year
;--------------------------------------------------------------------------
nclm = dimsizes(ctim)	;[time | 1460]
  tc = new(nclm,string)
idxF = new(ncycle,integer)

  tutc = cd_calendar(ctim, 0) 
month  = toint(tutc(:,1))
day    = toint(tutc(:,2))
hour   = toint(tutc(:,3))

tc = yyyy + "-" + sprinti("%0.2i",month) + "-" + sprinti("%0.2i",day) + "_" + sprinti("%0.2i",hour) +":00:00"
do icyc = 0, ncycle-1
   idxF(icyc) = ind(tc.eq.tf(icyc))
end do
;print(fcsth + "h forecast at these times...")
print("      Analysis  and    Forecast time")
print(""+tc(idxF))
print("")

; Project climate data onto the MPAS grid
;--------------------------------------------------------------------------
xm = xclm(idxF,ck,:,:)		         ; climate data at analysis times [time | 30] x [lat | 73] x [lon | 144]
ca = linint2_points_Wrap(xm&lon,xm&lat(::-1),xm(:,::-1,:),True,xlon,xlat,0)	; [time | 30] x [pts | 40962]
printMinMax(ca,0)
printMinMax(xa,0)

; Compute anomalies from climatology
;--------------------------------------------------------------------------
ap = xa(:,idx) - ca(:,idx)
fp = xf(:,idx) - ca(:,idx)
printVarSummary(ap)
printVarSummary(area)

; Compute anomaly correlation coefficient
;--------------------------------------------------------------------------
do icyc = 0, ncycle-1
   aave = sum(ap(icyc,:)*area)/sum(area)	; area-weighted mean [time | 30]
   fave = sum(fp(icyc,:)*area)/sum(area)	; area-weighted mean [time | 30]
   aprime = ap(icyc,:) - aave
   fprime = fp(icyc,:) - fave
   astd = sqrt(sum(aprime^2.*area)/sum(area))
   fstd = sqrt(sum(fprime^2.*area)/sum(area))
   acc_t(icyc) = sum(fprime*aprime*area)/(fstd*astd*sum(area))
end do
print(tc(idxF)+" "+acc_t)
print("AVERAGE:"+avg(acc_t))

; Write ACC in the output file
;--------------------------------------------------------------------------
data_out = tc(idxF) + sprintf("%10.5f",acc_t)
asciiwrite(fout_asc, data_out)
system("ls -l " + fout_asc)

; Plot
;--------------------------------------------------------------------------
if(if_plot) then

   wks = gsn_open_wks(ffmt,ffig)
   stimes = str_get_cols(tc(idxF),0,9)	;12)
   res = True
   res@xyLineThicknessF = 5.0
   res@xyDashPatterns   = "SolidLine"   
   res@xyLineColors     = (/"blue","red","orange"/)
   res@xyMarkLineMode = "MarkLines"
   res@xyMarkerColors = res@xyLineColors
   res@xyMarker = 16
   res@tmXBMode = "Explicit"
   res@tmXBValues = xtimes
   res@tmXBLabels = stimes
   res@tmXBLabelStride = 2
   res@tmXBLabelAngleF = 90.

   res@tiMainString  = expn_name + ": " + xvar + " (" + region + ")"
   res@tiYAxisString = "ACC"
   plot = gsn_csm_xy(wks,xtimes,acc_t,res)
   system("ls -l "+ffig+"."+ffmt)
end if