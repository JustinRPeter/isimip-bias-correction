#!/bin/bash

#PBS -q express
#PBS -l walltime=24:00:00
#PBS -l ncpus=16
#PBS -l mem=128gb
#PBS -l software=idl

#PBS -N bc1p5app
#PBS -P er4
##PBS -M wendy.sharples@bom.gov.au

#PBS -o qlogs/app.coef.out
#PBS -e qlogs/app.coef.err

module purge
module load cdo
module load nco
module load gdl
# module load idl
module load idl/8.6
module load pbs

export GDL_STARTUP=/g/data/er4/jr6311/isimip-bias-correction/isimip-bias-correction/.idl/idl-startup.pro

# import settings
#CHANGED WKS
fullpath=/g/data/er4/jr6311/isimip-bias-correction/isimip-bias-correction/ISIMIP2b_bc-master_PBS
source ${fullpath}/exports.settings.functions.sh



# check input parameters
if [ ! $# -eq 8 ]
then
  echo eight input parameters expected !!! exiting ... $(date)
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
idirobs=$idirOBSdata/$obsdataset
tdirobsi=$tdir/$obsdataset/idat
tdirobsc=$tdir/$obsdataset/coef
export ipathBCmask=$idirOBSdata/$obsdataset.BCmask.$ncs

exit_if_any_does_not_exist $ipathBCmask

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
GFDL-ESM2M|HadGEM2-ES|IPSL-CM5A-LR|MIROC5|CNRM-CM5|ACCESS1-0)
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

export time=$8

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

mkdir -p $tdirgcmi



# set path to spatial mask for bias correction
export ipathBCmask=$idirOBSdata/$obsdataset.BCmask.$ncs
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

# correct biases
opath=$odirgcm/$ofile

