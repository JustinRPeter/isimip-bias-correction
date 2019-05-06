# GCM Data Preparation

To prepare GCM data for the ISIMIP bias correction method two scripts need to be run, `data_prep.sh` and `data_prep2.sh`.

## data_prep.sh

This script copies raw GCM data for a specified time interval to the directory it's run in then (optionally) merges the files into a single .nc file.

### Example usage

If bias correcting precipitation using a reference period of 1976-2005 and a projection period of 2006-2100, commands to run would be:
```
./data_prep.sh 1970 2005 CNRM-CM5 /g/data/ua6/DRSv3/CMIP5/CNRM-CM5 historical pr latest Y

./data_prep.sh 2006 2100 CNRM-CM5 /g/data/ua6/DRSv3/CMIP5/CNRM-CM5 rcp85 pr latest Y
```

See the source code to understand the input arguments.

**NOTE**: We pass 1970 to `data_prep.sh` since later on in the process we'll need files split into decades (i.e we'll need a 19710101-19801231 file for a start year of 1976) and the GCM data is organised into 5 year chunks (19700101-19741231, 19750101-19791231).

## data_prep2.sh

This script splits the merged file created by `data_prep.sh` into decade files. Currently it's written to be run once for all variables and needs to be edited to suit the variables/time periods used for your bias correction. The output files will be saved to the directory the script is run in.

## WARNING:

No checking of outputs is currently implemented so it's advised that you use tools such as cdo, ncdump, etc to inspect outputs and make sure they're sensible before proceeding to use them.
