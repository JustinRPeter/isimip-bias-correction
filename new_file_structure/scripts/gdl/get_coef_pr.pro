; based on
; gdl_routines/v2/calc_P_cor_coeff_mon.pro
; gdl_routines/v2/calc_O_cor_coeff_mon.pro
; of ISIMIP Fast Track Bias Correction Code


pro get_coef_pr,ipathobs,ipathgcm,opath,CONSTRUCTION_PERIOD_START,CONSTRUCTION_PERIOD_STOP,mon,NUMLANDPOINTS,land,cutoff_mean,precip_cutoff,cutoff_raindays,idlfactor
; mon = 0..11
; cutoff_raindays = 80            ; number of days required to do the fit (dry days and outlier excluded)
; cutoff_mean = 0.01              ; cut-off for monthly mean value in OBS to be considered as dry
; precip_cutoff = 0.1


print,'using '+ipathgcm+' and '+ipathobs+' to get transfer function coefficients stored in ' +opath


; read OBS data
cmrestore,ipathobs
pr_o = idldata*idlfactor


; initialize some constants and arrays
top = n_elements(pr_o(0,*))
l = top
construction_period_length = CONSTRUCTION_PERIOD_STOP*1L-CONSTRUCTION_PERIOD_START*1L+1
monlength = l/construction_period_length
fullmean_x = fltarr(NUMLANDPOINTS)
fullmean_y = fltarr(NUMLANDPOINTS)
meanratio = fltarr(NUMLANDPOINTS)
extremes = fltarr(NUMLANDPOINTS,2)


; read GCM data
cmrestore,ipathgcm
pr_e = idldata*idlfactor
idldata=0


; check for negative values in input data
print,'checking for negative values in input data ...'
IF (min(pr_e) LT -1e-6) THEN BEGIN
   print,'negative values in GCM data !!! exiting ...'
   STOP
ENDIF
IF (min(pr_o) LT -1e-6) THEN BEGIN
   print,'negative values in OBS data !!! exiting ...'
   STOP
ENDIF
print,'... check passed'


; initialize several arrays for transfer function coefficients
fit_type=land*0.0               ; to keep track of the type of fit used.
i0_val  =land*0.0               ; the number of dry days at each grid box.
top_val =land*0.0               ; the value where outliers are removed.
error_pr=land*0.0+1e+33         ; an error field.
X0_pr   =land*0.0+1e+33         ; an index above which model precip > 0
a_pr    =land*0.0+1e+33         ; the offset fit parameter
b_pr    =land*0.0+1e+33         ; the slope fit parameter
tau_pr  =land*0.0+1e+33         ; the decay coefficient in the exponential
meany_val=land*0.0
s_e = fltarr(NUMLANDPOINTS)     ; threshold for dry days in model data
s_o = fltarr(NUMLANDPOINTS)     ; threshold for dry days in OBS
s_m = fltarr(NUMLANDPOINTS)     ; threshold for dry months in model data


; find start index of each year, account for leap years
start_new_month = findgen(construction_period_length)*monlength
if (mon eq 1) then begin
   monthlength=28
   leap=0
   for ii=1,construction_period_length-1 do begin
      syear = CONSTRUCTION_PERIOD_START*1L+ii-1
      leap = leap + is_leap_proleptic_gregorian(syear)
      start_new_month(ii) = (ii*monthlength)+leap
   endfor
endif


; loop over all land points
for i = 0L,(NUMLANDPOINTS-1) do begin
   n=i

;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;***************************************************************
;***************************************************************
;***************************************************************
; define data set to be used for the fit
; including dry months threshold, dry days threshold and
; redistribution of rain from dry days in wet months
;***************************************************************
;***************************************************************
;***************************************************************
;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

;*************************************************
; define the meanratio to correct the monthly mean
;*************************************************
   y=pr_o(n,*)                  ; OBS data
   x=pr_e(n,*)                  ; GCM data

   fullmean_x(n) = mean(x)      ; mean of all GCM data in the construction period
   fullmean_y(n) = mean(y)      ; mean of all OBS data in the construction period

   meanratio(n) = fullmean_y(n)/fullmean_x(n)
   if (fullmean_x(n) eq 0 and fullmean_y(n) eq 0) then meanratio(n) = 1

   means_x = start_new_month*0.0
   means_y = means_x

   for mm=0,construction_period_length-1 do begin
      startidx = start_new_month[mm]
      if (mm le (construction_period_length-2)) then endidx = start_new_month[mm+1]-1
      if (mm eq (construction_period_length-1)) then endidx = n_elements(x)-1
      means_x[mm] = mean(x[startidx:endidx])
      means_y[mm] = mean(y[startidx:endidx])

   endfor