case $bcmethod in
hurs|rsds)
  odir=$tdirgcmc

  # get multi-year daily means, variances (and maxima) of uncorrected data
  nleapdaysinper=0; for year in $(seq $ysp $yep); do nleapdaysinper=$(( $nleapdaysinper + $(is_leap_proleptic_gregorian $year) )); done
  case $bcmethod in
  hurs)
    echo "clamping $var input values in [0,100] ..."
    # need to put -L to avoid seg faults- JUST FOUND THIS OUT THANKS NCI
    $cdo -L -setmissval,$missval -setmisstoc,0 -ifthen -gtc,0 $idirgcm/$ifile.$ncs $idirgcm/$ifile.$ncs $odir/$ifile.unlimited.$ncs
    exit_if_nt $idirgcm/$ifile.$ncs $odir/$ifile.unlimited.$ncs
    $cdo -L -setmisstoc,100 -ifthen -ltc,100 $odir/$ifile.unlimited.$ncs $odir/$ifile.unlimited.$ncs $odir/$ifile.limited.$ncs
    exit_if_nt $odir/$ifile.unlimited.$ncs $odir/$ifile.limited.$ncs
    rm $odir/$ifile.unlimited.$ncs
    echo ... clamping done
    echo

    ipath=$odir/$ifile.limited
    stats="mean var1"
    echo computing multi-year daily $ysp-$yep means and variances of uncorrected data ...;;
  rsds)
    ipath=$idirgcm/$ifile
    stats="mean var1 max"
    echo computing multi-year daily $ysp-$yep means, variances and maxima of uncorrected data ...;;
  esac  # bcmethod
  for stat in $stats
  do
    # need to put -L to avoid seg faults- JUST FOUND THIS OUT THANKS NCI
    $cdo -L yday$stat -ifthen $ipathBCmask $ipath.$ncs $odir/$ifile.yday$stat.$ncs
    exit_if_nt $ipath.$ncs $odir/$ifile.yday$stat.$ncs

    # make sure leap days are covered
    case $nleapdaysinper in
    0)  # need to create leap day data
      $cdo inttime,2000-01-01,00:00:00,1day -setyear,2000 $odir/$ifile.yday$stat.$ncs $odir/$ifile.yday$stat.h.$ncs
      exit_if_nt $odir/$ifile.yday$stat.$ncs $odir/$ifile.yday$stat.h.$ncs
      mv $odir/$ifile.yday$stat.h.$ncs $odir/$ifile.yday$stat.$ncs
      ;;
    1)  # var1 not defined on leap day; replace it with mean of var1s of next and previous day
     if [[ $stat = var1 ]]
      then
        $cdo -O mergetime -select,timestep=1/59 $odir/$ifile.yday$stat.$ncs -select,timestep=61/366 $odir/$ifile.yday$stat.$ncs $odir/$ifile.yday$stat.h.$ncs
        exit_if_nt $odir/$ifile.yday$stat.$ncs $odir/$ifile.yday$stat.h.$ncs
        $cdo inttime,2000-01-01,00:00:00,1day -setyear,2000 $odir/$ifile.yday$stat.h.$ncs $odir/$ifile.yday$stat.$ncs
        exit_if_nt $odir/$ifile.yday$stat.h.$ncs $odir/$ifile.yday$stat.$ncs
        rm $odir/$ifile.yday$stat.h.$ncs
      fi  # stat
      ;;
    esac  # nleapdaysinper
  done  # stat
  echo ... computing done
  echo

  # get smoothed multi-year daily means, variances (and maxima) of uncorrected data
  case $bcmethod in
  hurs)
    get_coef_hurs_rsds_special_args="-l -u 100."
    echo smoothing multi-year daily $dataset means and variances ...;;
  rsds)
    get_coef_hurs_rsds_special_args="-f $rsdsmaxfitthreshold -t $sdir/python/TOA_daily_mean_insolation_climatology -x $odir/$ifile.ydaymax.$ncs"
    echo smoothing multi-year daily $dataset means, variances and maxima ...;;
  esac  # bcmethod
  python $sdir/python/get_coef_hurs_rsds.py $get_coef_hurs_rsds_special_args \
         -a $missval \
         -i $var \
         -n $nrunmeanhursrsds \
         -m $odir/$ifile.ydaymean.$ncs \
         -v $odir/$ifile.ydayvar1.$ncs \
         -o $odir/$ifile.$ncs
  for stat in $stats; do exit_if_nt $odir/$ifile.yday$stat.$ncs $odir/$ifile.$ncs; done
  for stat in $stats; do rm $odir/$ifile.yday$stat.$ncs; done
  echo ... smoothing done
  echo

  # get smoothed multi-year daily means, variances (and maxima) of corrected data
  ipathcoefobsref=$tdirobsc/${var}_${frequency}_${obsdataset}_${ysreference}0101-${yereference}1231
  ipathcoefgcmref=$odir/${var}_${frequency}_${gcm}_${expreference}_${realization}_${ysreference}0101-${yereference}1231
  ipathcoefgcmper=$odir/$ifile
  ipathcoefcorper=$odir/$ofile
  exit_if_any_does_not_exist $ipathcoefobsref.$ncs $ipathcoefgcmref.$ncs $ipathcoefgcmper.$ncs
  case $bcmethod in
  hurs)
    echo deriving smoothed multi-year daily $ysp-$yep means and variances of corrected data ...;;
  rsds)
    echo deriving smoothed multi-year daily $ysp-$yep means, variances and maxima of corrected data ...;;
  esac  # bcmethod
  for stat in meanrel var1rel
  do
     # need to put -L to avoid seg faults- JUST FOUND THIS OUT THANKS NCI 
     $cdo -L -ifthenelse -eq -selname,$stat $ipathcoefgcmper.$ncs -selname,$stat $ipathcoefgcmref.$ncs \
        -selname,$stat $ipathcoefobsref.$ncs \
        -ifthenelse -lt -selname,$stat $ipathcoefgcmper.$ncs -selname,$stat $ipathcoefgcmref.$ncs \
        -mul -selname,$stat $ipathcoefobsref.$ncs \
        -div -selname,$stat $ipathcoefgcmper.$ncs -selname,$stat $ipathcoefgcmref.$ncs \
        -addc,1 -mul -subc,1 -selname,$stat $ipathcoefobsref.$ncs \
        -div -subc,1 -selname,$stat $ipathcoefgcmper.$ncs -subc,1 -selname,$stat $ipathcoefgcmref.$ncs \
         $ipathcoefcorper.$stat.$ncs
    exit_if_nt $ipathcoefobsref.$ncs $ipathcoefcorper.$stat.$ncs
    exit_if_nt $ipathcoefgcmref.$ncs $ipathcoefcorper.$stat.$ncs
    exit_if_nt $ipathcoefgcmper.$ncs $ipathcoefcorper.$stat.$ncs
  done  # stat
  case $bcmethod in
  hurs)
    $cdo -O merge $ipathcoefcorper.meanrel.$ncs $ipathcoefcorper.var1rel.$ncs $ipathcoefcorper.$ncs
    exit_if_nt $ipathcoefcorper.meanrel.$ncs $ipathcoefcorper.$ncs
    exit_if_nt $ipathcoefcorper.var1rel.$ncs $ipathcoefcorper.$ncs
    rm $ipathcoefcorper.meanrel.$ncs $ipathcoefcorper.var1rel.$ncs
    ;;
  rsds)
    # need to put -L to avoid seg faults- JUST FOUND THIS OUT THANKS NCI
    $cdo -L -ifthenelse -gtc,0 -selname,max $ipathcoefgcmref.$ncs \
        -mul -selname,max $ipathcoefobsref.$ncs \
        -div -selname,max $ipathcoefgcmper.$ncs -selname,max $ipathcoefgcmref.$ncs \
        -selname,max $ipathcoefgcmref.$ncs \
         $ipathcoefcorper.max.$ncs
    exit_if_nt $ipathcoefobsref.$ncs $ipathcoefcorper.max.$ncs
    exit_if_nt $ipathcoefgcmref.$ncs $ipathcoefcorper.max.$ncs
    exit_if_nt $ipathcoefgcmper.$ncs $ipathcoefcorper.max.$ncs
    $cdo -O merge $ipathcoefcorper.meanrel.$ncs $ipathcoefcorper.var1rel.$ncs $ipathcoefcorper.max.$ncs $ipathcoefcorper.$ncs
    exit_if_nt $ipathcoefcorper.meanrel.$ncs $ipathcoefcorper.$ncs
    exit_if_nt $ipathcoefcorper.var1rel.$ncs $ipathcoefcorper.$ncs
    exit_if_nt $ipathcoefcorper.max.$ncs $ipathcoefcorper.$ncs
    rm $ipathcoefcorper.meanrel.$ncs $ipathcoefcorper.var1rel.$ncs $ipathcoefcorper.max.$ncs
    ;;
  esac  # bcmethod
  echo ... deriving done
  echo

  # correct year by year
  odir=$tdirgcmo
  echo correcting year by year ...
  for year in $(seq $ysp $yep)
  do
    echo ... $year ...
    yfile=$ofile.$year
    tfile=$yfile.$PBS_JOBID  # just to store a time stamp below

    $cdo -L -setreftime,${ysp}-01-01,00:00:00,day -selyear,$year $ipath.$ncs $odir/$yfile.$ncs
    exit_if_nt $ipath.$ncs $odir/$yfile.$ncs
    #WS had to change from lat, lon to latitude, longitude
    ncap2 -O -s "latitude=float(latitude);" $odir/$yfile.$ncs $odir/$yfile.$ncs
    ncap2 -O -s "longitude=float(longitude);" $odir/$yfile.$ncs $odir/$yfile.$ncs

    [[ $bcmethod = hurs ]] && app_coef_hurs_rsds_special_args="-l -m 100." || app_coef_hurs_rsds_special_args=
    touch $odir/$tfile  # this is necessary since yfile is modified in place
    python $sdir/python/app_coef_hurs_rsds.py $app_coef_hurs_rsds_special_args \
           -v $var \
           -i $odir/$yfile.$ncs \
           -u $ipathcoefgcmper.$ncs \
           -c $ipathcoefcorper.$ncs \
           -o $odir/$yfile.$ncs \
           -b $ipathBCmask \
           -a $missval
    errorcode=$?
    if [ $errorcode -ne 0 ]
    then
      echo python script execution returned error code $errorcode !!! exiting ... $(date)
      exit
    fi  # errorcode
    exit_if_nt $odir/$tfile $odir/$yfile.$ncs
    rm $odir/$tfile
  done  # year
  [[ $bcmethod = hurs ]] && rm $ipath.$ncs
  echo ... correcting done
  echo

  # merge annual NetCDF files
  echo merging annual NetCDF files to $opath.$ncs ...
  $cdo -O mergetime $odir/$ofile.????.$ncs $opath.$ncs
  for year in $(seq $ysp $yep); do exit_if_nt $odir/$ofile.$year.$ncs $opath.$ncs; done
  rm $odir/$ofile.????.$ncs
  echo ... merging done
  echo

  # modify NetCDF attributes
  ncatted -O \
  -a ,global,d,, \
  -a ,$var,d,, \
  -a _FillValue,$var,o,f,$missval \
  -a missing_value,$var,o,f,$missval \
  $opath.$ncs
  ;;
