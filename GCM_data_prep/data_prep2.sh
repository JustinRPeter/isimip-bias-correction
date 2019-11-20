#!/bin/bash
#Wendy Sharples- script to copy across data from GCMS that we need with optional merge together in prep for the interpolation- run this on the cmd line
module load cdo
#divide up into decades (needs to be this format for ISIMIP code- see readme)
yst=( 19710101 19810101 19910101 20010101 )
yen=( 19801231 19901231 20001231 20051231 )
gcm="CCAM-r3355-CNRM-CM5"
for (( ii=0;ii<=3;ii++ )); do
       for var in "tasmax" "tasmin" "tas" "rsds" "pr" "sfcWind"; do
       #cdo -f nc4c -z zip_9 -seldate,${yst[$ii]},${yen[$ii]} ../${gcm}/${var}_${gcm}_historical_r1i1p1_CSIRO-CCAM-r3355_v1_day_19710101-20051231.nc ../${gcm}/${var}_day_${gcm}_historical_r1i1p1_${yst[$ii]}-${yen[$ii]}.nc
       cdo -f nc4c -z zip_9 -seldate,${yst[$ii]},${yen[$ii]} ${var}_day_${gcm}_historical_r1i1p1_19710101-20051231.nc ../${gcm}/${var}_day_${gcm}_historical_r1i1p1_${yst[$ii]}-${yen[$ii]}.nc
       wait
       done
done