#!/usr/bin/env python3
import test
import yaml
import io
import sys
import os
import subprocess

# Safely load file and ensure it is a readable format. If not exit.
Stream = None
try:
    stream = open('config.yaml', 'r')
    stream = yaml.safe_load(stream)
except:
    print("File failed to open!")

# Get GCM from config file, throw an error and exit if no value set to true
def get_gcm():
    print("WARNING: Finding first instance of 'true' value in GCM config. If multiple instances are found only the first instance will be used!")
    for key, val in stream.items():
        if (key == "GCM"):
            for key2, val2 in val.items():
                if(str(val2).lower() == "true"):
                    return key2
    raise SystemExit("ERROR: Script quitting!\n::No GCM value set to TRUE in the config!")

# Get variables throw an error if no value has been selected
variables = ['tasmin', 'tasmax', 'tas', 'rsds', 'pr', 'sfcWind']
def get_variables():
    for i in list(variables):
        if(str(stream[i]["run_enabled"]).lower() == 'false'):
            variables.remove(i)
    if not variables:
        raise SystemExit("ERROR: Script quitting!\n::'run_enabled' must be set to TRUE for at least one variable!")

# Directory Paths
input_dir = stream["Directory Paths"]["main_working_dir"]
#output_dir = stream["Directory Paths"]["output_dir"]

# GCM & Variables
gcm = get_gcm()
get_variables()

tasmin_input_dir = stream["tasmin"]["obs_input_dir"]
tasmin_input_file = tasmin_input_dir.split("/")[-1]

tasmax_input_dir = stream["tasmax"]["obs_input_dir"]
tasmax_input_file = tasmax_input_dir.split("/")[-1]

tas_input_dir = stream["tas"]["obs_input_dir"]
tas_input_file = tas_input_dir.split("/")[-1]

rsds_input_dir = stream["rsds"]["obs_input_dir"]
rsds_input_file = rsds_input_dir.split("/")[-1]

pr_input_dir = stream["pr"]["obs_input_dir"]
pr_input_file = pr_input_dir.split("/")[-1]

sfcWind_obs_input_dir = stream["sfcWind"]["obs_input_dir"]
sfcWind_obs_input_file = sfcWind_input_dir.split("/")[-1]

# Time frames
year_start = stream["Time Periods"]["start_year"]
year_end = stream["Time Periods"]["end_year"]
projection_start = stream["Time Periods"]["projection_start"]
projection_end = stream["Time Periods"]["projection_end"]



#########################################
#
# CODE EXPERIMENTATION to increase overall
# robustness, error handling & odd edge cases
#
#########################################
#stream = list(stream.items())[1]
#for i in stream:
    #if (str(stream[num].get(i)).lower() == "false"):
    #    print(stream[num].keys())
    #    print(i)

# def populate_variables():
#     stream_list = list(stream.keys())
#     for num in range(len(stream_list)):
#         print(num)
#         print(stream_list[num].value())
#         # for i in stream_list[num]:
#         #     print(i)
#         #     if (str(stream_list[num].get(i)).lower() == "false"):
#         #         print(stream_list[num].keys())
#         #         print(i)

#populate_variables()
# print(input_dir)

# list(mydict.keys())[list(mydict.values()).index(16)])



#for i, num in stream.items():
#        print(num)
#    for j, value in num.items():
#        print(j)
#        print(value)

# i is the main listings, GCM, direct etc
# num is each of the sub dictionaries..


# variables = (rsds, pr, sfcWind, tas, tasmin, tasmax)
# for variable in variables:
#     result = variable()
#     if result:
#         return result