huss)
  # retrieve specific humidity from corrected hurs, ps and tas using Weedon2010 method
  ipathhurs=$odirgcm/hurs$ofilepostvar
  ipathps=$odirgcm/ps$ofilepostvar
  ipathtas=$odirgcm/tas$ofilepostvar
  exit_if_any_does_not_exist $ipathhurs.$ncs $ipathps.$ncs $ipathtas.$ncs

  echo merging bias-corrected hurs [1], ps [mb] and tas [degC] ...
  # need to put -L to avoid seg faults- JUST FOUND THIS OUT THANKS NCI
  $cdo -L -O merge -mulc,0.01 $ipathhurs.$ncs -mulc,0.01 $ipathps.$ncs -subc,273.15 $ipathtas.$ncs $opath.$ncs
  exit_if_nt $ipathhurs.$ncs $opath.$ncs
  exit_if_nt $ipathps.$ncs $opath.$ncs
  exit_if_nt $ipathtas.$ncs $opath.$ncs
  echo ... merging done
  echo

  # calculate huss monthwise to avoid memory errors
  cdoexprhuss=$(get_cdoexpr_huss_Weedon2010style huss hurs ps tas)
  echo retrieving $var from bias-corrected hurs, ps and tas month by month ...
  for year in $(seq $ysp $yep)
  do
    for month in $(seq -w 1 12)
    do
      $cdo expr,"$cdoexprhuss" -selmon,$month -selyear,$year $opath.$ncs $opath$year$month.$ncs
      exit_if_nt $opath.$ncs $opath$year$month.$ncs
    done  # month
  done  # year
  echo ... retrieving done
  echo

  # merge months
  echo merging monthly bias-corrected $var files ...
  $cdo -O mergetime $opath??????.$ncs $opath.$ncs
  for year in $(seq $ysp $yep); do for month in $(seq -w 1 12); do exit_if_nt $opath$year$month.$ncs $opath.$ncs; done; done
  rm $opath??????.$ncs
  echo ... merging done
  echo

  # remove global NetCDF attributes
  ncatted -O -a ,global,d,, $opath.$ncs
  ;;
