#!/usr/bin/env python3

import subprocess

var_list = ["tasmax", "tasmin", "tas", "rsds", "pr", "sfcWind"] # Likely to be temporary item. Config may overwrite this.
yst = [19710101, 19810101, 19910101, 20010101]
yen = [19801231, 19901231, 20001231, 20051231]
gcm = "CNRM-CM5" # Will need to be re-referenced via config.
for i in range(len(yst)):
    for var in var_list:
        strspl = f"cdo -f nc4c -z zip_9 -seldate,{yst[i]},{yen[i]} ../{gcm}/{var}_day_{gcm}_historical_r1i1p1_19710101-20051231.nc ../{gcm}/{var}_day_{gcm}_historical_r1i1p1_{yst[i]}-{yen[i]}.nc"
        subprocess.run(strspl.split())