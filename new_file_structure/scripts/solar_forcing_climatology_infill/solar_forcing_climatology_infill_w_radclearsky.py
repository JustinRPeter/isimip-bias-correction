import sys
import os
import csv
import math
import numpy as np
import pickle
import xarray as xr
import bottleneck
import netCDF4
import calendar
import datetime
import time
import logging
import numpy.ma as ma
import pandas as pd
from scipy.spatial import KDTree
from scipy import interpolate, ndimage
from numpy import newaxis
from calendar import monthrange
from awrams.simulation.server import SimulationServer
from awrams.models import awral
from awrams.utils import extents
from awrams.utils import datetools as dt
from awrams.utils import mapping_types as mt
from awrams.utils.nodegraph import nodes,graph
from awrams.utils.io.data_mapping import SplitFileManager
from awrams.utils.metatypes import ObjectDict as o
from os.path import join
from os import getcwd
from awrams.utils.awrams_log import get_module_logger

#Author: Wendy Sharples
#Date: 28.03.2018
#WRM
#Bureau of Meteorology
#Collins St Melbourne, VIC 3001

#Algorithm:
#Read in year_start, year_end, etc
#Load up the 2d landmask
#For each year do
#if < 1990
#forcing_array = climatology array
#else:
#Get the forcing array
#Find the gaps
#Fill the gaps
#write out to file
#get radclearsky radiation from formulation in AWRALv6 doc
#Comments: memory hungry also could optimise but runs fairly fast anyways

#example: python solar_forcing_climatology_infill_w_radclearsky.py 2000 2002 '/g/data/er4/data/CLIMATE' '/g/data/er4/data/CLIMATOLOGY' '/g/data/er4/ws1620/hydro_proj_ens_runs/initial_states_plus_climatology' '/g/data/er4/LIS/test_data/solar_forcing' 'solar_exposure_day' 'climatology_daily_solar_exposure_day' 'solar_exposure_day' 'solar_exposure_day' 'D' True False


#------------------------------------------------------------
# Writes netcdf file to output path sepcified by user
#------------------------------------------------------------

def write_new_ncfile(nc_filename,basedate,epochdate,lat,lon,name,standard_name,long_name,units,dataarray,chunk_time,chunk_lat,chunk_lon,sig_dig,fill_value,logger):

    nco = netCDF4.Dataset(nc_filename,'w',format='NETCDF4',clobber=True)
    dims = np.shape(dataarray)
    numtime = dims[0]
    if (np.size(dims) == 4):
        numtime = dims[1]
        nco.createDimension('variables',4)
        nlat = dims[2]
        nlon = dims[3]
        initialtime = 0
    else:
        nlat = dims[1]
        nlon = dims[2]
        initialtime = (basedate-epochdate).total_seconds()/86400.

    timearray = np.zeros(numtime)
    for i in range(numtime):
        timearray[i] = initialtime + i

    #DEBUG
    #logger.info(dataarray)

    #create dimensions, variables and attributes:
    nco.createDimension('time',None)
    nco.createDimension('latitude',nlat)
    nco.createDimension('longitude',nlon)

    if (np.size(dims) == 3):
        timeo = nco.createVariable('time','i4',('time'),zlib=True)
        timeo.units = 'days since ' + str(epochdate.year) +  '-' + str(epochdate.month).zfill(2) + '-' + str(epochdate.day).zfill(2)
        timeo.standard_name = 'time'
        timeo.long_name = 'time'
        timeo.calendar = 'gregorian'
    else:
        timeo = nco.createVariable('time','i4',('time'),zlib=True)
        timeo.units = 'DJF MAM JJA SON'

    lato = nco.createVariable('latitude','f4',('latitude'),zlib=True)
    lato.units = 'degrees_north'
    lato.standard_name = 'latitude'
    lato.long_name = 'latitude'

    lono = nco.createVariable('longitude','f4',('longitude'),zlib=True)
    lono.units = 'degrees_east'
    lono.standard_name = 'longitude'
    lono.long_name = 'longitude'

    #create container variable for CRS: lon/lat WGS84 datum
    #crso = nco.createVariable('crs','f4')
    #crso.long_name = 'Lon/Lat Coords in WGS84'
    #crso.grid_mapping_name='latitude_longitude'
    #crso.longitude_of_prime_meridian = 0.0
    #crso.semi_major_axis = 6378137.0
    #crso.inverse_flattening = 298.257223563

    #create float variable, with chunking
    if(np.size(dims) == 4):
        var0o = nco.createVariable(name,'f4',('variables', 'time', 'latitude', 'longitude',),zlib=True,complevel=6,chunksizes=[4,chunk_time,chunk_lat,chunk_lon],fill_value=-999.0)
    else:
        var0o = nco.createVariable(name,'f4',('time', 'latitude', 'longitude',),zlib=True,complevel=6,chunksizes=[chunk_time,chunk_lat,chunk_lon],fill_value=-999.0)
    #logger.info(var0o)
    var0o.units = units
    #s0o.scale_factor = 1.0
    #s0o.add_offset = 0.00
    var0o.long_name = long_name
    var0o.standard_name = standard_name
    #s0o.grid_mapping = 'crs'
    #var0o.set_auto_maskandscale(False)

    nco.Conventions='CF-1.6'
    nco.var_name=name

    #write lat,lon
    lato[:]=lat
    lono[:]=lon
    timeo[:]=timearray
    if (np.shape(dims) == 4):
        var0o[:,:,:,:] = dataarray
    else:
        var0o[:,:,:] = dataarray

    nco.close()
    dataarray = None


