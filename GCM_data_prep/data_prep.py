#!/usr/bin/env python3
import subprocess
import glob
import math
import sys
import os

# Establish execution function
def exec_cmd(run_string):
    subprocess.run(run_string.split())

# argsArr1= ['1976', '2005', 'CNRM-CM5', '/g/data/al33/replicas/CMIP5/combined/CNRM-CERFACS/CNRM-CM5',
#            'historical', 'pr', 'v20120530', 'Y']
# argsArr1= ['1976', '2005', 'MICROC5', '/g/data/al33/replicas/CMIP5/combined/MIROC/MIROC5',
#            'historical', 'pr', 'v20120710', 'Y']
# argsArr1 = ['1976', '2005', 'GFDL-ESM2M', '/g/data/al33/replicas/CMIP5/combined/NOAA-GFDL/GFDL-ESM2M',
#            'historical', 'pr', 'v20111228', 'Y']
# argsArr= ['1976', '2005', 'ACCESS1-0', '/g/data/rr3/publications/CMIP5/output1/CSIRO-BOM/ACCESS1-0',
#            'historical', 'pr', 'latest', 'Y']
# Test implementation
# year_start = argsArr[0]
# year_end = argsArr[1]
# gcm = argsArr[2]
# input_path = argsArr[3]
# rcp = argsArr[4]
# var = argsArr[5]
# ver = argsArr[6]
# merge = argsArr[7]

# Take command-line arguments
year_start = sys.argv[1]
year_end = sys.argv[2]
gcm = sys.argv[3]
input_path = sys.argv[4]
rcp = sys.argv[5]
var = sys.argv[6]
ver = sys.argv[7]
merge = sys.argv[8]

# Append with appropriate suffix
year_start_app = year_start + "0101"
year_end_app = year_end + "1231"

# Declare path variables
data_path = f"{input_path}/{rcp}/day/atmos/day/r1i1p1/{ver}/{var}"
file_name = f"{var}_day_{gcm}_{rcp}_r1i1p1_"
output_path = f"/g/data/er4/jr6311/isimip-bias-correction/isimip-bias-correction/{gcm}"
year_decade = str(math.floor(int(year_start)/10)*10)

# Retrieve and sort files
filelist = (glob.glob(data_path + "/" + "*" + rcp + "*"))
filelist.sort()
filteredfiles = []

# Indexing variables for tests
year_start_idx = 0
year_end_idx = 0
year_check = 0

# Loop through and find the earliest RELEVANT year to the specified time
for i,val in enumerate(filelist):
    if(int(filelist[i][-20:-16]) <= int(year_decade) and int(filelist[i][-20:-16]) > year_check):
        year_check = int(filelist[i][-20:-16])
        year_start_idx = i

# Loop through and find the latest RELEVANT year to the specified time
for i, val in enumerate(filelist, start = year_start_idx):
    if(int(filelist[i][-11:-7]) >= int(year_end)):
        year_end_idx = i
        break

# Add all items to a NEW list than can be run through to get GCM data
for x in range(year_start_idx, year_end_idx+1):
    filteredfiles.append(filelist[x])

# Copy file to working directory
for x in filteredfiles:
    exec_cmd(f"echo copying file: {x}")
    exec_cmd(f"cp {x} {os.getcwd()}")

# Generate the output folder if it doesn't exist
exec_cmd(f"mkdir -p {output_path}")

# If merge is 'Y'/'y' combine all the input files into a single input
if (merge.lower() == "y"):
    exec_cmd(f"echo Merging files then selecting date range from {year_start} to {year_end}")
    exec_cmd(f"cdo -f nc4c -z zip_9 -mergetime {' '.join(filteredfiles)} {os.getcwd()}/tmp_{file_name}merged.nc")

exec_cmd(f"cdo -f nc4c -z zip_9 -seldate,{year_start}0101,{year_end}1231 {os.getcwd()}/tmp_{file_name}merged.nc {output_path}/{file_name}{year_start_app}-{year_end_app}.nc")

# Clean-up resources
for x in filteredfiles:
    if(os.path.basename(x) in " ".join(glob.glob(f"{os.getcwd()}/*"))):
        exec_cmd(f"rm {os.getcwd()}/{os.path.basename(x)}")
exec_cmd(f"rm {os.getcwd()}/tmp_{file_name}merged.nc")