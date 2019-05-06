#!/bin/bash



# process input parameters
ipathobs=$1  # without month.suffix
ipathobstas=$2  # without month.suffix (only for tasmax and tasmin)
ipathgcm=$3  # without month.suffix
ipathgcmtas=$4  # without month.suffix (only for tasmax and tasmin)
opath=$5  # without month.suffix


# check input file existence (only for tasmax and tasmin)
case $bcmethod in
tasmax|tasmin)
  for month in $(seq -w 1 12)
  do
    exit_if_any_does_not_exist $ipathobstas$month.dat
    exit_if_any_does_not_exist $ipathgcmtas$month.dat
  done  # month
  [[ $bcmethod = tasmax ]] && minormax=1. || minormax=-1.
  ;;
esac  # bcmethod


# calculate transfer function coefficients for each month
for month in $(seq -w 1 12)
do
  sfile=get.coef.monthly.$month
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
    gdlprocedure=get_coef_hurs
    gdlarguments="'$ipathobs$month.dat','$ipathgcm$month.dat','$opath$month.dat'"
    ncpus=2;;
  pr)
    gdlprocedure=get_coef_pr
    gdlarguments="'$ipathobs$month.dat','$ipathgcm$month.dat','$opath$month.dat',$ysreference,$yereference,$((10#$month - 1)),NUMLANDPOINTS,land,$wetmonthreshold,$wetdaythreshold,$nwetdaysmin,$idlfactor"
    ncpus=2;;
  rlds|sfcWind)
    gdlprocedure=get_coef_rlds_sfcWind
    gdlarguments="'$ipathobs$prevmonth.dat','$ipathobs$month.dat','$ipathobs$nextmonth.dat','$ipathgcm$prevmonth.dat','$ipathgcm$month.dat','$ipathgcm$nextmonth.dat','$opath$month.dat',$ysreference,$yereference,$((10#$month - 1)),NUMLANDPOINTS,land"
    ncpus=3;;
  psl|tas)
    gdlprocedure=get_coef_psl_tas
    gdlarguments="'$ipathobs$month.dat','$ipathgcm$month.dat','$opath$month.dat',$ysreference,$yereference,$((10#$month - 1)),NUMLANDPOINTS"
    ncpus=2;;
  tasmax|tasmin)
    gdlprocedure=get_coef_tasmax_tasmin
    gdlarguments="'$ipathobs$month.dat','$ipathobstas$month.dat','$ipathgcm$month.dat','$ipathgcmtas$month.dat','$opath$month.dat',$minormax,NUMLANDPOINTS"
    ncpus=3;;
  *)
    echo bias correction method $bcmethod not supported !!! exiting ... $(date)
    exit;;
  esac  # bcmethod
  cat > $spath << EOF
#!/bin/bash

#PBS -l walltime=24:00:00
#PBS -q express
#PBS -l ncpus=16
#PBS -l mem=128gb
#PBS -N bc1p5g$month
#PBS -P er4
##PBS -M wendy.sharples@bom.gov.au

#PBS -o $qsubedlogs/$sfile.out
#PBS -e $qsubedlogs/$sfile.err

module purge
module load netcdf
module load cdo
module load nco
module load gdl
module load idl
module load pbs

export GDL_STARTUP=/g/data/er4/ISIMIP/.idl/idl-startup.pro

echo ... calculating coefficients for month $month ...

gdl <<GDLEOF
ipathBCmask = '$ipathBCmask'
.r $sdir/gdl/readBCmask.pro
.r $sdir/gdl/isleap.pro
.r $sdir/gdl/transferfunction.pro
.r $sdir/gdl/curvefit.pro
.r $sdir/gdl/$gdlprocedure.pro
$gdlprocedure,$gdlarguments
exit

GDLEOF

EOF
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
done  # month