#-----------------------------------------------------
# Infills the solar forcing array with climatology
#-----------------------------------------------------

def infill_with_climatology(nparray_forcing,clima_array,image,fill_value,num_days,logger):

    lm_3d = np.repeat(image[np.newaxis,:,:],num_days,axis=0)
    gap_list_t,gap_list_lat,gap_list_lon = np.where(np.logical_and(np.logical_or(nparray_forcing==fill_value,np.isnan(nparray_forcing)),lm_3d>=1.0))
    logger.info("Gap list is this long: %d and first gap is " % len(gap_list_t))
    if(len(gap_list_t)>0):
        logger.info("First gap time:%f lat:%f lon:%f" % (gap_list_t[0],gap_list_lat[0],gap_list_lon[0]))
    lm_3d = None
    for i in range(len(gap_list_t)):
        nparray_forcing[gap_list_t[i],gap_list_lat[i],gap_list_lon[i]] = clima_array[gap_list_t[i],gap_list_lat[i],gap_list_lon[i]]

    clima_array = None
    return nparray_forcing


#-----------------------------------------------------
# Gets a climatology array in the same size as the forcing
#-----------------------------------------------------

def get_climatology_array_montly(nparray_clima, num_days, year, numlat, numlon, fill_value,logger):

    temp_sf = np.zeros((num_days,numlat,numlon))
    temp_sf.fill(fill_value)
    days = []

    for i in range(12):
        mon = i + 1
        days.append(calendar.monthrange(year, mon)[1])

    eidx = 0
    sidx = 0
    for i in range(12):
        array = np.reshape(nparray_clima[i,:,:],(numlat,numlon))
        eidx = eidx + days[i]
        logger.info("Month %d, start index: %d, end index: %d" % (i+1,sidx,eidx))
        temp_sf[sidx:eidx,:,:] = np.repeat(array[np.newaxis,:,:], days[i], axis=0)
        sidx = eidx
        array = None

    nparray_clima = None
    return temp_sf

#-----------------------------------------------------
# Gets the radclearsky array
#-----------------------------------------------------

def get_rad_clear_sky_year(self, num_days, year, lat_array, numlat, numlon, fill_value, logger):

    rcskyt = np.zeros((num_days,numlat,numlon))
    rcskyt.fill(fill_value)
    #go thru all lats
    for i, lat in enumerate(lat_array):
        r_lat = rad_clear_sky(self, lat, num_days, logger)
        #logger.info("shape of r_lat is:")
        #logger.info(np.shape(r_lat))
        rcskyt[:,i,:] = np.reshape(np.repeat(r_lat[:,np.newaxis],numlon,axis=1),(num_days, numlon))
        #rcskyt[:,i,:] = r_lat.repeat(num_lon).reshape(num_days, num_lon)
    return rcskyt

#-----------------------------------------------------
# Gets the radclearsky at a latitude
#-----------------------------------------------------

