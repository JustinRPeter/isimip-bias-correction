#!/bin/bash

#PBS -q express
#PBS -l walltime=24:00:00
#PBS -l ncpus=16
#PBS -l mem=32gb

#PBS -N bc1p5app
#PBS -P er4
##PBS -M wendy.sharples@bom.gov.au

#PBS -o qlogs/app.coef.out
#PBS -e qlogs/app.coef.err

module purge
module load cdo
module load nco
module load gdl
module load idl
module load python/2.7.11
module load pbs

export GDL_STARTUP=$HOME/.gdl/gdl-startup.pro

# import settings
#CHANGED WKS
fullpath=/g/data/er4/ISIMIP/ISIMIP2b_bc-master_PBS
source ${fullpath}/exports.settings.functions.sh



# check input parameters
if [ ! $# -eq 7 ]
then
  echo seven input parameters expected !!! exiting ... $(date)
  exit
fi  # #

export obsdataset=$1
case $obsdataset in
EWEMBI|MSWEP|WFD|AWAP)
  echo observational_dataset $obsdataset
  export lmonsb=0;;
Forests*|Nottingham*)
  echo observational_dataset $obsdataset
  export lmonsb=0;;
*)
  echo observational_dataset $obsdataset not supported !!! exiting ... $(date)
  exit;;
esac  # obsdataset

export referenceperiod=$2
if [[ $referenceperiod =~ [0-9]{4}-[0-9]{4} ]]
then
  export ysreference=$(cut -d '-' -f 1 <<<$referenceperiod)
  export yereference=$(cut -d '-' -f 2 <<<$referenceperiod)
else
  echo reference period $referenceperiod has invalid format !!! exiting ... $(date)
  exit
fi  # referenceperiod
export expreference=$(get_reference_experiment $referenceperiod)

export var=$3
case $var in
hurs)
  export var_standard_name="relative_humidity"
  export var_long_name="Near-Surface Relative Humidity"
  export var_units="%"
  echo variable $var;;
huss)
  export var_standard_name="specific_humidity"
  export var_long_name="Near-Surface Specific Humidity"
  export var_units="kg kg-1"
  echo variable $var;;
pr)
  export idlfactor=86400.
  export dailymax=$dailymaxpr
  export var_standard_name="precipitation_flux"
  export var_long_name="Precipitation"
  export var_units="kg m-2 s-1"
  echo variable $var;;
prsn)
  export var_standard_name="snowfall_flux"
  export var_long_name="Snowfall Flux"
  export var_units="kg m-2 s-1"
  echo variable $var;;
ps)
  export var_standard_name="surface_air_pressure"
  export var_long_name="Surface Air Pressure"
  export var_units="Pa"
  echo variable $var;;
psl)
  export dailymax=$dailymaxpsl
  export dailymin=$dailyminpsl
  export var_standard_name="air_pressure_at_sea_level"
  export var_long_name="Sea Level Pressure"
  export var_units="Pa"
  echo variable $var;;
rlds)
  export dailymax=$dailymaxrlds
  export var_standard_name="surface_downwelling_longwave_flux_in_air"
  export var_long_name="Surface Downwelling Longwave Radiation"
  export var_units="W m-2"
  echo variable $var;;
rsds)
  export var_standard_name="surface_downwelling_shortwave_flux_in_air"
  export var_long_name="Surface Downwelling Shortwave Radiation"
  export var_units="W m-2"
  echo variable $var;;
sfcWind)
  export dailymax=$dailymaxsfcWind
  export var_standard_name="wind_speed"
  export var_long_name="Near-Surface Wind Speed"
  export var_units="m s-1"
  echo variable $var;;
tas)
  export dailymax=$dailymaxtas
  export dailymin=$dailymintas
  export var_standard_name="air_temperature"
  export var_long_name="Near-Surface Air Temperature"
  export var_units="K"
  echo variable $var;;
tasmax)
  export dailymax=$dailymaxtas
  export dailymin=$dailymintas
  export var_standard_name="air_temperature"
  export var_long_name="Daily Maximum Near-Surface Air Temperature"
  export var_units="K"
  echo variable $var;;
tasmin)
  export dailymax=$dailymaxtas
  export dailymin=$dailymintas
  export var_standard_name="air_temperature"
  export var_long_name="Daily Minimum Near-Surface Air Temperature"
  export var_units="K"
  echo variable $var;;
*)
  echo variable $var not supported !!! exiting ... $(date)
  exit;;
esac  # var

export bcmethod=$4
if [[ $bcmethod = $var ]]
then
  echo bias_correction_method $bcmethod
elif [[ $bcmethod = tas ]] && ([[ $var = tasmax ]] || [[ $var = tasmin ]])
then
  echo bias_correction_method $bcmethod ... CAUTION ... neither name nor metadata of the output file will indicate that $var was bias-corrected with a method developed for a different variable
else
  echo bias_correction_method $bcmethod not supported for variable $var !!! exiting ... $(date)
  exit
fi

export gcm=$5
case $gcm in
GFDL-ESM2M|HadGEM2-ES|IPSL-CM5A-LR|MIROC5|CNRM-CM5)
  echo GCM $gcm;;
*)
  echo GCM $gcm not supported !!! exiting ... $(date)
  exit;;
esac  # gcm

