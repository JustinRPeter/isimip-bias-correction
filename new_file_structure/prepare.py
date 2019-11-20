#!/usr/bin/env python3
from collections import namedtuple
import numpy as np
import os
import subprocess
import sys
import xarray as xr

import cfg
import config_generator

config = cfg.get_config()
years = cfg.get_dict('Time Periods', config)
data_path = "/g/data1a/er4/jr6311/isimip-bias-correction/isimip-bias-correction/new_file_structure/ProjectFiles/obs_data"
chtime = 12

def exec_cmd(run_string):
    """Accept string that will be parsed to be executed as a bash command"""
    subprocess.run(run_string.split())

def var_delegator(v):
    vdetails = define_variables(v)
    if v.name in ['tasmin', 'tasmax', 'tas']:
        if v.name == 'tas':
            get_tas(vdetails)
    else:
        run_general(vdetails)

def get_tas(vdetails):
    # for i in cfg.active_vars[0:3]:
    #     if os.path.exists(f'{data_path}/{i.name}_day_{vdetails.data_type}_{vdetails.year_start}0101-{vdetails.year_end}1231.nc4'):
    #         return

    remap_tas(vdetails)

    for v in cfg.active_vars[0:3]:
        output_file = (f'{data_path}/{v.name}_day_{vdetails.data_type}_{vdetails.year_start}0101-{vdetails.year_end}1231')

        if(v.name != 'tas'):
            exec_cmd(f'ncrename -O -v {v.obs_file},{v.name} {output_file}.nc4')
            exec_cmd(f'ncatted -O -a var_name,global,m,c,{v.name} {output_file}.nc4')
            exec_cmd(f'mv {output_file}.nc4 {output_file}.nc4_tmp')

        if(chtime == '12'):
            exec_cmd(f'cdo -f nc4c -z zip_9 -settaxis,{vdetails.year_start}-01-01,12:00:00,day {output_file}.nc4_tmp {output_file}.nc4')
        else:
            exec_cmd(f'cdo -f nc4c -z zip_9 -settaxis,{vdetails.year_start}-01-01,00:00:00,day {output_file}.nc4_tmp {output_file}.nc4')

        os.remove(f'{output_file}.nc4_tmp')

def remap_tas(vdetails):

    # Open datasets and retrieve corrected arrays
    min_filelist = build_file_list(cfg.active_vars[0]).split()
    max_filelist = build_file_list(cfg.active_vars[1]).split()

    tasmin_ds = xr.open_mfdataset(min_filelist, combine='by_coords')
    tasmax_ds = xr.open_mfdataset(max_filelist, combine='by_coords')

    tasmin_ds_fix = xr.ufuncs.fmin(tasmin_ds.temp_min_day, tasmax_ds.temp_max_day)
    tasmax_ds_fix = xr.ufuncs.fmax(tasmin_ds.temp_min_day, tasmax_ds.temp_max_day)

    # Preserve encoding and attributes
    tasmin_ds_fix.attrs = tasmin_ds.temp_min_day.attrs
    tasmin_ds_fix.encoding = tasmin_ds.temp_min_day.encoding

    tasmax_ds_fix.attrs = tasmax_ds.temp_max_day.attrs
    tasmax_ds_fix.encoding = tasmax_ds.temp_max_day.encoding

    # Apply corrected arrays
    tasmin_ds['temp_min_day'] = tasmin_ds_fix
    tasmax_ds['temp_max_day'] = tasmax_ds_fix
    tasmin_ds.time.encoding = xr.open_dataset(min_filelist[0]).time.encoding
    tasmax_ds.time.encoding = xr.open_dataset(max_filelist[0]).time.encoding

    # Adjust units
    tasmax_ds.temp_max_day.attrs['units'], tasmin_ds.temp_min_day.attrs['units'] = 'K'*2

    # Update tasmin/tasmax
    tasmin_ds['temp_min_day'] += 273.15
    tasmax_ds['temp_max_day'] += 273.15

    # Add encoding and attributes to tas
    tas_ds = tasmin_ds
    tas_ds = tas_ds.rename({'temp_min_day': 'tas'})
    tas_ds['tas'] = 0.75*tasmax_ds['temp_max_day'] + 0.25*tasmin_ds['temp_min_day']
    tas_ds.attrs = {'var_name': 'tas'}
    tas_ds.tas.encoding = tasmin_ds.temp_min_day.encoding
    tas_ds.tas.attrs = tasmin_ds.temp_min_day.attrs

    # Close datasets to allow saving
    tasmin_ds.close()
    tasmax_ds.close()
    print("Outputting datasets...")
    # Output datasets
    tasmin_ds.to_netcdf(f'{data_path}/tasmin_day_{cfg.active_vars[1].obs_datatype}_{vdetails.year_start}0101-{vdetails.year_end}1231.nc4', unlimited_dims=['time'])
    print("Tasmin output")
    tasmax_ds.to_netcdf(f'{data_path}/tasmax_day_{cfg.active_vars[0].obs_datatype}_{vdetails.year_start}0101-{vdetails.year_end}1231.nc4', unlimited_dims=['time'])
    print("Tasmax output")
    tas_ds.to_netcdf(f'{data_path}/tas_day_{cfg.active_vars[2].obs_datatype}_{vdetails.year_start}0101-{vdetails.year_end}1231.nc4_tmp', unlimited_dims=['time'])
    print("Tas output")