def solar_variables(self, lat, delta, logger):

    phi = lat * math.pi / 1.8e2
    self.solar_vars[lat] = (phi, np.arccos(-np.tan(phi)*np.tan(delta)))
    return self.solar_vars[lat]


def rad_clear_sky(self, lat, num_days, logger):

    q0 = 2 * math.pi * np.arange(num_days) / 365.
    delta = 0.006918 - 0.399912 * np.cos(q0) + 0.070257 * np.sin(q0) -0.006758 * np.cos(2 * q0) + 0.000907 * np.sin(2 * q0) -0.002697 * np.cos(3 * q0) + 0.00148 * np.sin(3 * q0)
    sin_delta = np.sin(delta)
    cos_delta = np.cos(delta)
    phi,pi = solar_variables(self, lat, delta, logger)
    rcs_dist = 1+0.033*np.cos(2*math.pi*(np.arange(num_days)-2)/365.0)
    whole_year = 94.5*rcs_dist*(pi*sin_delta*np.sin(phi)+cos_delta*np.cos(phi)*np.sin(pi))/math.pi
    return whole_year

#-----------------------------------------------------
# Infills solar forcing or replaces solar forcing
# by climatology depending on whether pre or post
# 1990 and writes to file
#-----------------------------------------------------

def infill_solar_forcing_and_write_to_file(self, forcing_filename, climatology_filename, frequency, year, extent, in_dir, out_dir, climatology_dir, states_dir, forcing_var_name, climatology_var_name, overwrite, basedate, epochdate, chunk_time, chunk_lat, chunk_lon, sig_dig, fill_value, image, logger):

    bbox = extents.get_default_extent()
    numlat = bbox.shape[0]
    numlon = bbox.shape[1]
    num_days = 365
    if (calendar.isleap(year)):
        num_days = 366

    new_forcing_file = out_dir + '/' + forcing_filename + '/' + forcing_filename + '_' + str(year) + '.nc'

    #Check for pre-existing data
    if (os.path.exists(new_forcing_file)):
        if(overwrite == True):
            try:
                os.remove(new_forcing_file)
            except:
                logger.info("Overwrite is true and cannot remove this forcing file check you have permissions")
                sys.exit()
        else:
            logger.info("Overwrite is false so skipping this year as there is a pre-existing forcing file")
            return
    else:
        if not (os.path.exists(out_dir)):
            os.mkdir(out_dir)
        if not (os.path.exists(out_dir + '/' + forcing_var_name)):
            os.mkdir(out_dir + '/' + forcing_var_name)

    climatology_file = str(climatology_dir) + '/' + climatology_filename + '.nc'
    try:
        climatologydata = xr.open_dataset(climatology_file)
        #, chunks={'time': chunk_time, 'latitude': chunk_lat, 'longitude': chunk_lon})
    except:
        logger.info("climatology file:%s not found or something is wrong with it. Please check." % climatology_file)
        sys.exit()
    #logger.info(forcingdata.keys())
    #The easiest way to convert an xarray data structure from lazy dask arrays into eager,
    #in-memory numpy arrays is to use the load() method:
    climatologydata.load()

    #get climatology array:
    nparray_clima = np.asarray(climatologydata.__getitem__(climatology_var_name))
    self.lats = np.asarray(climatologydata.__getitem__('latitude'))
    self.lons = np.asarray(climatologydata.__getitem__('longitude'))

    if (frequency == 'M'):
        #convert monthly climatology array into a daily array:
        #insert extra day for leap year
        nparray_clima = np.reshape(nparray_clima,(12,numlat,numlon))
        climatologydata = None
        clima_array = get_climatology_array(nparray_clima, num_days, year, numlat, numlon, fill_value, logger)
    else:
        nparray_clima = np.reshape(nparray_clima,(366,numlat,numlon))
        clima_array = nparray_clima
        climatologydata = None

    nparray_clima = None
    #if year < 1990
    if(year < 1990):
        resulting_array = clima_array
        name = forcing_var_name
        standard_name = "integral_of_surface_downwelling_shortwave_flux_in_air_wrt_time"
        long_name = "Daily global solar radiation exposure"
        units = "MJ m^-2"
    else:
        #load up forcing
        forcing_file = str(in_dir) + '/' + forcing_filename + '/' + forcing_filename + '_' + str(year) + '.nc'
        try:
           forcingdata = xr.open_dataset(forcing_file, chunks={'time': chunk_time, 'latitude': chunk_lat, 'longitude': chunk_lon})
        except:
            logger.info("forcing file:%s not found" % forcing_file)
            sys.exit()
        #logger.info(forcingdata.keys())
        #The easiest way to convert an xarray data structure from lazy dask arrays into eager,
        #in-memory numpy arrays is to use the load() method:
        forcingdata.load()
        name = forcingdata[forcing_var_name].attrs['name']
        standard_name = forcingdata[forcing_var_name].attrs['standard_name']
        long_name = forcingdata[forcing_var_name].attrs['long_name']
        units = forcingdata[forcing_var_name].attrs['units']
        #get climatology array:
        nparray_forcing = np.asarray(forcingdata.__getitem__(forcing_var_name))
        resulting_array = infill_with_climatology(nparray_forcing,clima_array,image,fill_value,num_days,logger)

    nparray_forcing = None
    clima_array = None
    #logger.info(resulting_array)
    #write to file:

    write_new_ncfile(new_forcing_file,basedate,epochdate,self.lats,self.lons,name,standard_name,long_name,units,resulting_array,chunk_time,chunk_lat,chunk_lon,sig_dig,fill_value,logger)
    resulting_array = None

