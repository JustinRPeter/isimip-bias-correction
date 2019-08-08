#!/bin/bash

#PBS -l walltime=24:00:00
#PBS -N bc1p5get
#PBS -P er4
##PBS -M wendy.sharples@bom.gov.au
#PBS -l ncpus=16
#PBS -l mem=128gb

#PBS -o qlogs/get.coef.out
#PBS -e qlogs/get.coef.err


#Dependent on settings file
fullpath=/g/data/er4/jr6311/isimip-bias-correction/isimip-bias-correction/ISIMIP2b_bc-master_PBS
source ${fullpath}/exports.settings.functions.sh


# check input parameters
case $# in
5)
  lobs=1;;
6)
  lobs=0;;
7)
  lobs=-1;;
*)
  echo five, six or seven input parameters expected !!! exiting ... $(date)
  exit;;
esac  # #

export obsdataset=$1
case $obsdataset in
EWEMBI|MSWEP|WFD|AWAP)
  echo observational_dataset $obsdataset
  export lmonsb=1;;
Forests*|Nottingham*)
  echo observational_dataset $obsdataset
  export lmonsb=0;;
*)
  echo observational_dataset $obsdataset not supported !!! exiting ... $(date)
  exit;;
esac  # obsdataset
idirobs=$idirOBSdata
tdirobsi=$tdir/$obsdataset/idat
tdirobsc=$tdir/$obsdataset/coef
export ipathBCmask=$idirOBSdata/$obsdataset.BCmask.$ncs
exit_if_any_does_not_exist $ipathBCmask

export referenceperiod=$2
if [[ $referenceperiod =~ [0-9]{4}-[0-9]{4} ]]
then
  echo reference period $referenceperiod
  export ysreference=$(cut -d '-' -f 1 <<<$referenceperiod)
  export yereference=$(cut -d '-' -f 2 <<<$referenceperiod)
else
  echo reference period $referenceperiod has invalid format !!! exiting ... $(date)
  exit
fi  # referenceperiod
export expreference=$(get_reference_experiment $referenceperiod)

export var=$3
case $var in
hurs|psl|rlds|rsds|sfcWind|tas|tasmax|tasmin)
  echo variable $var;;
pr)
  export idlfactor=86400.
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
GFDL-ESM2M|HadGEM2-ES|IPSL-CM5A-LR|MIROC5|CNRM-CM5|ACCESS1-0)
  echo GCM $gcm;;
*)
  echo GCM $gcm not supported !!! exiting ... $(date)
  exit;;
esac  # gcm
idirgcm=$idirGCMdata/$gcm
tdirgcmi=$tdir/$obsdataset/idat
tdirgcmc=$tdir/$obsdataset/coef
echo

echo idirgcm is $idirgcm

# prepare submission of pbs jobs for different months
if [ "$PBS_JOBID" == "" ]
then
  export PBS_JOBID=$RANDOM
  while [ -d $wdir/qlogs/get.coef.$PBS_JOBID.qsubed ]
  do
    export PBS_JOBID=$RANDOM
  done
fi
if [ $lmonsb -eq 1 ] && [[ $bcmethod != hurs ]] && [[ $bcmethod != rsds ]]
then
  export qsubedlogs=$wdir/qlogs/get.coef.$PBS_JOBID.qsubed
  export qsubedlist=$qsubedlogs.current
  mkdir -p $qsubedlogs
fi

# set input paths and check input file existence
if [ $lobs -eq 1 ]
then
  dataset=$gcm
  idir=$idirgcm
  ifile=${var}_${frequency}_${gcm}_${expreference}_${realization}_${ysreference}0101-${yereference}1231
  echo ifile is $ifile
  if [ ! -f $idir/$ifile.$ncs ]
  then
    idir=$tdirgcmi
    merge_reference_decades_if_necessary $var $gcm $ysreference-$yereference $idir/$ifile.$ncs $ipathBCmask
  fi
else
  dataset=$gcm
  idir=$tdirgcmi
  ifile=${var}_${frequency}_${gcm}_${expreference}_${realization}_${ysreference}0101-${yereference}1231
fi  # lobs
echo "\n CHECK FILE EXISTENCE\n"
exit_if_any_does_not_exist $idir/$ifile.$ncs
echo "\n Done \n"


case $bcmethod in
hurs|rsds)
  [ $lobs -eq 1 ] && odir=$tdirobsc || odir=$tdirgcmc
  ofile=$ifile
  ;;
*)
  
  # convert NetCDF to IDL binary files
  if [ $lobs -eq 1 ]
  then
    sfile=convert.nc2idl.monthly
    odir=$tdirgcmi
    echo odir is $odir
    echo converting reference-period NetCDF file to monthly IDL binary files ...
    $sdir/bash/$sfile.sh $idir $odir $ifile ${ifile}_ 2
  fi

  # calculate transfer function coefficients
  if [ $lobs -eq 0 ]
  then
    #CHECK ALL CONVERTED FILES EXIST: WKS CHANGED
    for month in $(seq -w 1 12); do exit_if_nt $idir/$ifile.$ncs $idir/${ifile}_$month.dat; done
    echo ... converting has been done
    echo
    echo computing transfer function coefficients ...
    sfile=get.coef.monthly
    ifixobs=_${frequency}_${obsdataset}_${ysreference}0101-${yereference}1231_
    ifixgcm=_${frequency}_${gcm}_${expreference}_${realization}_${ysreference}0101-${yereference}1231_
    ofixgcm=_${frequency}_${gcm}_${expreference}_${realization}_${obsdataset}_${ysreference}0101-${yereference}1231_
    ipathobs=$tdirobsi/$var$ifixobs
    ipathgcm=$tdirgcmi/$var$ifixgcm
    ipathobstas=$tdirobsi/tas$ifixobs  # for tasmin and tasmax
    ipathgcmtas=$tdirgcmi/tas$ifixgcm  # for tasmin and tasmax
    opath=$tdirgcmc/$var$ofixgcm

    # check input file existence
    for month in $(seq -w 1 12)
    do
      exit_if_any_does_not_exist $ipathobs$month.dat
      exit_if_any_does_not_exist $ipathgcm$month.dat
    done  # month

    # calculate coefficients
    $sdir/bash/$sfile.sh $ipathobs $ipathobstas $ipathgcm $ipathgcmtas $opath
    echo ... submitting done
  fi  # lobs
  if [ $lmonsb -eq -1 ]
  then
    # check output file existence
    for month in $(seq -w 1 12)
    do
      exit_if_nt $ipathobs$month.dat $opath$month.dat
      exit_if_nt $ipathgcm$month.dat $opath$month.dat
    done  # month
    echo ... computing done
  fi
  ;;
esac  # bcmethod
