#!/usr/bin/env python3
import cfg
import subprocess
import glob
import math
import sys
import os

config = cfg.get_config('foo.yml')
start, end = config['limits']
start, end = config.limits

# Establish execution function
def exec_cmd(run_string):
    subprocess.run(run_string.split())

for v in cfg.variables:
    # Take command-line arguments
    year_start = str(cfg.year_start)
    year_end = str(cfg.year_end)
    gcm = cfg.gcm
    input_path = cfg.stream[f"{v}"]["gcm_input_dir"]
    rcp = cfg.stream[f"{v}"]["rcp"]
    var = v
    ver = cfg.stream[f"{v}"]["version"]
    merge = "y"
    dataprep(config)
    dataprep(year_start, year_end, gcm, input_path, rcp, var, merge)
    split_files(gcm, var)
    dataprep(cfg.projection_start, cfg.projection_end, gcm, input_path, cfg.stream[f"{v}"]["projection_rcp"], cfg.stream[f"{v}"]["projection_version"], merge)

def dataprep(year_start, year_end, gcm, input_path, rcp, var, merge):
    # Append with appropriate suffix
    year_start_app = year_start + "0101"
    year_end_app = year_end + "1231"

    # Declare path variables
    data_path = f"{input_path}/{rcp}/day/atmos/day/r1i1p1/{ver}/{var}"
    file_name = f"{var}_day_{gcm}_{rcp}_r1i1p1_"
    output_path = f"/g/data/er4/jr6311/isimip-bias-correction/isimip-bias-correction/{gcm}"
    year_decade = str(math.floor(int(year_start)/10)*10)

    # Retrieve and sort files
    filelist = (glob.glob(f"{data_path}/*{rcp}*"))
    filelist.sort()
    filteredfiles = []
    print(f"{data_path}/*{rcp}*")

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


# Split files if rcp is historical to prepare for isimip interp
def split_files(gcm, var)
    var_list = cfg.variables
    yst = [19710101, 19810101, 19910101, 20010101]
    yen = [19801231, 19901231, 20001231, 20051231]
    for i in range(len(yst)):
            exec_cmd(f"cdo -f nc4c -z zip_9 -seldate,{yst[i]},{yen[i]} ../{gcm}/{var}_day_{gcm}_historical_r1i1p1_19710101-20051231.nc ../{gcm}/{var}_day_{gcm}_historical_r1i1p1_{yst[i]}-{yen[i]}.nc")