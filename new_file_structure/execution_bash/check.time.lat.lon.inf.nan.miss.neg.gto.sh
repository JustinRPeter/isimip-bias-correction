#!/bin/bash


#PBS -l walltime=24:00:00
#PBS -l walltime=24:00:00
#PBS -l ncpus=16

#PBS -N bc1p5chk
#PBS -P er4
##PBS -M wendy.sharples@bom.gov.au

#PBS -o slogs/check.time.lat.lon.inf.nan.miss.neg.gto.out
#PBS -e slogs/check.time.lat.lon.inf.nan.miss.neg.gto.err


source exports.settings.functions.sh


obsdataset=$1
echo observational_dataset $obsdataset
referenceperiod=$(get_reference_period $obsdataset)
expreference=$(get_reference_experiment $referenceperiod)
var=$2
case $var in
hurs)
  flags="-o -n"
  echo variable $var;;
huss|pr|prsn|ps|psl|rlds|rsds|sfcWind|tas|tasmax|tasmin)
  flags="-n"
  echo variable $var;;
*)
  echo variable $var not supported !!! exiting ... $(date)
  exit;;
esac  # var
gcm=$3
echo GCM $gcm
exp=$4
echo experiment $exp
[[ $exp = $expreference ]] && expper=$referenceperiod || expper=$(get_experiment_period $exp $gcm)
per=$5
echo period $per
echo


ds=$(cut -d '-' -f 1 <<<$per)0101
de=$(cut -d '-' -f 2 <<<$per)1231
dse=$(cut -d '-' -f 1 <<<$expper)0101
ts=$(get_day_difference $ds $dse)
te=$(get_day_difference $de $dse)


opath=$odirGCMdata/$gcm/$obsdataset/${var}_${frequency}_${gcm}_${exp}_${realization}_${obsdataset}_$ds-$de.$ncs
exit_if_any_does_not_exist $opath
echo -n "$opath "
python $sdir/python/check.time.lat.lon.inf.nan.miss.neg.gto.py $flags -s $ts -e $te -v $var -f $opath
