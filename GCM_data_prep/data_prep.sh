#!/bin/bash

#Wendy Sharples- script to copy across data from GCMS that we need with optional merge together in prep for the interpolation
#Assumes ISIMIP modules are loaded

#USAGE: ./data_prep.sh 2006 2015 CNRM-CM5 /g/data1/ua6/drstree/CMIP5/GCM/CNRM/CNRM-CM5 rcp85 tasmin latest Y


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

pwd=$PWD
dateys=$(date -d $ys +"%Y%m%d")
dateye=$(date -d $ye +"%Y%m%d")
echo $dateys $dateye 

#assuming r1i1p1 but could put this in as another variable
data_path=${ipath}/${rcp}/day/atmos/r1i1p1/${var}/${ver}
filename=${var}_day_${gcm}_${rcp}_r1i1p1_
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
	date=$(echo $file | grep -Eo '[[:digit:]]{4}[[:digit:]]{2}[[:digit:]]{2}')
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

if [[ $merge =~ "Y" ]]; then
	echo we are merging files and then selecting the date range from $ys to $ye
        cdo -f nc4c -z zip_9 -mergetime $filelist $pwd/tmp_${filename}merged.nc
	wait
	cdo -f nc4c -z zip_9 -seldate,$ys,$ye $pwd/tmp_${filename}merged.nc $pwd/${filename}${ys}-${ye}.nc
	wait
	rm $pwd/tmp_*
	rm $filelist
fi