#-----------------------------------------------------
# Calculates clear sky radiation and writes to file
#-----------------------------------------------------

def create_rad_clear_sky_and_write_to_file(self, year, extent, out_dir, overwrite, basedate, epochdate, chunk_time, chunk_lat, chunk_lon, sig_dig, fill_value, logger):

    bbox = extents.get_default_extent()
    numlat = bbox.shape[0]
    numlon = bbox.shape[1]
    num_days = 365
    if (calendar.isleap(year)):
        num_days = 366

    forcing_filename = "radcsky_day"
    forcing_var_name = "radcskyt"

    new_forcing_file = out_dir + '/' + forcing_filename + '/' + forcing_filename + '_' + str(year) + '.nc'

    #Check for pre-existing data
    if (os.path.exists(new_forcing_file)):
        if(overwrite == True):
            try:
                os.remove(new_forcing_file)
            except:
                logger.info("Overwrite is true and cannot remove this forcing file check you have permissions")
                sys.exit()
        else:
            logger.info("Overwrite is false so skipping this year as there is a pre-existing forcing file")
            return
    else:
        if not (os.path.exists(out_dir)):
            os.mkdir(out_dir)
        if not (os.path.exists(out_dir + '/' + forcing_filename)):
            os.mkdir(out_dir + '/' + forcing_filename)

    resulting_array = get_rad_clear_sky_year(self, num_days, year, self.lats, numlat, numlon, fill_value, logger)
    name = forcing_var_name
    standard_name = "downward_shortwave_clear_sky_radiation"
    long_name = "Daily downward short wave radiation for a clear sky"
    units = "MJ m^-2"

    write_new_ncfile(new_forcing_file,basedate,epochdate,self.lats,self.lons,name,standard_name,long_name,units,resulting_array,chunk_time,chunk_lat,chunk_lon,sig_dig,fill_value,logger)
    resulting_array = None


#----------------------------------------------------------
# Creating the solarinfill class and relevant functionality:
#----------------------------------------------------------