def define_variables(v):
    """Return a namedtuple with 'v' variable information"""
    VarDetails = namedtuple('VarDetails', ['data_type', 'obs_dir', 'obs_file', 'year_start', 'year_end'])
    obs_file = v.obs_dir.split('/')[-1]
    var_details = VarDetails(v.obs_datatype, v.obs_dir, v.obs_file, years['start_year'],  years['end_year'])
    return var_details

def apply_expressions(file, var):
    exp_dict = {'tasmax': [lambda x: x + 237.15, 'K'],
                'tasmin': [lambda x: x + 237.15, 'K'],
                'rsds': [lambda x: x * 11.57407, 'W m-2'],
                'pr': [lambda x: x / 86400, 'kg m-2 s-1'],
                'sfcWind': None
                }

    if exp_dict[var] is None:
        return

    ds = xr.open_dataset(file)
    getattr(ds, var).values = exp_dict[var][0](getattr(ds, var).values)
    getattr(ds, var).attrs['units'] = exp_dict[var][1]
    ds.to_netcdf(file)

def build_file_list(v):
    """Get active variable and return a string of filenames to process."""
    strbuilder = ''
    for i in range(years['start_year'], years['end_year'] + 1):
        strbuilder += f' {v.obs_dir}/{v.obs_file}_{i}.nc'
    return strbuilder.strip()

def run_general(v, vdetails):
    """Execute CDO commands.

    Args:
        v: Active variable to run
        vdetails: Tuple storing variable details
    """
    file_list = build_file_list(v)
    output_file = (f'{data_path}/{v.name}_day_{vdetails.data_type}_{vdetails.year_start}0101-{vdetails.year_end}1231')

    exec_cmd(f'cdo -f nc4c -z zip_9 -mergetime {file_list} {output_file}.nc4')
    print('Operation 1 done.')
    exec_cmd(f'ncrename -O -v {vdetails.obs_file},{v.name} {output_file}.nc4')
    print('Operation 2 done.')
    exec_cmd(f'ncatted -O -a var_name,global,m,c,{v.name} {output_file}.nc4')
    print('Operation 3 done.')
    exec_cmd(f'mv {output_file}.nc4 {output_file}.nc4_tmp')

    if(chtime == '12'):
        exec_cmd(f'cdo -f nc4c -z zip_9 -settaxis,{vdetails.year_start}-01-01,12:00:00,day {output_file}.nc4_tmp {output_file}.nc4')
    else:
        exec_cmd(f'cdo -f nc4c -z zip_9 -settaxis,{vdetails.year_start}-01-01,00:00:00,day {output_file}.nc4_tmp {output_file}.nc4')

    apply_expressions(f'{output_file}.nc4', v.name)

    os.remove(f'{output_file}.nc4_tmp')

if __name__ == '__main__':
    for v in cfg.active_vars:
        var_delegator(v)