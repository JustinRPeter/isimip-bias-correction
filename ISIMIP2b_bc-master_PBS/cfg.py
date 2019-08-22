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
    try:
        stream = open('config.yaml', 'r')
        stream = yaml.safe_load(stream)
        return stream
    except:
        print("File failed to open!")

# Get GCM from config file, throw an error and exit if no value set to true
def get_gcm(dictionary):
    print("WARNING: Finding first instance of 'true' value in GCM config. If multiple instances are found only the first instance will be used!")
    for key, val in dictionary['GCM'].items():
        if val:
            return key
    raise SystemExit("ERROR: Script quitting!\n::No GCM value set to TRUE in the config!")

# Retrieve variables that are run-enabled from the config
def get_active_vars(dictionary):
     for key, v in dictionary['Variables'].items():
            if v['run_enabled']:
                yield(key, v['run_enabled'], v['obs_input_dir'],
                        v['gcm_input_dir'], v['rcp'], v['version'],
                        v['projection_rcp'], v['projection_version'])

# Dyanmically chunk years into 10 year periods inclusive of firs and last year
def year_split_decade(year_start, year_end):
    decade_qty = ((year_end - year_start ) + 1)/10
    start_years_list = []
    end_years_list = []

    for i in range(ceil(decade_qty)):
        if (decade_qty <= 1):
            start_years_list.append(year_start)
            end_years_list.append(year_start + int((10*decade_qty)-1))
        else:
            start_years_list.append(year_start)
            end_years_list.append(year_start + 9)
            year_start +=10
            decade_qty -= 1
    return start_years_list, end_years_list

def validate_year_range(dictionary):
    if(dictionary['start_year'] > dictionary['end_year']):
        sys.exit('ERROR: Start year is later than end year!')

# Time frames
def get_dict(dict_name, file):
    return file.get(dict_name)

# Retrieve all yielded information from get_active_vars()
active_vars = [data_store.Vars(i[0], i[1], i[2], i[3], i[4], i[5], i[6], i[7])
                for i in list(get_active_vars(get_config()))]

validate_year_range(get_config())