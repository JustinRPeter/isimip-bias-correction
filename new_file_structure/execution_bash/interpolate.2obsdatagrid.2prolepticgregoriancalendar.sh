#!/bin/bash

#PBS -l walltime=24:00:00
#PBS -P er4
##PBS -M wendy.sharples@bom.gov.au
#PBS -l ncpus=16
#PBS -l mem=128gb



#PBS -o qlogs/interpolate.2obsdatagrid.2prolepticgregoriancalendar.out
#PBS -e qlogs/interpolate.2obsdatagrid.2prolepticgregoriancalendar.err

#CHANGED WKS
fullpath=/g/data/er4/jr6311/isimip-bias-correction/isimip-bias-correction/ISIMIP2b_bc-master_PBS/
source ${fullpath}/exports.settings.functions.sh



# check input parameters
if [ ! $# -eq 6 ]
then
  echo six input parameters expected !!! exiting ... $(date)
  exit
fi

obsdataset=$1
case $obsdataset in
EWEMBI|MSWEP|WFD|AWAP)
  echo observational dataset $obsdataset;;
*)
  echo observational dataset $obsdataset not supported !!! exiting ... $(date)
  exit;;
esac  # obsdataset

ovar=$2
case $ovar in
huss|pr|prsn|psl|rlds|rsds|tas|tasmax|tasmin|tos)
  echo variable $ovar
  ivar=$ovar
  remapweightsfileextension=;;
hurs)  # special case since hurs was mostly called rhs in CMIP5
  echo variable $ovar
  ivar=rhs
  remapweightsfileextension=;;
sfcWind)  # special case since wind fields may be defined on a staggered grid
  echo variable $ovar
  ivar=$ovar
  remapweightsfileextension=.wind;;
*)
  echo variable $ovar not supported !!! exiting ... $(date)
  exit;;
esac
[[ $ivar != $ovar ]] && cdosetname="-setname $ovar" || cdosetname=

gcm=$3
case $gcm in  # set input calendar
GFDL-ESM2M|IPSL-CM5A-LR|MIROC5|NorESM1-M)
  echo GCM $gcm
  icalendar=365_day;;
CMCC-CESM|CNRM-CM5|ACCESS1-0)
  echo GCM $gcm
  icalendar=standard;;
HadGEM2-ES)
  echo GCM $gcm
  icalendar=360_day;;
*)
  echo GCM $gcm not supported !!! exiting ... $(date)
  exit;;
esac  # gcm

exp=$4
case $exp in
piControl|historical|rcp26|rcp45|rcp60|rcp85)
  echo experiment $exp;;
*)
  echo experiment $exp not supported !!! exiting ... $(date)
  exit;;
esac

per=$5
if [[ $per =~ [0-9]{4}-[0-9]{4} ]]
then
  echo period $per
  ysp=$(cut -d '-' -f 1 <<<$per)
  yep=$(cut -d '-' -f 2 <<<$per)
  echo ysp is $ysp
  echo yep is $yep
else
  echo period $per has invalid format !!! exiting ... $(date)
  exit
fi  # per
echo

setreftime=$6
case $setreftime in  # set input calendar
True|False)
    echo setreftime? $setreftime;;
*)
    echo setreftime must be True or False!!! exiting
    exit;;
esac
# set calendar and reference of output time axis
ocalendar=proleptic_gregorian
tsp=$ysp-01-01,00:00:00
timeframe=${ysp}0101-${yep}1231

# set input directory and file name
# (customize to your raw climate model output data directory and file name structures)
#CHANGED WKS
idir=$idirGCMsource/$gcm  
ifile=${ivar}_${frequency}_${gcm}_${exp}_${realization}_$timeframe.nc

# set output directory and file name
odir=$idirGCMdata/$gcm
ofile=${ovar}_${frequency}_${gcm}_${exp}_${realization}_$timeframe  # suffix is determined by shell variable ncs
[ ! -d $odir ] && mkdir -p $odir

# set paths to remap weights
remapweightsdir=$tdir/remapweights
remapgriddesfile=$idirOBSdata/$obsdataset.griddes
remapweightsfile=$remapweightsdir/$gcm.remap$remapmethod.$obsdataset$remapweightsfileextension
[ ! -d $remapweightsdir ] && mkdir -p $remapweightsdir



# generate remap weights
if [ $remapgriddesfile -nt $remapweightsfile.$ncs ]
then 
  echo generating remap weights ...
  $cdo gen$remapmethod,$remapgriddesfile $idir/$ifile $remapweightsfile.$ncs
  wait
fi
echo

# interpolate in space
echo interpolating $ysp-$yep in space ...
#DEBUG
echo $tdir
echo $idir/$ifile
echo $odir/$ofile.$ncs

