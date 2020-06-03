import argparse
import numpy as np
import xarray as xr


def get_args():
    parser = argparse.ArgumentParser(description='Supply arguments to correct temperature data')
    parser.add_argument('tasmin_file', help='Tasmin file with full path')
    parser.add_argument('tasmax_file', help='Tasmax file with full path')
    parser.add_argument('gcm', help='Provide the GCM of the dataset')
    parser.add_argument('rcp', help='Provide the rcp of the dataset')
    parser.add_argument('output_path', help='Provide a filepath for outputs')

    parser.add_argument('--convert_to_kelvin', action='store_true',
        help='Treat input as degress and convert to kelvin')

    args = parser.parse_args()
    return args


def get_year(rcp):
    if rcp == 'historical':
        return '19600101-20051231'
    elif rcp == 'rcp45' or rcp == 'rcp85' :
        return '20060101-20991231'
    else:
        raise NameError(rcp)


def remap_tas(min_file, max_file, gcm, rcp, year_string, output_path, convert_to_kelvin):
    # Open datasets and apply corrected arrays
    #THIS IS OPENS A DASK ARRAY!
    tasmin_ds = xr.open_dataset(min_file)
    tasmax_ds = xr.open_dataset(max_file)
    
    tasmin_ds_fix = xr.ufuncs.fmin(tasmin_ds.tasmin, tasmax_ds.tasmax)
    tasmax_ds_fix = xr.ufuncs.fmax(tasmin_ds.tasmin, tasmax_ds.tasmax)
    
    # Maintain encoding/attributes
    tasmin_ds_fix.attrs = tasmin_ds.tasmin.attrs 
    tasmin_ds_fix.encoding = tasmin_ds.tasmin.encoding
    tasmin_ds_fix.attrs = tasmin_ds.tasmin.attrs 
    tasmin_ds_fix.encoding = tasmin_ds.tasmin.encoding

    tasmin_ds['tasmin'] = tasmin_ds_fix
    tasmax_ds['tasmax'] = tasmax_ds_fix
    
    # Adjust attributes     
    tasmax_ds.tasmax.attrs['units'], tasmin_ds.tasmin.attrs['units'] = 'K'*2
    tas_ds = tasmin_ds
    tas_ds = tas_ds.rename({'tasmin': 'tas'})
    
    # Update values
    if convert_to_kelvin:
        tasmin_ds['tasmin'] += 273.15
        tasmax_ds['tasmax'] += 273.15
    tas_ds['tas'] = 0.5*tasmax_ds['tasmax'] + 0.5*tasmin_ds['tasmin']

    # Close datasets to allow saving
    tasmin_ds.close()
    tasmax_ds.close()

    print('Outputting now...')
    # Output datasets
    tasmin_ds.to_netcdf(f'{output_path}/tasmin_day_{gcm}_{rcp}_r1i1p1_{year_string}.nc', unlimited_dims=['time'])
    tasmax_ds.to_netcdf(f'{output_path}/tasmax_day_{gcm}_{rcp}_r1i1p1_{year_string}.nc', unlimited_dims=['time'])
    tas_ds.to_netcdf(f'{output_path}/tas_day_{gcm}_{rcp}_r1i1p1_{year_string}.nc', unlimited_dims=['time'])


if __name__ == "__main__":
    args = get_args()
    year = get_year(args.rcp)

    remap_tas(args.tasmin_file, args.tasmax_file, args.gcm, args.rcp, year, args.output_path, args.convert_to_kelvin)
    print('Operation Complete')