prsn)
  # retrieve snowfall flux from corrected pr retaining the original snowfall to rainfall ratio
  ipathprc=$odirgcm/pr$ofilepostvar
  ipathpru=$idirgcm/pr$ifilepostvar
  ipathprsnu=$idirgcm/$ifile
  if [ $ysp -eq $ysreference ] && [ $yep -eq $yereference ] && [ ! -f $ipathpru ]
  then
    ipathpru=$tdirgcmi/pr$ifilepostvar
    merge_reference_decades_if_necessary pr $gcm $ysp-$yep $ipathpru $ipathBCmask
  fi
  exit_if_any_does_not_exist $ipathprc.$ncs $ipathpru.$ncs $ipathprsnu.$ncs

  echo retrieving $var from bias-corrected pr retaining the original snowfall to rainfall ratio ...
  # set prsn to zero if the corrected pr is zero else retain the original snowfall to rainfall ratio
  # make sure that prsnu <= pru since the input data do not guarantee that
  # need to put -L to avoid seg faults- JUST FOUND THIS OUT THANKS NCI
  $cdo -L -setname,$var \
      -ifthenelse -gtc,0 $ipathprc.$ncs \
      -mul $ipathprc.$ncs \
      -div -min $ipathpru.$ncs $ipathprsnu.$ncs $ipathpru.$ncs \
      -mulc,0 $ipathprc.$ncs \
       $opath.$ncs
  exit_if_nt $ipathprc.$ncs $opath.$ncs
  exit_if_nt $ipathpru.$ncs $opath.$ncs
  exit_if_nt $ipathprsnu.$ncs $opath.$ncs
  echo ... retrieving done
  echo

  # remove global NetCDF attributes
  ncatted -O -a ,global,d,, $opath.$ncs
  ;;
