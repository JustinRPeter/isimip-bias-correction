import xarray as xr

def remap_tas():

    #THIS IS OPENS A DASK ARRAY!
    tasmin_ds = xr.open_dataset('/g/data/er4/jr6311/isimip-bias-correction/isimip-bias-correction/Obs_data_prep/tasmin_day_AWAP_19760101-20051231.nc4', chunks={'time': 300})
    tasmax_ds = xr.open_dataset('/g/data/er4/jr6311/isimip-bias-correction/isimip-bias-correction/Obs_data_prep/tasmax_day_AWAP_19760101-20051231.nc4', chunks={'time': 300})
    
    tas_ds = tasmin_ds
    tas_ds = tas_ds.rename({'tasmin': 'tas'})

    # Update values
    tas_array = 0.5*tasmax_ds['tasmax'] + 0.5*tasmin_ds['tasmin']

    tas_ds['tas'] = tas_array
#     Close datasets to allow saving
    tasmin_ds.close()
    tasmax_ds.close()

    print('Outputting now...')
    # Output datasets
    tas_ds.to_netcdf('/g/data/er4/jr6311/isimip-bias-correction/isimip-bias-correction/Obs_data_prep/tas_50_50_weighting.nc4', unlimited_dims=['time'])

if __name__ == "__main__":
    remap_tas()
