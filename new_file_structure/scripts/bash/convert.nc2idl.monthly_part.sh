#!/bin/bash

#WKS CHANGED:
queue=express

# process input parameters
idir=$1
odir=$2
ifile=$3  # without suffix
ofile=$4  # without suffix
ncpus=$5



# split multi-year ifile into months
echo ... splitting $idir/$ifile.$ncs into months ...
mfile=${ifile}_
cdo -f nc splitmon $idir/$ifile.$ncs $odir/$mfile
for month in $(seq -w 1 12); do exit_if_nt $idir/$ifile.$ncs $odir/$mfile$month.$ncs; done
echo ... done ...