ps)
  # retrieve surface air pressure from corrected psl, tas and surface elevation
  ipathpsl=$odirgcm/psl$ofilepostvar
  ipathtas=$odirgcm/tas$ofilepostvar
  ipathoro=$idirobs/orog_$obsdataset
  exit_if_any_does_not_exist $ipathpsl.$ncs $ipathtas.$ncs $ipathoro.$ncs

  echo retrieving $var from $obsdataset orog and bias-corrected psl and tas ...
  # ps = psl / exp((g * oro)/(r_d * tas))
  # need to put -L to avoid seg faults- JUST FOUND THIS OUT THANKS NCI
  $cdo -L -setname,$var \
      -div, $ipathpsl.$ncs \
      -exp -div \
      -mulc,9.80665 $ipathoro.$ncs -mulc,287.05 $ipathtas.$ncs \
       $opath.$ncs
  exit_if_nt $ipathpsl.$ncs $opath.$ncs
  exit_if_nt $ipathtas.$ncs $opath.$ncs
  exit_if_nt $ipathoro.$ncs $opath.$ncs
  echo ... retrieving done
  echo

  # remove global NetCDF attributes
  ncatted -O -a ,global,d,, $opath.$ncs
  ;;
*)
  # convert NetCDF to IDL binary files
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

  #MARKER
  # apply transfer functions
  echo $tdirgcmi
  sfile=app.coef.monthly
  ipathdata=$tdirgcmi/${ifile}_
  ipathtasu=$tdirgcmi/tas${ifilepostvar}_
  ipathtasc=$tdirgcmo/tas${ofilepostvar}_
  ipathcoef=$tdirobsc/${var}_${frequency}_${gcm}_${expreference}_${realization}_${obsdataset}_${ysreference}0101-${yereference}1231_
  opathdata=$tdirgcmo/${ofile}_
  echo $ipathcoef
  for month in $(seq -w 1 12)
  do
    exit_if_any_does_not_exist $ipathdata$month.dat
    exit_if_any_does_not_exist $ipathcoef$month.dat
  done  # month

  echo applying transfer functions ...
  $sdir/bash/$sfile.sh $ipathdata $ipathtasu $ipathtasc $ipathcoef $opathdata
  if [ $lmonsb -eq 1 ]
  then
    wait_for_batch_jobs_to_finish $qsubedlist
    rm $qsubedlist $tdir/subscripts/*.$PBS_JOBID
  fi
  for month in $(seq -w 1 12)
  do
    exit_if_nt $ipathdata$month.dat $opathdata$month.dat
    exit_if_nt $ipathcoef$month.dat $opathdata$month.dat
  done  # month
  echo ... applying done
  echo

    # convert IDL binary files to NetCDF file
  echo converting monthly IDL binary files to NetCDF file ...
  sfile=convert.idl2nc.monthly
  ipath=$opathdata
  $sdir/bash/$sfile.sh $ipath $opath $time
  for month in $(seq -w 1 12); do exit_if_nt $ipath$month.dat $opath.$ncs; done
  echo ... converting done
  echo
  ;;
esac  # bcmethod

# set NetCDF attributes
echo setting NetCDF attributes ...
if [[ $gcm = HadGEM2-ES ]] && ([[ $exp = piControl ]] || [[ $exp = historical ]] || [[ $exp = rcp26 ]])
then
  nctitleprefix="CMIP5 output of ${var}_${frequency}_${gcm}_${exp}_${realization} rerun by Kate Halladay on the MOHC Cray XC40"
else
  nctitleprefix="CMIP5 output of ${var}_${frequency}_${gcm}_${exp}_${realization}"
fi

if [[ $bcmethod == "rsds" ]]; then
  echo ncatting for rsds
  ncatted -h \
  -a standard_name,$var,o,c,"$var_standard_name" \
  -a long_name,$var,o,c,"$var_long_name" \
  -a units,$var,o,c,"$var_units" \
  -a long_name,time,o,c,"time" \
  -a standard_name,latitude,o,c,"latitude" \
  -a long_name,latitude,o,c,"latitude" \
  -a units,latitude,o,c,"degrees_north" \
  -a standard_name,longitude,o,c,"longitude" \
  -a long_name,longitude,o,c,"longitude" \
  -a units,longitude,o,c,"degrees_east" \
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
else
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
fi
echo ... done
