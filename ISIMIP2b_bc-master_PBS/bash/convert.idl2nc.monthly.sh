#!/bin/bash

# process input parameters
ipath=$1  # without month.suffix
opath=$2  # without suffix
time=$3 # WKS midday or midnight- should not be hardcoded

# set number of cpus per task (this only takes effect if lmonsb == 1)
[[ $exp = $expreference ]] && ncpus=2 || ncpus=1

# convert each monthly IDL binary file to a NetCDF file
cdopipe=
for month in $(seq -w 1 12)
do
  sfile=convert.idl2nc.monthly.$month
  spath=$tdir/subscripts/$sfile.$PBS_JOBID
  cat > $spath << EOF
#!/bin/bash

#PBS -l walltime=8:00:00
#PBS -l ncpus=16
#PBS -l mem=64gb
#PBS -lsoftware=idl
#PBS -N bc1p5i$month
#PBS -P er4
##PBS -M wendy.sharples@bom.gov.au

#PBS -o $qsubedlogs/$sfile.out
#PBS -e $qsubedlogs/$sfile.err

module purge
module load netcdf
module load cdo
module load nco
module load gdl
# module load idl
module load pbs
module load idl/8.4

export IDL_STARTUP=/g/data1a/er4/jr6311/isimip-bias-correction/isimip-bias-correction/.idl/idl-startup.pro

echo ... converting data for month $month ...

idl <<GDLEOF
ipathBCmask = '$ipathBCmask'
.r $sdir/gdl/readBCmask.pro
.r $sdir/gdl/isleap.pro
.r $sdir/gdl/idl2nc.pro
idl2nc,'$ipath$month.dat','$ipath$month.$ncs','$var',$ysp,$yep,$((10#$month - 1)),nlat,nlon,lat0,lon0,dlat,dlon,NUMLANDPOINTS,landlat,landlon,$missval
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
  if [[ "$time" =~ "midday" ]]; then
     cdopipe="$cdopipe $cdo -setreftime,${ysp}-01-01,12:00:00,day $ipath$month.$ncs ${ipath}${month}_ref.${ncs}; wait;"
  else
     cdopipe="$cdopipe $cdo -setreftime,${ysp}-01-01,00:00:00,day $ipath$month.$ncs ${ipath}${month}_ref.${ncs}; wait;"
  fi
  allfiles="$allfiles ${ipath}${month}_ref.${ncs}"
done  # month



# wait for monthly batch jobs to finish
if [ $lmonsb -eq 1 ]
then
  wait_for_batch_jobs_to_finish $qsubedlist
  rm $qsubedlist $tdir/subscripts/*.$PBS_JOBID
fi

# check monthly NetCDF file existence
for month in $(seq -w 1 12); do exit_if_nt $ipath$month.dat $ipath$month.$ncs; done

# merge monthly NetCDF files
echo ... merging monthly NetCDF files into $opath.$ncs ...
echo $cdopipe
#echo $allfiles
eval $cdopipe
wait
$cdo -O -r -mergetime $allfiles ${opath}_tmp.${ncs}
wait
if [[ "$time" =~ "midday" ]]; then
  $cdo -O -r -settaxis,${ysp}-01-01,12:00:00,day ${opath}_tmp.${ncs} ${opath}.${ncs}
else
  $cdo -O -r -settaxis,${ysp}-01-01,00:00:00,day ${opath}_tmp.${ncs} ${opath}.${ncs}
fi
wait
echo ... done ...
#rm $ipath??.$ncs
