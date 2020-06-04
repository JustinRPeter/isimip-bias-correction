#!/bin/bash

# Usage
# Set the following to the desired settings, then run the script:
# - variables, e.g. (pr rsds sfcWind tas tasmin tasmax)
# - models, e.g. (ACCESS1-0 CNRM-CM5 CCAM-r3355-GFDL-ESM2M)
# - pbs_job_storage_flags
# - isimip_base_path
#
# rcp is effectively fixed at historical, as this job interpolates the
# historical decade files created by the data_prep2 stage.
# Intended to be run from the folder that contains this script.

variables=(pr tas tasmin)
models=(ACCESS1-0)
pbs_job_storage_flags=gdata/er4+scratch/er4
isimip_base_path=/g/data/er4/jr6311/isimip-bias-correction/isimip-bias-correction



pbs_jobs_folder=created_interp_jobs
pbs_job_template_file=interp_hist_job.pbs_template

mkdir -p ${pbs_jobs_folder}

# Generate and run all jobs
for var in ${variables[@]}; do
    for model in ${models[@]}; do
        job_file=${pbs_jobs_folder}/interp_hist_${model}_${var}.pbs

        echo "Creating Job ${job_file}"
        cp ${pbs_job_template_file} ${job_file}
        sed -i "s|xxVARxx|${var}|g" ${job_file}
        sed -i "s|xxMODELxx|${model}|g" ${job_file}
        sed -i "s|xxPBS_JOB_STORAGE_FLAGSxx|${pbs_job_storage_flags}|g" ${job_file}
        sed -i "s|xxISIMIP_BASE_DIRxx|${isimip_base_path}|g" ${job_file}

        echo "Submitting Job ${job_file}"
        qsub ${job_file}
        wait
    done
done

echo "Done"