#WKS CHANGED- chaining did not work:
if [[ $setreftime =~ "True" ]]; then
	$cdo -r setreftime,$tsp,day $cdosetname $idir/$ifile $tdir/${ofile}_setreftime.$ncs
	$cdo -remap,$remapgriddesfile,$remapweightsfile.$ncs $tdir/${ofile}_setreftime.$ncs $odir/$ofile.$ncs
else
	$cdo -remap,$remapgriddesfile,$remapweightsfile.$ncs $idir/$ifile $odir/$ofile.$ncs
fi
#$cdo -r setreftime,$tsp,day $cdosetname \
#     -remap,$remapgriddesfile,$remapweightsfile.$ncs $idir/$ifile \
#     $odir/$ofile.$ncs
#echo

# interpolate in time
case $icalendar in
365_day|360_day)
  echo interpolating $ysp-$yep in time ...
  if [[ $icalendar = 360_day ]]; then
    # turn 360_day into 365_day calendar
    # (unfortunately this does not work with cdo setcalendar)
    # we devide the 360=72*5 days per year into six blocks with 
    # 36, 72, 72, 72, 72, 36 days worth of data per block
    # and then interpolate one day worth of data into the five gaps
    $cdo splityear $odir/$ofile.$ncs $odir/$ofile
    for year in $(seq $ysp $yep)
    do
      tsy=$year-01-01,00:00:00
      $cdo settaxis,$tsy,1day $odir/$ofile$year.$ncs $odir/$ofile$year.h.$ncs
      ncatted -a calendar,time,o,c,365_day $odir/$ofile$year.h.$ncs
      $cdo -O mergetime \
           -shifttime,0day -select,timestep=1/36 $odir/$ofile$year.h.$ncs \
           -shifttime,1day -select,timestep=37/108 $odir/$ofile$year.h.$ncs \
           -shifttime,2day -select,timestep=109/180 $odir/$ofile$year.h.$ncs \
           -shifttime,3day -select,timestep=181/252 $odir/$ofile$year.h.$ncs \
           -shifttime,4day -select,timestep=253/324 $odir/$ofile$year.h.$ncs \
           -shifttime,5day -select,timestep=325/360 $odir/$ofile$year.h.$ncs \
           $odir/$ofile$year.$ncs
      $cdo setreftime,$tsp,day \
           -inttime,$tsy,1day $odir/$ofile$year.$ncs \
           $odir/$ofile$year.h.$ncs
      mv $odir/$ofile$year.h.$ncs $odir/$ofile$year.$ncs
    done  # year
    $cdo -O mergetime $odir/$ofile????.$ncs $odir/$ofile.$ncs
    rm $odir/$ofile????.$ncs
  fi
  # turn 365_day into output calendar
  $cdo -L -setreftime,$tsp,day \
       -inttime,$tsp,1day \
       -setcalendar,$ocalendar \
       -settaxis,$tsp,1day $odir/$ofile.$ncs \
       $odir/$ofile.h.$ncs
  mv $odir/$ofile.h.$ncs $odir/$ofile.$ncs;;
standard)
  if [[ $ysp -le 1582 ]]
  then
    echo standard and $ocalendar calendar differ before 1582-10-15 !!! please adjust script to cover that case !!! exiting ... $(date)
    exit
  else
    echo changing NetCDF calendar attribute from standard to $ocalendar
    ncatted -a calendar,time,o,c,$ocalendar $odir/$ofile.$ncs
  fi;;
$ocalendar)
  echo no time interpolation necessary;;
*)
  echo time interpolation not supported for input calendar=$icalendar !!! exiting ... $(date)
  exit;;
esac  # icalendar
# cdo -f nc4c -z zip setreftime,1975-01-01,00:00:00,day -inttime,1975-01-01,00:00:00,1day -setcalendar,proleptic_gregorian -settaxis,1975-01-01,00:00:00,1day
# $cdo -L -setreftime,1975-01-01,00:00:00,day -inttime,1975-01-01,00:00:00,1day -settaxis,1975-01-01,00:00:00,1day -setcalendar,proleptic_gregorian ../GCMinput/MIROC5/pr_day_MIROC5_historical_r1i1p1_19750101-19841231.nc4 tmp.nc4
# cdo f nc4c -z zip -L -setreftime,1971-01-01,00:00:00,day -inttime,1971-01-01,00:00:00,1day -setcalendar,proleptic_gregorian -settaxis,1971-01-01,00:00:00,1day /g/data/er4/jr6311/isimip-bias-correction/isimip-bias-correction/jobs/GCMinput/MIROC5/pr_day_MIROC5_historical_r1i1p1_19710101-19801231.nc4