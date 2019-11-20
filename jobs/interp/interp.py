#!/usr/bin/env python3
from multiprocessing import Pool
import subprocess

import cfg

globalpath = '/g/data/er4/jr6311/isimip-bias-correction/isimip-bias-correction/ISIMIP2b_bc-master_PBS'
config = cfg.get_config()
years = cfg.get_dict('Time Periods', config)
gcm = cfg.get_gcm(config)

def exec_cmd(run_string):
    subprocess.run(run_string.split())

# Do interpolation for reference period
def interpolate(var):
    period = f"{years['projection_start']}-{years['projection_end']}"
    exec_cmd(f'{globalpath}/interpolate.2obsdatagrid.2prolepticgregoriancalendar.sh {var.obs_datatype} {var.name} {gcm} {var.projection_rcp} {period} False')

# Do interpolation for projection period
def interpolate_hist(var):
    start_years_list, end_years_list = cfg.year_split_decade(years['start_year'], years['end_year'])
    for i, j in zip(start_years_list, end_years_list):
        period = f'{i}-{j}'
        exec_cmd(f'{globalpath}/interpolate.2obsdatagrid.2prolepticgregoriancalendar.sh {var.obs_datatype} {var.name} {gcm} {var.rcp} {period} False')


if __name__ == '__main__':
    exec_cmd('./init.pbs')
    cfg.init_env_vars()
    with Pool() as p:
        minterp = p.map_async(interpolate_hist, cfg.active_vars)
        minterphist = p.map_async(interpolate, cfg.active_vars)

        # Creating blocking behaviour to ensure processes execute
        minterp.get()
        minterphist.get()