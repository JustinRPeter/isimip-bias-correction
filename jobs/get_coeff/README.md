The numbers represent variables:

None: tasmax
1: tas
2: tasmin
3: rsds
4: pr
5: sfcWind

NEED TO HAVE THE GCM DATA INTERPOLATED AND SET UP:

Eg for pr from 1975-2014 obs and 2006-2015 projections, you need:

/g/data/er4/ISIMIP/jobs/GCMinput/CNRM-CM5/pr_day_CNRM-CM5_historical_r1i1p1_19710101-19801231.nc4
/g/data/er4/ISIMIP/jobs/GCMinput/CNRM-CM5/pr_day_CNRM-CM5_historical_r1i1p1_19810101-19901231.nc4
/g/data/er4/ISIMIP/jobs/GCMinput/CNRM-CM5/pr_day_CNRM-CM5_historical_r1i1p1_19910101-20001231.nc4
/g/data/er4/ISIMIP/jobs/GCMinput/CNRM-CM5/pr_day_CNRM-CM5_historical_r1i1p1_20010101-20051231.nc4
/g/data/er4/ISIMIP/jobs/GCMinput/CNRM-CM5/pr_day_CNRM-CM5_rcp85_r1i1p1_20060101-20101231.nc4
/g/data/er4/ISIMIP/jobs/GCMinput/CNRM-CM5/pr_day_CNRM-CM5_rcp85_r1i1p1_20110101-20201231.nc4

NEED tas_day for tasmin and tasmax!!! SO HAVE TO RUN ALL TAS jobs

### 2. `get.coef.sh`
- This script can be used to compute bias correction coefficients using simulated and observed data from the reference period
- In order to obtain these coefficients for a particular observational dataset-variable-GCM combination, the script first needs to be run with the input parameters
  
  first create the monthly .dat files (idl): get_coeff_00.sh
  ```
  $1 ... observational dataset (e.g., EWEMBI)
  $2 ... reference period (e.g., 1979-2013)
  $3 ... variable (hurs, pr, psl, rlds, rsds, sfcWind, tas, tasmax, tasmin)
  $4 ... bias-correction method (hurs, pr, psl, rlds, rsds, sfcWind, tas, tasmax, tasmin)
  ```


 
  then computing transfer function coefficients from obs: 
  ```
  $1 ... observational dataset (e.g., EWEMBI)
  $2 ... reference period (e.g., 1979-2013)
  $3 ... variable (hurs, pr, psl, rlds, rsds, sfcWind, tas, tasmax, tasmin)
  $4 ... bias-correction method (hurs, pr, psl, rlds, rsds, sfcWind, tas, tasmax, tasmin)
  ```

  and then create coeffs with gcm data:
  ```
  $1 ... observational dataset (e.g., EWEMBI)
  $2 ... reference period (e.g., 1979-2013)
  $3 ... variable (hurs, pr, psl, rlds, rsds, sfcWind, tas, tasmax, tasmin)
  $4 ... bias-correction method (hurs, pr, psl, rlds, rsds, sfcWind, tas, tasmax, tasmin)
  $5 ... GCM (GFDL-ESM2M, HadGEM2-ES, IPSL-CM5A-LR, MIROC5)
  ```
- Please note that
  - bias correction coefficients for tasmax and tasmin can only be computed after those for tas have been computed
  - `python/get_TOA_daily_mean_insolation_climatology.py` has to be run once before rsds bias correction coefficients can be computed; ISIMIP2b usage example: `python get_TOA_daily_mean_insolation_climatology.py -d 0.05` where 0.05 is the desired grid resolution

  - the shell variable `lmonsb` determines if calculations that may be carried out in parallel for different calendar months are actually carried out in parallel (via SLURM batch job submissions; `lmonsb = 1`) or sequentially (within the running instance of the script; `lmonsb = 0`); currently, the value of `lmonsb` is set depending on the observational dataset; this also holds for `app.coef.sh`, see below - at the moment this is set to 0

  - any bias correction of a variable using a method that was not developed for that variable is strongly discouraged; in the current code version this is prohibited with the exception of tasmax and tasmin which may be bias-corrected with the method developed for tas; this also holds for `app.coef.sh`, see below

