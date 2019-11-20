from multiprocessing import Pool
import subprocess

import cfg

def exec_cmd(run_string):
    subprocess.run(run_string.split())

globalpath = '/g/data/er4/jr6311/isimip-bias-correction/isimip-bias-correction/ISIMIP2b_bc-master_PBS'
config = cfg.get_config()
years = cfg.get_dict('Time Periods', config)
gcm = cfg.get_gcm(config)
time = 'midday'

def apply_coefficients(var):
    ref_period = f"{years['start_year']}-{years['end_year']}"
    proj_period = f"{years['projection_start']}-{years['projection_end']}"
    exec_cmd(f'{globalpath}/app.coef.sh {var.obs_datatype} {ref_period} {var.name} {var.name} {gcm} {var.rcp} {proj_period} {time}')

if __name__ == '__main__':
    exec_cmd('./init.pbs')
    cfg.init_env_vars()
    with Pool() as p:
        p.map(apply_coefficients, cfg.active_vars)