;*************************************************
; define dry months such that number is the same in OBS and GCM
; fix threshold for OBS 0.01mm/day (threshold for deserts areas,
; roughly 3.6 mm/year of rain. Regions with that little rain are not fitted.
;*************************************************

; dry months: either the monthly mean in observational data is less or equal 0.01
; (threshold for deserts) OR the monthly mean in the GCM data is not positive

; number of dry months

   tmp1 = (where(means_y(sort(means_y)) le cutoff_mean or means_x(sort(means_x)) le 0))
   numdrymonths = n_elements(where(means_y(sort(means_y)) le cutoff_mean or means_x(sort(means_x)) le 0))
   if (numdrymonths eq 1) then begin
      if (tmp1 eq -1) then numdrymonths = -1
   endif

; define the monthly mean value in the GCM that marks the cut-off between dry and wet months

   asorted = means_x(sort(means_x))
   if (numdrymonths eq -1) then s_m(n) = 0.0
   if (numdrymonths gt 0 and numdrymonths lt construction_period_length) then s_m(n) = asorted(numdrymonths-1)
   if (numdrymonths eq construction_period_length) then s_m(n) = asorted(numdrymonths-1)

; sort monthly means by absolute value

   sort_meanx = sort(means_x)
   sort_meany = sort(means_y)

; choose dry months
   mmx = -1
   mmy = -1
   if (numdrymonths ge 1) then begin
      mmx = sort_meanx(0:numdrymonths-1)
      mmy = sort_meany(0:numdrymonths-1)
   endif


; set all days within dry months to zero
; and count the number to account for leap year, no leap year combinations
   ndays_x = 0
   ndays_y = 0
   if (numdrymonths ge 1) then begin
      for mm=0,(n_elements(mmy)-1) do begin
; GCM
         startidx = start_new_month[mmx[mm]]
         if (mmx[mm] le (construction_period_length-2)) then endidx = start_new_month[mmx[mm]+1]-1
         if (mmx[mm] eq (construction_period_length-1)) then endidx = l-1
         x[startidx:endidx] = 0.0
         ndays_x = ndays_x+n_elements(x[startidx:endidx])
; OBS
         startidx = start_new_month[mmy[mm]]
         if (mmy[mm] le (construction_period_length-2)) then endidx = start_new_month[mmy[mm]+1]-1
         if (mmy[mm] eq (construction_period_length-1)) then endidx = l-1
         y[startidx:endidx] = 0.0
         ndays_y = ndays_y+n_elements(y[startidx:endidx])
      endfor
   endif


; sort remaining values (vector length is top)

   xs = x(sort(x))
   ys = y(sort(y))

; number of additional dry and drizzle days in OBS (in wet months)
   i0=min([top-1,max([0,where(ys lt precip_cutoff)])])

;print,'top ',top, ' i0 ',i0

;***************************************************************
; threshold for dry days of model data in wet months
;***************************************************************

   s_e(n) = 0.0
   if (i0 lt 0) then s_e(n) = 0.0
   if (i0 ge 0 and i0 lt (top-1)) then s_e(n) = (xs(i0)+xs(i0+1))/2.0
   if (i0 eq (top-1)) then s_e(n) = xs(i0)

   if (n_elements(xs) eq 1) then begin
      if (where(finite(xs)) eq -1) then s_e(n)=0.0
   endif

;***************************************************************
; threshold for dry days in OBS data in wet months
;***************************************************************

   s_o(n) = 0.0
   if (i0 lt 0) then s_o(n) = 0.0
   if (i0 ge 0 and i0 lt (top-1)) then s_o(n) = (ys(i0)+ys(i0+1))/2.0
   if (i0 eq (top-1)) then s_o(n) = ys(i0)

   if (n_elements(ys) eq 1) then begin
      if (where(finite(ys)) eq -1) then s_o(n)=0.0
   endif

; choose wet months
   mmx_w = -1
   mmy_w = -1
   if(numdrymonths ne construction_period_length) then begin
      if(numdrymonths eq -1) then begin ; no dry months
         mmx_w = sort_meanx
         mmy_w = sort_meany
      endif
      if(numdrymonths ge 1) then begin
         mmx_w = sort_meanx(numdrymonths:construction_period_length-1)
         mmy_w = sort_meany(numdrymonths:construction_period_length-1)
      endif
   endif

; set dry days within wet months to zero and distribute the amount of rain
; numdrymonths = -1 means no dry months

   if(numdrymonths eq construction_period_length) then print,'warning: no wet months'
   if(numdrymonths ne construction_period_length) then begin

      add_dry_month = 0
      for mm=0,(n_elements(mmy_w)-1) do begin
; GCM
         startidx1 = start_new_month[mmx_w[mm]]
         if (mmx_w[mm] le (construction_period_length-2)) then endidx1 = start_new_month[mmx_w[mm]+1]-1
         if (mmx_w[mm] eq (construction_period_length-1)) then endidx1 = l-1

; select days of this month
         x_month = x[startidx1:endidx1]

;       print,max(xnn_month)

; find dry days
; count number of additional dry months
         wx_dry = where(x_month le s_e(n))
         lx = 0
         if(n_elements(wx_dry) eq 1) then begin
            if(wx_dry ne -1) then begin ; only one dry day
               lx = n_elements(x_month)-n_elements(wx_dry)
               sx = total(x_month[wx_dry])/lx
               x_month[wx_dry] = 0.0
               x_month[where(x_month gt s_e(n))] = x_month[where(x_month gt s_e(n))]+sx
            endif
            if(wx_dry eq -1) then begin
               lx = n_elements(x_month)
            endif
         endif
         if(n_elements(wx_dry) gt 1) then begin
            lx = n_elements(x_month)-n_elements(wx_dry)
            if(lx gt 0) then begin ; more then one dry day, but not all days dry
               sx = total(x_month[wx_dry])/lx
               x_month[wx_dry] = 0.0
               x_month[where(x_month gt s_e(n))] = x_month[where(x_month gt s_e(n))]+sx
            endif
         endif
; OBS
         startidx2 = start_new_month[mmy_w[mm]]
         if (mmy_w[mm] le (construction_period_length-2)) then endidx2 = start_new_month[mmy_w[mm]+1]-1
         if (mmy_w[mm] eq (construction_period_length-1)) then endidx2 = l-1

; select days of this month
         y_month = y[startidx2:endidx2]

;       print,max(ynn_month)

; find dry days
; count number of additional dry months
         wy_dry = where(y_month le s_o(n))
         ly = 0
         if(n_elements(wy_dry) eq 1) then begin
            if(wy_dry ne -1) then begin ; only one dry day
               ly = n_elements(y_month)-n_elements(wy_dry)
               sy = total(y_month[wy_dry])/ly
               y_month[wy_dry] = 0.0
               y_month[where(y_month gt s_o(n))] = y_month[where(y_month gt s_o(n))]+sy
            endif
            if(wy_dry eq -1) then begin
               ly = n_elements(y_month)
            endif
         endif
         if(n_elements(wy_dry) gt 1) then begin
            ly = n_elements(y_month)-n_elements(wy_dry)
            if(ly gt 0) then begin ; more then one dry day, but not all days dry
               sy = total(y_month[wy_dry])/ly
               y_month[wy_dry] = 0.0
               y_month[where(y_month gt s_o(n))] = y_month[where(y_month gt s_o(n))]+sy
            endif
         endif

         if(lx le 0) then begin ; all days of the month dry
            x_month = 0.0*x_month
         endif
         if(ly le 0) then begin ; all days of the month dry
            y_month = 0.0*y_month
         endif

         x[startidx1:endidx1] = x_month

         y[startidx2:endidx2] = y_month
      endfor
   endif

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;############################################;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; normalize with monthly mean (excluding 0)  ;
;############################################;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

   xnn = x
   ynn = y

   mmx = sort(means_x)
   mmy = sort(means_y)

   for mm=0,construction_period_length-1 do begin
      startidx1 = start_new_month[mmx[mm]]
      if (mmx[mm] le (construction_period_length-2)) then endidx1 = start_new_month[mmx[mm]+1]-1
      if (mmx[mm] eq (construction_period_length-1)) then endidx1 = n_elements(x)-1

      startidx2 = start_new_month[mmy[mm]]
      if (mmy[mm] le (construction_period_length-2)) then endidx2 = start_new_month[mmy[mm]+1]-1
      if (mmy[mm] eq (construction_period_length-1)) then endidx2 = n_elements(y)-1


      days_x=x[startidx1:endidx1]
; number of wet days in that month in the GCM
      w_wetdays_x = where(days_x gt 0.0)
      days_y=y[startidx2:endidx2]
; number of wet days in that month in the OBS
      w_wetdays_y = where(days_y gt 0.0)

; calculate mean over the wet days
      if(n_elements(w_wetdays_x) eq 1) then begin
         if(w_wetdays_x eq -1) then means_x[mmx[mm]] = 0.0
         if(w_wetdays_x gt -1) then means_x[mmx[mm]] = mean(days_x(w_wetdays_x))
      endif
      if(n_elements(w_wetdays_x) gt 1) then means_x[mmx[mm]] = mean(days_x(w_wetdays_x))

      if(n_elements(w_wetdays_y) eq 1) then begin
         if(w_wetdays_y eq -1) then means_y[mmy[mm]] = 0.0
         if(w_wetdays_y gt -1) then means_y[mmy[mm]] = mean(days_y(w_wetdays_y))
      endif
      if(n_elements(w_wetdays_y) gt 1) then means_y[mmy[mm]] = mean(days_y(w_wetdays_y))

; normalise all daily values by the
; corresponding monthly means (zeros
; excluded)
      if(means_x[mmx[mm]] gt 0.0) then xnn[startidx1:endidx1] = x[startidx1:endidx1]/means_x[mmx[mm]]
      if(means_y[mmy[mm]] gt 0.0) then ynn[startidx2:endidx2] = y[startidx2:endidx2]/means_y[mmy[mm]]

   endfor




   ysort=y(sort(y))             ; OBS
   xsort=x(sort(x))             ; GCM

   i0 = min([top-1,max([where((ysort LE s_o(n)) AND (xsort LE s_e(n)))])])
   meany=mean(y(where(y gt 0)))

   ysort_n=ynn(sort(y))         ; OBS
   xsort_n=xnn(sort(x))         ; GCM

   meanx_norm = mean(xnn)
   meany_norm = mean(ynn)

   x_norm = xsort_n
   y_norm = ysort_n


   wy = where(ysort GT s_o(n))  ; exclude dry days of wet months in OBS


   if (n_elements(wy) eq 1) then begin
      if (wy eq -1) then begin
         x_norm = -1            ; exclude dry
;days of wet months in GCM
         y_norm = -1            ; exclude dry
;days of wet months in OBS
         i0 = top
      endif
      if (wy gt -1) then begin
         x_norm = xsort_n(wy)   ; exclude dry
;days of wet months in GCM
         y_norm = ysort_n(wy)   ; exclude dry
;days of wet months in OBS
         i0 = top-1-n_elements(wy)
      endif
   endif

   if (n_elements(wy) gt 1) then begin
      x_norm = xsort_n(wy)      ; exclude dry
;days of wet months in GCM
      y_norm = ysort_n(wy)      ; exclude dry
;days of wet months in OBS
      i0 = top-1-n_elements(wy)
   endif


    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; reorder remaining nomalized days for the fit
; dry days and outlier excluded
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
   x_norm = x_norm(sort(x_norm))
   y_norm = y_norm(sort(y_norm))

   i0_val[i] = i0
   top_val[i] = top


;print,i,' mean x ',mean(x_norm),' mean y ',mean(y_norm)


;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;***************************************************************
;***************************************************************
;***************************************************************
; construct transfer function from remaining normalized data
; use fit type that results in smaller root mean square error
;***************************************************************
;***************************************************************
;***************************************************************
;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


; initialize fitting parameter
   a=[0,1,1e33]
   er=1e33
;
;******************************************************
;********* fitting procedure ************************
;
; several fitting algorithms may be useful, depending on number of
; available data points in model and observations and the degree to
; which they converge.

   if (i0 lt top-cutoff_raindays and meany gt cutoff_mean) then begin
;selecting the finite precip values (greater than precip_cutoff but
;not outliers)
      x0 = x_norm
      y0 = y_norm


      a=[0,1,0.9]               ; for transfer function
      w=replicate(1.0,n_elements(x0))
; fitting an exponential distribution: y=(A+B.x)*(1-exp(-x/tau))
; the exponential forces the fit to go to zero in the limit x->0
      g=curvefit(x0-x0(0),y0,w,a,function_name='transferfunction',$
                 status=stat,yerror=er,itmax=1000,/noderivative,$
                 iter=iter,tol=1e-16,fita=[1,1,1])

; check if the gradient method used to fit the exponential converges
      if(stat eq 0) then er=sqrt(mean((y0-((a(0) + a(1)*(x0-x0(0)))*(1-exp(-(x0-x0(0))/a(2)))))^2))
; if not then try different inial
; values (offset and slope from linear
; fit)
      if(stat ne 0) then begin
         print,'warning:'
         if(stat eq 1) then print,'The computation failed. Chi-square was increasing without bounds.'
         if(stat eq 2) then print,'The computation failed to converge in ITMAX iterations.'
         print,'Trying different intialization'

         stat = 100
         a=[0,1,1e33]
         er=1e33
; perform a linear fit
         x0m=mean(x0)
         y0m=mean(y0)
         yx0m=mean(x0*y0)
         xx0m=mean(x0*x0)
         divisor=x0m^2-xx0m
         IF(divisor NE 0.0) THEN BEGIN
; this should only not be the case of
; all values are equal. In that case a
; multiplicative correction of the
; mean is best.
            a(1)=(y0m*x0m-yx0m)/divisor
            a(0)=y0m-a(1)*x0m
         ENDIF ELSE BEGIN
            a(0) = 0
            a(1) = meany_norm/meanx_norm
         ENDELSE
         alin=a
         a=[alin(0),alin(1),0.9]  ; for transfer function
         w=replicate(1.0,n_elements(x0))
; fitting an exponential distribution:
; y=(A+B.x)*(1-exp(-x/Tau))
; the exponential forces the fit to go
; to zero in the limit x->0
         g=curvefit(x0-x0(0),y0,w,a,function_name='transferfunction',$
                    status=stat,yerror=er,itmax=1000,/noderivative,$
                    iter=iter,tol=1e-16,fita=[1,1,1])

; check if the gradient method used to fit the exponential converges
         if  (stat eq 0) then er=sqrt(mean((y0-((a(0) + a(1)*(x0-x0(0)))*(1-exp(-(x0-x0(0))/a(2)))))^2))
; if second initialization failed for
; nonlinear curvefit failed then use
; linear fit
         if(stat ne 0) then begin
            print,'warning:'
            if (stat eq 1) then print,'The computation failed. Chi-square was increasing without bounds.'
            if (stat eq 2) then print,'The computation failed to converge in ITMAX iterations.'
            print,'Linear fit will be used.'
            a = alin
            er=sqrt(mean((y0-a(0)-a(1)*x0)^2))
         endif

      endif

      if(er gt 0.05) then begin
         alin=a
         x0m=mean(x0)
         y0m=mean(y0)
         yx0m=mean(x0*y0)
         xx0m=mean(x0*x0)
         divisor=x0m^2-xx0m
         IF(divisor NE 0.0) THEN BEGIN
; this should only not be the case of
; all values are equal. In that case a
; multiplicative correction of the
; mean is best.
            alin(1)=(y0m*x0m-yx0m)/divisor
            alin(0)=y0m-alin(1)*x0m
         ENDIF ELSE BEGIN
            alin(0) = 0
            alin(1) = meany_norm/meanx_norm
         ENDELSE
         er_lin=sqrt(mean((y0-alin(0)-alin(1)*x0)^2))
         if(er_lin le er) then begin
            a(0)=alin(0)
            a(1)=alin(1)
            a(2)=1e33
            er=er_lin
         endif
      endif

      tau_pr(n)=a(2)
      error_pr(n)=er

      extremes(n,0)=Y0(0)
      extremes(n,1)=Y0(n_elements(Y0)-1)

   endif
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
;**********************************************************
;**********************************************************
; dry month
;**********************************************************
;**********************************************************
   if (i0 ge top-cutoff_raindays or meany le cutoff_mean) then $
      a = [0,1,1e33]
   X0_pr(n) = x_norm(0)         ; largest normized value classified as dry day
   a_pr(n)  =a(0)
   b_pr(n)  =a(1)
   tau_pr(n)=a(2)
endfor


cmsave,filename=opath,$
       a_pr,b_pr,error_pr,tau_pr,x0_pr,meanratio,s_e,s_m,extremes
end
