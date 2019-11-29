#!/bin/bash -e

#Wendy Sharples 10.10.2018

#Annoyingly in order to run ISIMPIP, need to:
#1. merge obs (AWAP) data for reference period which is, for the sake of argument: 1975-2014
#2. change the variable name eg from wind to sfcWind
#eg /AWAP/sfcWind_day_AWAP_19790101-20131231.nc4
#3. need to mark the cells to be bias corrected in a separate file (ALL cells will be marked to be bias corrected)
#eg /AWAP/AWAP.BCmask.nc4 - did this separately
#4. need a grid for running the interpolation script
#5. need to change units for temperature, precip and solar exposure

myArgs=( "$@" )
export obs_dir=${myArgs[0]}
export obs_file=${myArgs[1]}
export output_file=${myArgs[2]}
export year_start=${myArgs[3]}
export year_end=${myArgs[4]}
export oldvar=${myArgs[5]}
export newvar=${myArgs[6]}
export chtime=${myArgs[7]} #null, 12 or 0
export exp="${myArgs[8]}" #if we need to convert between units
echo expression is $exp
#build up the string to mergetime:
str=''
for (( ii=year_start;ii<=year_end;ii++ )); do
    str="$str ${obs_dir}/${obs_file}_${ii}.nc"
done
#merge time
cdo -f nc4c -z zip_9 -mergetime $str ${output_file}.nc4
wait
#need to change var_name:
#LOCAL:
ncrename -O -v $oldvar,$newvar ${output_file}.nc4
wait

#GLOBAL:
ncatted -O -a var_name,global,m,c,$newvar ${output_file}.nc4
wait

#if chtime not null:
if [[ chtime =~ "12" ]]; then
    mv ${output_file}.nc4 ${output_file}.nc4_tmp
    cdo -f nc4c -z zip_9 -settaxis,${year_start}-01-01,12:00:00,day ${output_file}.nc4_tmp ${output_file}.nc4
    wait
    rm *_tmp
elif [[ chtime =~ "0" ]]; then
    mv ${output_file}.nc4 ${output_file}.nc4_tmp
    cdo -f nc4c -z zip_9 -settaxis,${year_start}-01-01,00:00:00,day ${output_file}.nc4_tmp ${output_file}.nc4
    wait
    rm *_tmp
fi

#if scale non null:
if ! [[ $exp == '' ]]; then
    mv ${output_file}.nc4 ${output_file}.nc4_tmp
    cmd="cdo -f nc4c -z zip_9 ${exp} ${output_file}.nc4_tmp ${output_file}.nc4"
    eval "${cmd}"
rm *_tmp
fi

# Changes META data for new sfcWind data
# if [[ $newvar == 'sfcWind' ]]; then
#     ncatted -a _FillValue,sfcWind,o,f,1.e+20 ${output_file}
#     wait
#     ncatted -a missing_value,sfcWind,o,f,1.e+20 ${output_file}
#     wait
# fi