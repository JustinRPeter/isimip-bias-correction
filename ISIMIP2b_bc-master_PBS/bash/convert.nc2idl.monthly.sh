#!/bin/bash

#WKS CHANGED:
queue=express

# process input parameters
idir=$1
odir=$2
ifile=$3  # without suffix
ofile=$4  # without suffix
ncpus=$5

# split multi-year ifile into months
echo ... splitting $idir/$ifile.$ncs into months output to $odir ...
mfile=${ifile}_
cdo -f nc splitmon $idir/$ifile.$ncs $odir/$mfile
wait
for month in $(seq -w 1 12); do exit_if_nt $idir/$ifile.$ncs $odir/$mfile$month.$ncs; done
echo ... done ...

# convert each monthly NetCDF file to an IDL binary file
for month in $(seq -w 1 12)
do
  #COMMENT OUT LINE BELOW IF FILES ALREADY CREATED
  sfile=convert.nc2idl.monthly.$month
  spath=$tdir/subscripts/$sfile.$PBS_JOBID
  cat > $spath << EOF
#!/bin/bash

#PBS -q $queue
#PBS -l walltime=8:00:00
#PBS -l ncpus=16
#PBS -l mem=64gb
#PBS -lsoftware=idl
#PBS -N bc1p5n$month
#PBS -P er4
##PBS -M wendy.sharples@bom.gov.au

#PBS -o $qsubedlogs/$sfile.out
#PBS -e $qsubedlogs/$sfile.err

module purge
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
.r $sdir/gdl/nc2idl.pro
nc2idl,'$odir/$mfile$month.$ncs','$odir/$ofile$month.dat','$var',NUMLANDPOINTS,land
exit

GDLEOF
#rm $odir/$mfile$month.$ncs

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
