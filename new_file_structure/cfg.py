#!/usr/bin/env python3
import io
import math
import os
import subprocess
import sys
import yaml

import config_generator
import data_store

# Safely load file and ensure it is a readable format. If not exit.

def get_config():
    """Return config file as an object"""
    try:
        stream = open('config.yaml', 'r')
        stream = yaml.safe_load(stream)
        return stream
    except:
        print("File failed to open!")

# Get GCM from config file, throw an error and exit if no value set to true
def get_gcm(dictionary):
    """Return value of GCM dictionary set to 'active' else exit"""
    print("WARNING: Finding first instance of 'true' value in GCM config. If multiple instances are found only the first instance will be used!")
    for key, val in dictionary['GCM'].items():
        if val:
            return key
    raise SystemExit("ERROR: Script quitting!\n::No GCM value set to TRUE in the config!")

# Retrieve variables that are run-enabled from the config
def get_active_vars(dictionary):
    """Return a generator containing details of all variables set to 'true'"""
    for key, v in dictionary['Variables'].items():
        if v['run_enabled']:
            # if key is 'tasmin' or 'tasmax' or 'tas':
            #     if not dictionary['Variables']['tasmin']['run_enabled'] or not dictionary['Variables']['tasmax']['run_enabled'] or not dictionary['Variables']['tas']['run_enabled']:
            #         raise SystemExit('ERROR: Script quitting!\n::When running for temperature variables, all of tasmin, tasmax and tas MUST BE ENABLED!')
            yield(key, v['run_enabled'], v['obs_data_type'], v['obs_input_dir'], v['gcm_input_dir'], v['rcp'], v['version'], v['projection_rcp'], v['projection_version'])

# Dynamically chunk years into 10 year periods inclusive of first and last year
def year_split_decade(year_start, year_end):
    """Return two lists where each lists corresponds a start and end year
    args:
        year_start: First year in a sequence
        year_end: End year in a sequence

    return:
        start_years_list: List sequence of starting years
        end_years_list: List sequence of ending years
    """
    decade_qty = ((year_end - year_start ) + 1)/10
    start_years_list = []
    end_years_list = []

    for i in range(math.ceil(decade_qty)):
        if (decade_qty <= 1):
            start_years_list.append(year_start)
            end_years_list.append(year_start + int((10*decade_qty)-1))
        else:
            start_years_list.append(year_start)
            end_years_list.append(year_start + 9)
            year_start +=10
            decade_qty -= 1

    return start_years_list, end_years_list

# Time frames
def get_dict(dict_name, file):
    return file.get(dict_name)

def validate_year_range(dictionary):
    if(dictionary['Time Periods']['start_year'] > dictionary['Time Periods']['end_year']):
        sys.exit('ERROR: Start year is later than end year!')

def set_env_var(var_name, var_data):
    os.environ[var_name] = var_data

def init_env_vars():
    for i, j in env_vars.items():
        set_env_var(i, j)

wdir = '/g/data/er4/jr6311/isimip-bias-correction/isimip-bias-correction/jobs'
sdir = '/g/data/er4/jr6311/isimip-bias-correction/isimip-bias-correction/ISIMIP2b_bc-master_PBS'
env_vars = {'wdir': '/g/data/er4/jr6311/isimip-bias-correction/isimip-bias-correction/jobs',
        'sdir': '/g/data/er4/jr6311/isimip-bias-correction/isimip-bias-correction/ISIMIP2b_bc-master_PBS',
        'tdir': f'{wdir}/tmp',
        'idirGCMdata': f'{wdir}/GCMinput',
        'idirOBSdata': '/g/data/er4/jr6311/isimip-bias-correction/isimip-bias-correction/Obs_data_prep',
        'odirGCMdata': f'{wdir}/GCMoutput',
        'idirGCMsource': '/g/data/er4/jr6311/isimip-bias-correction/isimip-bias-correction',
        'settings_source': f'{sdir}/exports.settings.functions.sh',
        'idirGCMsource': '/g/data/er4/jr6311/isimip-bias-correction/isimip-bias-correction/.idl/idl-startup.pro'
        }

# Retrieve all yielded information from get_active_vars()
active_vars = [data_store.Vars(i[0], i[1], i[2], i[3], i[4], i[5], i[6], i[7], i[8])
                for i in list(get_active_vars(get_config()))]

validate_year_range(get_config())