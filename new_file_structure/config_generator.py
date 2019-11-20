#!/usr/bin/env python3
import yaml
import io
from flatten_dict import flatten

def default_var_config():
    """Return a default dictionary structure"""
    return {'run_enabled' : False,
            'obs_data_type' : "AWAP",
            'obs_input_dir': "/g/data/er4/data/CLIMATE",
            'gcm_input_dir': "/g/data/al33",
            'rcp': "historical",
            'version': "latest",
            'projection_rcp': "rcp85",
            'projection_version': "latest"}

default_vars = ['tasmin', 'tasmax', 'tas', 'rsds', 'pr', 'sfcWind']
default_var_dict = {var: default_var_config() for var in default_vars}

data = {'Directory Paths':
            {
            'main_working_dir': "/g/data"},
        'Time Periods':
            {'start_year': 1976,
            'end_year': 2005,
            'projection_start': 2006,
            'projection_end': 2099},
        'GCM':
            {'CNRM-CM5': False,
            'MIROC5': False,
            'GFDL-ESM2M': False,
            'ACCESS1-0': False},
        'Variables':{}
        }

data['Variables'].update(default_var_dict)

# Write YAML file
def generate_config():
    """Create a YAML named config.yaml and populate with default dictionary"""
    outfile = io.open('config.yaml', 'w')
    yaml.dump(data, outfile, sort_keys=False)

# Read YAML file
def config_exists():
    """Check if config exists and return true/false dependent on result"""
    try:
        stream = open('config.yaml', 'r')
        return True
    except:
        return False

# Validate all major Keys are in config
if __name__ == "__main__":
    # Check for config existence
    if (config_exists() == True):
        print("Config already exists!")
    else:
        generate_config()
        print("Config Generated!")

# List to iterate over file and ensure all keys are there. Small validation check.
# keyList = ['Directory Paths','main_working_dir','Time Periods','start_date','Time Periods','end_date','Time Periods','projection_start','Time Periods',
#         'projection_end','GCM','CNRM-CM5','GCM','MIROC5','GCM','GFDL-ESM2M','GCM','ACCESS1-0','tasmin','run_enabled','tasmin','input_dir','tasmin','input_filename',
#         'tasmax','run_enabled','tasmax','input_dir','tasmax','input_filename','tas','run_enabled','tas','input_dir','tas','input_filename','rsds','run_enabled','rsds',
#         'input_dir','rsds','input_filename','pr','run_enabled','pr','input_dir','pr','input_filename','sfcWind','run_enabled','sfcWind','input_dir','sfcWind','input_filename']