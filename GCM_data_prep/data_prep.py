#!/usr/bin/env python3
from collections import namedtuple
import glob
import math
import os
import subprocess
import sys

import cfg

# Declare fixed gloabl variables
config = cfg.get_config()
gcm = cfg.get_gcm(config)
years = cfg.get_dict('Time Periods', config)

# Establish command-line execution function
def exec_cmd(run_string):
    subprocess.run(run_string.split())

# Retrieve file listing and copy to working directory
def get_files(finfo, dinfo, vinfo):
    # Indexing variables for tests
    year_start_idx = 0
    year_end_idx = 0
    year_check = 0

    # Retrieve and sort files
    filelist = (glob.glob(f"{finfo.data_path}/*{vinfo.rcp}*"))
    filelist.sort()
    filteredfiles = []
    print(f"{finfo.data_path}/*{vinfo.rcp}*")

    # Loop through and find the earliest RELEVANT year to the specified time
    for i,val in enumerate(filelist):
        if(int(filelist[i][-20:-16]) <= int(dinfo.decade) and int(filelist[i][-20:-16]) > year_check):
            year_check = int(filelist[i][-20:-16])
            year_start_idx = i

    # Loop through and find the latest RELEVANT year to the specified time
    for i, val in enumerate(filelist, start = year_start_idx):
        if(int(filelist[i][-11:-7]) >= int(dinfo.year_end)):
            year_end_idx = i
            break

    # Add all items to a NEW list than can be run through to get GCM data
    for x in range(year_start_idx, year_end_idx+1):
        filteredfiles.append(filelist[x])

    # Copy file to working directory
    for x in filteredfiles:
        print(f"Copying file: {x}")
        exec_cmd(f"cp {x} {os.getcwd()}")

    return filteredfiles

# Get file output - execute muliple CDO commands
def process_files(filteredfiles, finfo, dinfo):
    # Generate the output folder if it doesn't exist, then merge relevant files into a single output
    exec_cmd(f"mkdir -p {finfo.gcm_output_path}")
    print(f"Merging files then selecting date range from {dinfo.year_start} to {dinfo.year_end}")
    exec_cmd(f"cdo -f nc4c -z zip_9 -mergetime {' '.join(filteredfiles)} {os.getcwd()}/tmp_{file_info.file_name}merged.nc")
    exec_cmd(f"cdo -f nc4c -z zip_9 -seldate,{dinfo.year_start_app},{dinfo.year_end_app} {os.getcwd()}/tmp_{finfo.file_name}merged.nc {finfo.gcm_output_path}/{finfo.file_name}{dinfo.year_start_app}-{dinfo.year_end_app}.nc")

    # Clean-up tmp files
    for x in filteredfiles:
        if(os.path.basename(x) in " ".join(glob.glob(f"{os.getcwd()}/*"))):
            exec_cmd(f"rm {os.getcwd()}/{os.path.basename(x)}")
    exec_cmd(f"rm {os.getcwd()}/tmp_{finfo.file_name}merged.nc")

# Split files if rcp is historical to prepare for isimip interp
def split_files(gcm, var):
    start_years, end_years = year_split_decade(years['start_year'], years['end_year'])
    for i, j in zip(start_years, end_years):
            exec_cmd(f"cdo -f nc4c -z zip_9 -seldate,{i},{j} ../{gcm}/{var}_day_{gcm}_historical_r1i1p1_19710101-20051231.nc ../{gcm}/{var}_day_{gcm}_historical_r1i1p1_{i}-{j}.nc")


def define_variables(v, reference_period):
    FileInfo = namedtuple('FileInfo', ['data_path', 'file_name', 'gcm_output_path'])
    DateInfo = namedtuple('DateInfo', ['year_start', 'year_end', 'decade', 'year_start_app', 'year_end_app'])
    VersionInfo = namedtuple('VersionInfo', ['rcp', 'ver'])

    gcm_output_path = f"/g/data/er4/jr6311/isimip-bias-correction/isimip-bias-correction/{gcm}"

    #Check if data is for reference period (True/False - Flag)
    if reference_period:
        decade = str(math.floor(years['start_year']/10)*10)
        file_info = FileInfo(f"{v.gcm_dir}/{v.rcp}/day/atmos/day/r1i1p1/{v.version}/{v.name}", f"{v.name}_day_{gcm}_{v.rcp}_r1i1p1_", gcm_output_path)
        date_info = DateInfo(years['start_year'],  years['end_year'], decade, f"{years['start_year']}0101", f"{years['end_year']}1231")
        version_info = VersionInfo(v.rcp, v.version)
    else:
        decade = str(math.floor(years['projection_start']/10)*10)
        file_info = FileInfo(f"{v.gcm_dir}/{v.projection_rcp}/day/atmos/day/r1i1p1/{v.projection_version}/{v.name}", f"{v.name}_day_{gcm}_{v.projection_rcp}_r1i1p1_", gcm_output_path)
        date_info = DateInfo(years['projection_start'],  years['projection_end'], decade, f"{years['projection_start']}0101", f"{years['projection_end']}1231")
        version_info = VersionInfo(v.projection_rcp, v.projection_version)

    return (file_info, date_info, version_info)

# Run main script functions
if __name__ == '__main__':
    for v in cfg.active_vars:
        # Prepare GCM data for reference period
        file_info, date_info, version_info = define_variables(v, True)
        files = get_files(file_info, date_info, version_info)
        process_files(files, file_info, date_info)
        split_files(gcm, v.name)

        # Prepare GCM data for projection period
        file_info, date_info, version_info = define_variables(v, False)
        files = get_files(file_info, date_info, version_info)
        process_files(files, file_info, date_info)