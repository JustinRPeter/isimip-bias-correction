#!/bin/bash

# process input parameters
ipathdata=$1  # without month.suffix
ipathtasu=$2  # without month.suffix (only for tasmax and tasmin)
ipathtasc=$3  # without month.suffix (only for tasmax and tasmin)
ipathcoef=$4  # without month.suffix
opath=$5  # without month.suffix
month=$6  # in XX format, e.g 01

# check input file existence (only for tasmax and tasmin)
case $bcmethod in
tasmax|tasmin)
  for month in $(seq -w 1 12)
  do
    exit_if_any_does_not_exist $ipathtasu$month.dat
    exit_if_any_does_not_exist $ipathtasc$month.dat
  done  # month
  case $bcmethod in
  tasmax)
    minormax=1.
    minmaxval=$dailymax;;
  *)
    minormax=-1.
    minmaxval=$dailymin;;
  esac  # bcmethod
  ;;
esac  # bcmethod


# set number of cpus per task (this only takes effect if lmonsb == 1)
[[ $exp = $expreference ]] && ncpus=4 || ncpus=1

# apply transfer function coefficients for each month
sfile=app.coef.monthly.$month
spath=$tdir/subscripts/$sfile.$PBS_JOBID
case $month in
01)
  prevmonth=12
  nextmonth=02;;
12)
  prevmonth=11
  nextmonth=01;;
*)
  prevmonth=$(printf '%02d' $((10#$month - 1)))
  nextmonth=$(printf '%02d' $((10#$month + 1)));;
esac  # month
case $bcmethod in
hurs)
  gdlprocedure=app_coef_hurs
  gdlarguments="'$ipathdata$prevmonth.dat','$ipathdata$month.dat','$ipathdata$nextmonth.dat','$ipathcoef$prevmonth.dat','$ipathcoef$month.dat','$ipathcoef$nextmonth.dat','$opath$month.dat',$ysp,$yep,$((10#$month - 1)),NUMLANDPOINTS";;
pr)
  gdlprocedure=app_coef_pr
  gdlarguments="'$ipathdata$month.dat','$ipathcoef$month.dat','$opath$month.dat',$ysp,$yep,$((10#$month - 1)),NUMLANDPOINTS,$correctionfactormaxnonneg,$dailymax,$idlfactor";;
rlds|sfcWind)
  gdlprocedure=app_coef_rlds_sfcWind
  gdlarguments="'$ipathdata$prevmonth.dat','$ipathdata$month.dat','$ipathdata$nextmonth.dat','$ipathcoef$month.dat','$opath$month.dat',$ysp,$yep,$((10#$month - 1)),NUMLANDPOINTS,$correctionfactormaxnonneg,$dailymax"
  echo $gdlarguments
  echo $gldprocedure;;

psl|tas)
  gdlprocedure=app_coef_psl_tas
  gdlarguments="'$ipathdata$month.dat','$ipathcoef$prevmonth.dat','$ipathcoef$month.dat','$ipathcoef$nextmonth.dat','$opath$month.dat',$ysp,$yep,$((10#$month - 1)),$dailymin,$dailymax,NUMLANDPOINTS";;
tasmax|tasmin)
  gdlprocedure=app_coef_tasmax_tasmin
  gdlarguments="'$ipathdata$month.dat','$ipathtasu$month.dat','$ipathtasc$month.dat','$ipathcoef$prevmonth.dat','$ipathcoef$month.dat','$ipathcoef$nextmonth.dat','$opath$month.dat',$ysp,$yep,$((10#$month - 1)),$minormax,$correctionfactormaxtasminmax,$minmaxval,NUMLANDPOINTS";;
*)
  echo bias correction method $bcmethod not supported !!! exiting ... $(date)
  exit;;
esac  # bcmethod
cat > $spath << EOF
#!/bin/bash

#PBS -q express
#PBS -l walltime=8:00:00
#PBS -l ncpus=16
#PBS -l mem=64gb
#PBS -l software=idl
#PBS -N bc1p5n$month
#PBS -P er4
##PBS -M wendy.sharples@bom.gov.au

#PBS -o $qsubedlogs/$sfile.out
#PBS -e $qsubedlogs/$sfile.err

module load cdo
module load nco
module load gdl
# module load idl
module load idl/8.4

export IDL_STARTUP=/g/data1a/er4/jr6311/isimip-bias-correction/isimip-bias-correction/.idl/idl-startup.pro

echo ... applying coefficients for month $month ...

idl <<GDLEOF
ipathBCmask = '$ipathBCmask'
.r $sdir/gdl/readBCmask.pro
wait, 30
.r $sdir/gdl/isleap.pro
wait, 30
.r $sdir/gdl/$gdlprocedure.pro
wait, 30
$gdlprocedure,$gdlarguments
wait, 30
exit

GDLEOF

EOF
echo $lmonsb
if [ $lmonsb -eq 1 ]
then
  qsubstdouterr=error
  while [[ $qsubstdouterr = *error* ]]
  do
    qsubstdouterr=$(qsub $spath 2>&1)
    qsubdate=$(date)
    sleep 2
  done  # qsubstdouterr
  echo $qsubstdouterr $qsubdate
  echo $qsubstdouterr | cut -d ' ' -f 4 >> $qsubedlist
else
  /bin/bash $spath
  rm $spath
fi  # lmonsb