class solar_infill:
    """
    Solar forcing infill class to infill solar forcing with a climatology file.
    Assumptions and caveats: Infills all years prior to 1990 with monthly or daily climatology
    Assumes forcing var name is the same as the file name
    """
    def __init__(self, year_start, year_end, forcing_dir, climatology_dir, states_dir, output_dir, forcing_file, climatology_file, forcing_var, climatology_var, frequency, rad_clear_sky, overwrite):
        """
        Reads in the year start and end, solar forcing directory, directory where the climatology file is stored, the output dir, the climatology file name,
        the solar forcing var name and the climatology var name and whether the user wants to overwrite pre-existing infilled solar forcing
        :return:
        """

        self.year_start = year_start
        self.year_end = year_end
        self.forcing_dir = forcing_dir
        self.climatology_dir = climatology_dir
        self.states_dir = states_dir
        self.output_dir = output_dir
        self.forcing_file = forcing_file
        self.climatology_file = climatology_file
        self.forcing_var = forcing_var
        self.climatology_var = climatology_var
        self.frequency = frequency
        self.overwrite = False
        self.rad_clear_sky = False
        if (rad_clear_sky == 'True' or rad_clear_sky == 'true'):
            self.rad_clear_sky = True
        if (overwrite == 'True' or overwrite == 'true'):
            self.overwrite = True
        #prelim check- could be more thorough
        self.chunk_time = 32
        self.chunk_lat = 32
        self.chunk_lon = 32
        self.sig_dig = 2
        self.fill_value = -999.0
        self.epoch_year_start = 1900
        self.epoch_month_start = 1
        self.epoch_day_start = 1
        self.epochdate = dt.datetime(self.epoch_year_start,self.epoch_month_start,self.epoch_day_start,0,0,0)
        self.solar_vars = {}
        self.lats = np.empty((20,20,20))
        self.lons = np.empty((20,20,20))


    def run_solar_infill(self):
        """
        Generates solar forcing infilled with solar climatology.
        Everything prior to 1990 is just climatology (constant over the year)
        """

        full_extent = extents.get_default_extent()
        numlat = full_extent.shape[0]
        numlon = full_extent.shape[1]

        nlogger = logging.getLogger('NULL')
        nlogger.parent.handlers

        logger = get_module_logger("ensemble")

        #load up AWRA landmask file
        lm_file = self.states_dir + '/solar_exposure_day_landmask.nc'
        try:
            lmdata = xr.open_dataset(lm_file, chunks={'time': self.chunk_time, 'latitude': self.chunk_lat, 'longitude': self.chunk_lon})
        except:
            logger.info("landmask file:%s not found" % lm_file)
            sys.exit()
        #The easiest way to convert an xarray data structure from lazy dask arrays into eager,
        #in-memory numpy arrays is to use the load() method:
        lmdata.load()
        #get landmask array:
        image = np.asarray(lmdata.__getitem__('LANDMASK'))
        image = np.reshape(image,(numlat,numlon))
        lmdata = None

        for year in range(int(self.year_start),(int(self.year_end) + 1)):
            #scale forcing and write to netcdf
            basedate = dt.datetime(year,1,1,0,0,0)
            logger.info("Starting to infill solar forcing and writing this out to file for year %d" % year)
            #commented out for debugging purposes- want to use old forcing
            infill_solar_forcing_and_write_to_file(self, self.forcing_file, self.climatology_file, self.frequency, year, full_extent, self.forcing_dir, self.output_dir, self.climatology_dir, self.states_dir, self.forcing_var, self.climatology_var, self.overwrite, basedate, self.epochdate, self.chunk_time, self.chunk_lat, self.chunk_lon, self.sig_dig, self.fill_value, image, logger)
            if(self.rad_clear_sky == True):
                logger.info("Starting to write out clear sky downward radiation for year %d" % year)
                create_rad_clear_sky_and_write_to_file(self, year, full_extent, self.output_dir, self.overwrite, basedate, self.epochdate, self.chunk_time, self.chunk_lat, self.chunk_lon, self.sig_dig, self.fill_value, logger)
            logger.info("Finshed writing forcing")

if __name__ == '__main__':

    runner = solar_infill(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6], sys.argv[7], sys.argv[8], sys.argv[9], sys.argv[10], sys.argv[11], sys.argv[12], sys.argv[13])

    runner.run_solar_infill()

    def __init__(self, year_start, year_end, forcing_dir, climatology_dir, states_dir, output_dir,
    forcing_file, climatology_file, forcing_var, climatology_var, frequency, rad_clear_sky, overwrite):

/g/data/er4/LIS/test_data/solar_forcing_climatology_infill_w_radclearsky.py
### year_start = 1970
### year_end = 2017
forcing_dir = '/g/data/er4/data/CLIMATE'
climatology_dir = '/g/data/er4/data/CLIMATOLOGY'
states_dir = '/g/data/er4/ws1620/hydro_proj_ens_runs/initial_states_plus_climatology'
### output_dir = '/g/data/er4/ISIMIP/AWAP/solar_forcing_climatology_infill'
forcing_file = 'solar_exposure_day'
cilmatology_file = 'climatology_daily_solar_exposure_day'
forcing_var = 'solar_exposure_day'
climatology_var = 'solar_exposure_day'
frequency = 'D'
rad_clear_sky = True
### overwrite = True