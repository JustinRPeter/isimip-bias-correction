#!/bin/bash

# Usage
# Set the following to the desired settings, then run the script:
# - variables, e.g. (pr rsds sfcWind tas tasmin tasmax)
# - models, e.g. (ACCESS1-0 CNRM-CM5 CCAM-r3355-GFDL-ESM2M)
# - rcps, e.g. (historical rcp45 rcp85)
# - pbs_job_storage_flags
# - isimip_base_path
#
# Intended to be run from the folder that contains this script.

variables=(pr tas tasmin)
models=(ACCESS1-0)
rcps=(historical)
pbs_job_storage_flags=gdata/er4+scratch/er4
isimip_base_path=/g/data/er4/jr6311/isimip-bias-correction/isimip-bias-correction



pbs_jobs_folder=created_interp_jobs
pbs_job_template_file=interp_job.pbs_template

mkdir -p ${pbs_jobs_folder}

# Generate and run all jobs
for var in ${variables[@]}; do
    for model in ${models[@]}; do
        for rcp in ${rcps[@]}; do
            job_file=${pbs_jobs_folder}/interp_${model}_${var}_${rcp}.pbs

            echo "Creating Job ${job_file}"
            cp ${pbs_job_template_file} ${job_file}
            sed -i "s|xxVARxx|${var}|g" ${job_file}
            sed -i "s|xxMODELxx|${model}|g" ${job_file}
            sed -i "s|xxRCPxx|${rcp}|g" ${job_file}
            sed -i "s|xxPBS_JOB_STORAGE_FLAGSxx|${pbs_job_storage_flags}|g" ${job_file}
            sed -i "s|xxISIMIP_BASE_DIRxx|${isimip_base_path}|g" ${job_file}

            echo "Submitting Job ${job_file}"
            qsub ${job_file}
            wait
        done
    done
done

echo "Done"