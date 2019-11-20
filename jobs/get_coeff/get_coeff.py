from multiprocessing import Pool
import subprocess

import cfg

def exec_cmd(run_string):
    subprocess.run(run_string.split())

globalpath = '/g/data/er4/jr6311/isimip-bias-correction/isimip-bias-correction/ISIMIP2b_bc-master_PBS'
config = cfg.get_config()
years = cfg.get_dict('Time Periods', config)
gcm = cfg.get_gcm(config)

def get_coeff_a(var):
    period = f"{years['start_year']}-{years['end_year']}"
    exec_cmd(f'{globalpath}/get.coef_00.sh {var.obs_datatype} {var.name} {period} {var.name}')

def get_coeff_b(var):
    period = f"{years['start_year']}-{years['end_year']}"
    exec_cmd(f'{globalpath}/get.coef_01.sh {var.obs_datatype} {period} {var.name} {var.name} {gcm}')

def get_coeff_c(var):
    period = f"{years['start_year']}-{years['end_year']}"
    exec_cmd(f'{globalpath}/get.coef_01.sh {var.obs_datatype} {period} {var.name} {var.name} {gcm} coeff')

def get_coeff_d(var):
    period = f"{years['start_year']}-{years['end_year']}"
    exec_cmd(f'{globalpath}/get.coef_01.sh {var.obs_datatype} {period} {var.name} {var.name} {gcm} coeff check')

if __name__ == '__main__':
    exec_cmd('./init.pbs')
    cfg.init_env_vars()
    with Pool() as p:
        p.map(get_coeff_a, cfg.active_vars)
        p.map(get_coeff_b, cfg.active_vars)
        p.map(get_coeff_c, cfg.active_vars)
        p.map(get_coeff_d, cfg.active_vars)