export exp=$6
export per=$7
if [[ $per =~ [0-9]{4}-[0-9]{4} ]]
then
  export ysp=$(cut -d '-' -f 1 <<<$per)
  export yep=$(cut -d '-' -f 2 <<<$per)
else
  echo period $per has invalid format !!! exiting ... $(date)
  exit
fi  # per
case $exp in
piControl|historical|rcp26|rcp45|rcp60|rcp85)  # make sure that period fits into experiment period
  ep=$(get_experiment_period $exp $gcm)
  export yse=$(cut -d '-' -f 1 <<<$ep)
  export yee=$(cut -d '-' -f 2 <<<$ep)
  if [ $ysp -ge $yse ] && [ $yep -le $yee ]
  then
    echo experiment $exp
    echo period $per
  else
    echo period $per does not fit into $exp period $ep !!! exiting ... $(date)
    exit
  fi;;
$expreference)  # enable correction of reference period data for validation purposes
  if [ $ysp -eq $ysreference ] && [ $yep -eq $yereference ]
  then
    echo experiment $exp
    echo period $per
    export yse=$ysp
    export yee=$yep
  else
    echo period $per does not match $exp period $ysreference-$yereference !!! exiting ... $(date)
    exit
  fi;;
*)
  echo experiment $exp not supported !!! exiting ... $(date)
  exit;;
esac  # exp
echo



# prepare submission of slurm jobs for different months
if [ "$PBS_JOBID" == "" ]
then
  export PBS_JOBID=$RANDOM
  while [ -d $wdir/slogs/app.coef.$PBS_JOBID.qsubed ]
  do
    export PBS_JOBID=$RANDOM
  done
fi
if [ $lmonsb -eq 1 ] && [[ $bcmethod != hurs ]] && [[ $bcmethod != huss ]] && [[ $bcmethod != prsn ]] && [[ $bcmethod != ps ]] && [[ $bcmethod != rsds ]]
then
  export qsubedlogs=$wdir/slogs/app.coef.$PBS_JOBID.qsubed
  export qsubedlist=$qsubedlogs.current
  mkdir -p $qsubedlogs
fi



# set directories
idirobs=$idirOBSdata/$obsdataset
tdirobsi=$tdir/$obsdataset/idat
tdirobsc=$tdir/$obsdataset/coef
idirgcm=$idirGCMdata/$gcm
tdirgcmi=$tdir/$gcm/$obsdataset/idat
tdirgcmc=$tdir/$gcm/$obsdataset/coef
tdirgcmo=$tdir/$gcm/$obsdataset/odat
odirgcm=$odirGCMdata/$gcm/$obsdataset



# set path to spatial mask for bias correction
export ipathBCmask=$idirobs/$obsdataset.BCmask.$ncs
exit_if_any_does_not_exist $ipathBCmask



# make directories for intermediate and final output
mkdir -p $tdir/subscripts $tdirgcmo $odirgcm



# set input and output file name parts
ifilepostvar=_${frequency}_${gcm}_${exp}_${realization}_${ysp}0101-${yep}1231
ofilepostvar=_${frequency}_${gcm}_${exp}_${realization}_${obsdataset}_${ysp}0101-${yep}1231
ifile=$var$ifilepostvar
ofile=$var$ofilepostvar

# correct biases
opath=$odirgcm/$ofile


# set NetCDF attributes
echo setting NetCDF attributes ...
if [[ $gcm = HadGEM2-ES ]] && ([[ $exp = piControl ]] || [[ $exp = historical ]] || [[ $exp = rcp26 ]])
then
  nctitleprefix="CMIP5 output of ${var}_${frequency}_${gcm}_${exp}_${realization} rerun by Kate Halladay on the MOHC Cray XC40"
else
  nctitleprefix="CMIP5 output of ${var}_${frequency}_${gcm}_${exp}_${realization}"
fi
ncatted -h \
-a standard_name,$var,o,c,"$var_standard_name" \
-a long_name,$var,o,c,"$var_long_name" \
-a units,$var,o,c,"$var_units" \
-a long_name,time,o,c,"time" \
-a standard_name,lat,o,c,"latitude" \
-a long_name,lat,o,c,"latitude" \
-a units,lat,o,c,"degrees_north" \
-a standard_name,lon,o,c,"longitude" \
-a long_name,lon,o,c,"longitude" \
-a units,lon,o,c,"degrees_east" \
-a title,global,o,c,"$nctitleprefix, $(get_interpolation_method_label $remapmethod)ly interpolated to a 0.5 degree regular grid and bias-corrected using $obsdataset data from $ysreference to $yereference" \
-a institution,global,o,c,"Potsdam Institute for Climate Impact Research, Research Domain Climate Impacts and Vulnerability, Potsdam, Germany" \
-a project,global,o,c,"Inter-Sectoral Impact Model Intercomparison Project phase 2b (ISIMIP2b)" \
-a contact,global,o,c,"ISIMIP Coordination Team, Potsdam Institute for Climate Impact Research (info@isimip.org)" \
-a references,global,o,c,"Frieler et al. (2017; http://dx.doi.org/10.5194/gmd-10-4321-2017) and Lange (2017; https://doi.org/10.5194/esd-2017-81)" \
-a Conventions,global,o,c,"CF-1.6" \
-a CDI,global,d,, \
-a CDO,global,d,, \
-a history,global,d,, \
$opath.$ncs
echo ... done
