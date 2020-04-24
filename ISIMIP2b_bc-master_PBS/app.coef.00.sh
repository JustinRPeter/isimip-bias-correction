#!/bin/bash

#PBS -q express
#PBS -lstorage=gdata/er4
#PBS -l walltime=24:00:00
#PBS -l ncpus=16
#PBS -l mem=128gb

#PBS -N 00-appcoef
#PBS -P er4
##PBS -M sean.loh@bom.gov.au

#PBS -o qlogs/app.coef.00.out
#PBS -e qlogs/app.coef.00.err

# Split of app.coef.sh to apply coefficients to months separately.
# Stage 1 of 3
# Split netCDF file into months then convert monthly nc4s to IDL binaries.

module purge
module load cdo/1.7.2
module load nco
module load gdl
module load idl/8.6
module load pbs

# TODO: Reconfigure for my dir paths on raijin
export GDL_STARTUP=/g/data/er4/ISIMIP/.idl/idl-startup.pro

# import settings
# TODO: Reconfigure for my dir paths on raijin
fullpath=/g/data/er4/ISIMIP/ISIMIP2b_bc-master_PBS
source ${fullpath}/exports.settings.functions.sh

# check input parameters
# TODO: Make sure all 8 parameters are still required.
if [ ! $# -eq 8 ]
then
  echo eight input parameters expected !!! exiting ... $(date)
  exit
fi


##################################
##################################
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
esac


##################################
##################################
idirobs=$idirOBSdata/$obsdataset # ./AWAP
tdirobsi=$tdir/$obsdataset/idat  # ./jobs/tmp/AWAP/idat
tdirobsc=$tdir/$obsdataset/coef  # ./jobs/tmp/AWAP/coef
export ipathBCmask=$idirobs/$obsdataset.BCmask.$ncs # AWAP/AWAP.BCmask.nc4
exit_if_any_does_not_exist $ipathBCmask


##################################
##################################
export referenceperiod=$2
if [[ $referenceperiod =~ [0-9]{4}-[0-9]{4} ]]
then
  export ysreference=$(cut -d '-' -f 1 <<<$referenceperiod)
  export yereference=$(cut -d '-' -f 2 <<<$referenceperiod)
else
  echo reference period $referenceperiod has invalid format !!! exiting ... $(date)
  exit
fi
export expreference=$(get_reference_experiment $referenceperiod)


##################################
##################################
export var=$3
case $var in
pr)
  export idlfactor=86400.
  export dailymax=$dailymaxpr
  export var_standard_name="precipitation_flux"
  export var_long_name="Precipitation"
  export var_units="kg m-2 s-1"
  echo variable $var;;
*)
  echo variable $var not supported !!! exiting ... $(date)
  exit;;
esac


##################################
##################################
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


##################################
##################################
export gcm=$5
case $gcm in
GFDL-ESM2M|HadGEM2-ES|IPSL-CM5A-LR|MIROC5|CNRM-CM5|ACCESS1-0)
  echo GCM $gcm;;
*)
  echo GCM $gcm not supported !!! exiting ... $(date)
  exit;;
esac  # gcm


##################################
##################################
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
esac


##################################
##################################
export time=$8


##################################
##################################
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

# check input file existence
if [[ $var != huss ]] && [[ $var != ps ]]
then
  if [ $ysp -eq $ysreference ] && [ $yep -eq $yereference ] && [ ! -f $idirgcm/$ifile.$ncs ]
  then
    idirgcm=$tdirgcmi
    merge_reference_decades_if_necessary $var $gcm $ysp-$yep $idirgcm/$ifile.$ncs $ipathBCmask
  fi
  exit_if_any_does_not_exist $idirgcm/$ifile.$ncs
fi


##################################
##################################
# correct biases
opath=$odirgcm/$ofile

case $bcmethod in
pr)
  # convert single NetCDF file to monthly IDL binary files
  sfile=convert.nc2idl.monthly
  odir=$tdirgcmi

  echo converting NetCDF file to monthly IDL binary files ...
  [[ $exp = $expreference ]] && ncpus=2 || ncpus=1
  $sdir/bash/$sfile.sh $idirgcm $odir $ifile ${ifile}_ $ncpus
  wait
  if [ $lmonsb -eq 1 ]
  then
    wait_for_batch_jobs_to_finish $qsubedlist
    rm $qsubedlist $tdir/subscripts/*.$PBS_JOBID
  fi
  for month in $(seq -w 1 12); do exit_if_nt $idirgcm/$ifile.$ncs $odir/${ifile}_$month.dat; done
  echo ... converting done
  echo
  ;;
*)
  echo bcmethod $bcmethod not supported !!! exiting ... $(date)
  exit;;
esac
