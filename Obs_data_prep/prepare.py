#!/usr/bin/env python3
from collections import namedtuple
import os
import subprocess
import sys

import cfg
import config_generator

config = cfg.get_config()
years = cfg.get_dict('Time Periods', config)
data_path = "/g/data/er4/jr6311/isimip-bias-correction/isimip-bias-correction/Obs_data_prep/"
chtime = 12


def exec_cmd(run_string):
    subprocess.run(run_string.split())

def run_tas(v, vdetails):
    exp1, exp2, exp3 = vdetails.expression
    output_file = (f'{data_path}/{v.name}_day_AWAP_{v.year_start}0101-{v.year_end}1231')
    obs_files = (f'tasmax_day_AWAP_{vdetails.year_start}0101-{vdetails.year_end}1231.nc4', f'tasmin_day_AWAP_{vdetails.year_start}0101-{vdetails.year_end}1231.nc4')

    if not (os.path.exists(obs_files[0]) and os.path.exists(obs_files[1])): sys.exit('ERROR: tasmax or tasmin does not exist!')

    exec_cmd(f'cdo -f nc4c -z zip_9 -merge {vdetails.obs_dir}/{obs_files[0]} {vdetails.obs_dir}/{obs_files[1]} {output_file}.nc4')
    exec_cmd(f'mv {output_file}.nc4 {output_file}.nc4_tmp')
    exec_cmd(f'cdo -f nc4c -z zip_9 {exp1} {output_file}.nc4_tmp {obs_files[0]}')
    exec_cmd(f'cdo -f nc4c -z zip_9 {exp2} {output_file}.nc4_tmp {obs_files[1]}')
    exec_cmd(f'cdo -f nc4c -z zip_9 -merge obs_dir/{obs_files[0]} {vdetails.obs_dir}/{obs_files[1]} {output_file}.nc4')
    exec_cmd(f'cdo -f nc4c -z zip_9 {exp3} {output_file}.nc4_tmp {output_file}.nc4')
    exec_cmd(f'mv {output_file}.nc4 {output_file}.nc4_tmp')
    exec_cmd(f'cdo -f nc4c -z zip_9 selvar,{v.name} {output_file}.nc4_tmp {output_file}.nc4')


def define_variables(v):
    VarDetails = namedtuple('VarDetails', ['obs_dir', 'obs_file', 'year_start', 'year_end', 'expression'])
    obs_file = v.obs_dir.split('/')[-1]
    print("obs file:", obs_file)
    expression = exp_dict[v.name]
    var_details = VarDetails(v.obs_dir, v.obs_file, years['start_year'],  years['end_year'], expression)
    return var_details

exp_dict = {'tasmax': "-expr,'tasmax = (( tasmax > -999.0 ))? 273.15 + tasmax:tasmax' -chunit,'degC','K'",
            'tasmin': "-expr,'tasmin = (( tasmin > -999.0 ))? 273.15 + tasmin:tasmin' -chunit,'degC','K'",
            'tas': {"-expr,'tasmax=(tasmin>tasmax)?tasmin:tasmax'", "-expr,'tasmin=(tasmax<tasmin)?tasmax:tasmin'", "-expr,'tas=0.75*tasmax+0.25*tasmin'"},
            'rsds': "-expr,'rsds = (( rsds > -999.0 ))? 11.57407 * rsds:rsds' -chunit,'MJ m^-2','W m^-2'",
            'pr': "-expr,'pr = (( pr > -999.0 ))? pr/86400:pr' -chunit,'mm','kg m-2 s-1'",
            'sfcWind': ""
            }

def build_file_list(v):
    print('obs file', v.obs_file)
    strbuilder = ''
    for i in range(years['start_year'], years['end_year']):
        strbuilder += f' {v.obs_dir}/{v.obs_file}_{i}.nc'
    return strbuilder

def get_obs_data(v, vdetails):
    file_list = build_file_list(v)
    output_file = (f'{data_path}/{v.name}_day_AWAP_{vdetails.year_start}0101-{vdetails.year_end}1231')

    exec_cmd(f'cdo -f nc4c -z zip_9 -mergetime {file_list} {output_file}.nc4')
    exec_cmd(f'ncrename -O -v {vdetails.obs_file},{v.name} {output_file}.nc4')
    exec_cmd(f'ncatted -O -a var_name,global,m,c,{v.name} {output_file}.nc4')
    exec_cmd(f'mv {output_file}.nc4 {output_file}.nc4_tmp')

    if(chtime == '12'):
        exec_cmd(f'cdo -f nc4c -z zip_9 -settaxis,{vdetails.year_start}-01-01,12:00:00,day {output_file}.nc4_tmp {output_file}.nc4')
    else:
        exec_cmd(f'cdo -f nc4c -z zip_9 -settaxis,{vdetails.year_start}-01-01,00:00:00,day {output_file}.nc4_tmp {output_file}.nc4')

    if vdetails.expression is not None:
        exec_cmd(f'mv {output_file}.nc4 {output_file}.nc4_tmp')
        exec_cmd(f'cdo -f nc4c -z zip_9 {vdetails.expression} {output_file}.nc4_tmp {output_file}.nc4')

    exec_cmd(f'rm *_tmp')

if __name__ == '__main__':
    for v in cfg.active_vars:
        if (v.name is not 'tas'):
            vdetails = define_variables(v)
            get_obs_data(v, vdetails)
        else:
            vdetails = define_variables(v)
            run_tas(v, vdetails)