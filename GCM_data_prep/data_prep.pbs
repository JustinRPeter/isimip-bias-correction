#!/bin/bash

#Wendy Sharples- script to copy across data from GCMS that we need with optional merge together in prep for the interpolation
#Assumes ISIMIP modules are loaded

module load cdo/1.7.2
# USAGE:
# ./data_prep.sh 1976 2005 CNRM-CM5 /g/data/al33/replicas/CMIP5/combined/CNRM-CERFACS/CNRM-CM5 historical pr v20120530 Y
# ./data_prep.sh 1976 2005 MIROC5 /g/data/al33/replicas/CMIP5/combined/MIROC/MIROC5 historical pr v20120710 Y
# ./data_prep.sh 1976 2005 GFDL-ESM2M /g/data/al33/replicas/CMIP5/combined/NOAA-GFDL/GFDL-ESM2M historical pr v20111228 Y
# ./data_prep.sh 1976 2005 ACCESS1-0 /g/data/rr3/publications/CMIP5/output1/CSIRO-BOM/ACCESS1-0 historical pr latest Y

#year start
ys=${1}0101
#year end
ye=${2}1231
#gcm
gcm=$3
#input path
ipath=$4
#rcp
rcp=$5
#variable
var=$6
#version
ver=$7
#merge
merge=$8

ccam_gcm=$9

pwd=$PWD
dateys=$(date -d $ys +"%Y%m%d")
dateye=$(date -d $ye +"%Y%m%d")
echo $dateys $dateye

# data_path=${ipath}/${rcp}/r1i1p1/CSIRO-CCAM-r3355/${ver}/day/${var} # Use this for CCAM data
# filename=${var}_AUS-50_${ccam_gcm}_${rcp}_r1i1p1_CSIRO-CCAM-r3355_v1_day_ # Use this for CCAM data
data_path=${ipath}/${rcp}/day/atmos/day/r1i1p1/${ver}/${var}
filename=${var}_day_${gcm}_${rcp}_r1i1p1_
newfilename=${var}_day_${ccam_gcm}_${rcp}_r1i1p1_

output_path=/g/data/er4/jr6311/isimip-bias-correction/isimip-bias-correction/
echo data path is $data_path

#get all files pertaining to the start and end year
get_file_list=''
get_file_list=$(ls $data_path/*$rcp*)
#echo $get_file_list
arr=($get_file_list)
echo first file: ${arr[0]}

#loop around the array of file names- get the year start and year end and check if within range:
filelist=''
for file in "${arr[@]}"; do
date=$(echo `basename $file` | grep -Eo '[[:digit:]]{4}[[:digit:]]{2}[[:digit:]]{2}')
date_arr=($date)
        fs=${date_arr[0]}
fe=${date_arr[1]}
        echo $file

        #check within range:
        fdateys=$(date -d $fs +"%Y%m%d")
        fdateye=$(date -d $fe +"%Y%m%d")
        # Include if file start date is less than start date
        # arg and file end date is greater than start date arg.
        # File ----|----|------------------------------------
        # Arg  -------|--------------|-----------------------
        if [ $fdateys -le $ys ] && [ $ys -le $fdateye ]; then
echo we are copying file $file
                filen=$pwd/${filename}${fdateys}-${fdateye}.nc
filelist="$filelist $filen"
cp $file $pwd/.
                continue
fi

        # Include if file start date is after start date arg
        # and file end date is before end date arg.
        # File ---------|----|-------------------------------
        # Arg  -------|--------------|-----------------------
        if [ $ys -le $fdateys ] && [ $fdateye -le $ye ]; then
                echo we are copying file $file
                filen=$pwd/${filename}${fdateys}-${fdateye}.nc
                filelist="$filelist $filen"
                cp $file $pwd/.
                continue
        fi

        # Include if file start date is after start date arg
        # and file start date is before end date arg.
        # File -------------------|----|---------------------
        # Arg  -------|--------------|-----------------------
if [ $fdateys -ge $ys ] && [ $fdateys -le $ye ]; then
                echo we are copying file $file
filen=$pwd/${filename}${fdateys}-${fdateye}.nc
filelist="$filelist $filen"
cp $file $pwd/.
        fi
done
echo $filelist

# Generate output folder if not existent
mkdir -p $output_path

if [[ $merge =~ "Y" ]]; then
echo we are merging files and then selecting the date range from $ys to $ye
        cdo -f nc4c -z zip_9 -mergetime $filelist $pwd/tmp_${filename}merged.nc
wait

# Merge files and output to "GCM" folder
cdo -f nc4c -z zip_9 -seldate,$ys,$ye $pwd/tmp_${filename}merged.nc $output_path/${filename}${ys}-${ye}.nc
# cdo -f nc4c -z zip_9 -seldate,$ys,$ye $pwd/tmp_${filename}merged.nc $output_path/${newfilename}${ys}-${ye}.nc #USE THIS FOR CCAM DATA
wait

# Clean up files
rm $pwd/tmp_*
rm $filelist

fi