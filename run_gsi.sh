#PBS -N tutorial-gsi
#PBS -m abe 
#PBS -l walltime=03:00:00 
#PBS -l nodes=1:ppn=24 
#PBS -j oe 

BASEDIR=/home/paola.corrales/datosmunin3/tutorial_gsi		# Path to the tutorial folder
GSIDIR=/home/paola.corrales/datosmunin3/comGSIv3.7_EnKFv1.3	# Path to where the GSI/EnKF code is compiled 
FECHA_INI='11:00:00 2018-11-22'					# Init time (analisis tieme - $ANALISIS)
ANALISIS=3600							# Assimmilation cycle in seconds
OBSWIN=1							# Assimilation window in hours
N_MEMBERS=10							# Ensamble size
E_WE=200                                                        # West-East grid points
E_SN=240                                                        # South-North grid points
E_BT=37								# Vertical levels


export OMP_NUM_THREADS=1
GSIPROC=10

set-x

#####################################################
# case set up 
#####################################################
  ANAL_TIME=$(date -d "$FECHA_INI+ $ANALISIS seconds" +"%Y%m%d%H%M%S")
  JOB_DIR=$BASEDIR/
  RUN_NAME=GSI
  OBS_ROOT=$BASEDIR/OBS
  BK_ROOT=$BASEDIR/GUESS/$(date -d "$FECHA_INI + $ANALISIS seconds" +"%Y%m%d%H%M%S")
  GSI_ROOT=$GSIDIR
  CRTM_ROOT=$GSI_ROOT/libsrc/crtm

  ENS_ROOT=the_directory_where_ensemble_backgrounds_are_located
      #ENS_ROOT is not required if not running hybrid EnVAR 
  YYYYMMDD=`echo $ANAL_TIME | cut -c1-8`
  HH=`echo $ANAL_TIME | cut -c9-10`
  MM=`echo $ANAL_TIME | cut -c11-12`
  SS=`echo $ANAL_TIME | cut -c13-14`
  GSI_EXE=${GSI_ROOT}/build/bin/gsi.x  #assume you have a copy of gsi.x here
  WORK_ROOT=${JOB_DIR}/${RUN_NAME}
  FIX_ROOT=${GSI_ROOT}/fix
  GSI_NAMELIST=${BASEDIR}/namelists/comgsi_namelist.sh
  PREPBUFR=${OBS_ROOT}/cimap.${YYYYMMDD}.t${HH}z.0${OBSWIN}h.prepbufr.nqc
  BK_FILE=${BK_ROOT}/00/wrfarw.ensmean
#
#------------------------------------------------
# bk_core= which WRF core is used as background (NMM or ARW or NMMB)
# bkcv_option= which background error covariance and parameter will be used 
#              (GLOBAL or NAM)
# if_clean = clean  : delete temperal files in working directory (default)
#            no     : leave running directory as is (this is for debug only)
# if_observer = Yes  : only used as observation operater for enkf
# if_hybrid   = Yes  : Run GSI as 3D/4D EnVar
# if_4DEnVar  = Yes  : Run GSI as 4D EnVar
# if_nemsio = Yes    : The GFS background files are in NEMSIO format
# if_oneob  = Yes    : Do single observation test
  if_hybrid=No     # Yes, or, No -- case sensitive !
  if_4DEnVar=No    # Yes, or, No -- case sensitive (set if_hybrid=Yes first)!
  if_observer=Yes   # Yes, or, No -- case sensitive !
  if_nemsio=No     # Yes, or, No -- case sensitive !
  if_oneob=No      # Yes, or, No -- case sensitive !

  bk_core=ARW
  bkcv_option=GLOBAL
  if_clean=clean
#
# setup for GSI 3D/4D EnVar hybrid
  if [ ${if_hybrid} = Yes ] ; then
    PDYa=`echo $ANAL_TIME | cut -c1-8`
    cyca=`echo $ANAL_TIME | cut -c9-10`
    gdate=`date -u -d "$PDYa $cyca -6 hour" +%Y%m%d%H` #guess date is 6hr ago
    gHH=`echo $gdate |cut -c9-10`
    datem1=`date -u -d "$PDYa $cyca -1 hour" +%Y-%m-%d_%H:%M:%S` #1hr ago
    datep1=`date -u -d "$PDYa $cyca 1 hour"  +%Y-%m-%d_%H:%M:%S`  #1hr later
    if [ ${if_nemsio} = Yes ]; then
      if_gfs_nemsio='.true.'
      ENSEMBLE_FILE_mem=${ENS_ROOT}/gdas.t${gHH}z.atmf006s.mem
    else
      if_gfs_nemsio='.false.'
      ENSEMBLE_FILE_mem=${ENS_ROOT}/sfg_${gdate}_fhr06s_mem
    fi

    if [ ${if_4DEnVar} = Yes ] ; then
      BK_FILE_P1=${BK_ROOT}/wrfout_d01_${datep1}
      BK_FILE_M1=${BK_ROOT}/wrfout_d01_${datem1}

      if [ ${if_nemsio} = Yes ]; then
        ENSEMBLE_FILE_mem_p1=${ENS_ROOT}/gdas.t${gHH}z.atmf009s.mem
        ENSEMBLE_FILE_mem_m1=${ENS_ROOT}/gdas.t${gHH}z.atmf003s.mem
      else
        ENSEMBLE_FILE_mem_p1=${ENS_ROOT}/sfg_${gdate}_fhr09s_mem
        ENSEMBLE_FILE_mem_m1=${ENS_ROOT}/sfg_${gdate}_fhr03s_mem
      fi
    fi
  fi

# The following two only apply when if_observer = Yes, i.e. run observation operator for EnKF
# no_member     number of ensemble members
# BK_FILE_mem   path and base for ensemble members
  no_member=${N_MEMBERS}
# BK_FILE_mem=${BK_ROOT}/wrfarw.mem
  nlon=$((${E_WE}-1))
  nlat=$((${E_SN}-1))
  nsig=${E_BT}
  half_window=0.5
#
#
#####################################################
# Users should NOT make changes after this point
#####################################################
#
BYTE_ORDER=Big_Endian
# BYTE_ORDER=Little_Endian

##################################################################################
# Check GSI needed environment variables are defined and exist
#
 
# Make sure ANAL_TIME is defined and in the correct format
if [ ! "${ANAL_TIME}" ]; then
  echo "ERROR: \$ANAL_TIME is not defined!"
  exit 1
fi

# Make sure WORK_ROOT is defined and exists
if [ ! "${WORK_ROOT}" ]; then
  echo "ERROR: \$WORK_ROOT is not defined!"
  exit 1
fi

# Make sure the background file exists
if [ ! -r "${BK_FILE}" ]; then
  echo "ERROR: ${BK_FILE} does not exist!"
  exit 1
fi

# Make sure OBS_ROOT is defined and exists
if [ ! "${OBS_ROOT}" ]; then
  echo "ERROR: \$OBS_ROOT is not defined!"
  exit 1
fi
if [ ! -d "${OBS_ROOT}" ]; then
  echo "ERROR: OBS_ROOT directory '${OBS_ROOT}' does not exist!"
  exit 1
fi

# Set the path to the GSI static files
if [ ! "${FIX_ROOT}" ]; then
  echo "ERROR: \$FIX_ROOT is not defined!"
  exit 1
fi
if [ ! -d "${FIX_ROOT}" ]; then
  echo "ERROR: fix directory '${FIX_ROOT}' does not exist!"
  exit 1
fi

# Set the path to the CRTM coefficients 
if [ ! "${CRTM_ROOT}" ]; then
  echo "ERROR: \$CRTM_ROOT is not defined!"
  exit 1
fi
if [ ! -d "${CRTM_ROOT}" ]; then
  echo "ERROR: fix directory '${CRTM_ROOT}' does not exist!"
  exit 1
fi


# Make sure the GSI executable exists
if [ ! -x "${GSI_EXE}" ]; then
  echo "ERROR: ${GSI_EXE} does not exist!"
  exit 1
fi

#
##################################################################################
# Create the ram work directory and cd into it

workdir=${WORK_ROOT}

mkdir -p ${workdir}

echo " Enter to working directory:" ${workdir}

cd ${workdir}

rm *

##################################################################################

echo " Copy GSI executable, background file, and link observation bufr to working directory"

# Save a copy of the GSI executable in the workdir
cp ${GSI_EXE} gsi.x

# Bring over background field (it's modified by GSI so we can't link to it)
cp ${BK_FILE} ./wrf_inout


# Link to the prepbufr data
ln -sf ${PREPBUFR} ./prepbufr

# Link to the radiance and sat derived wind data

# Hourly bufr files
srcobsfile[13]=${OBS_ROOT}/abig16.${YYYYMMDD}.t${HH}z.bufr_d


# Files every 6 hs
if [ "$HH" -ge 3 ] && [ "$HH" -lt 9 ]; then
	srcobsfile[1]=${OBS_ROOT}/satwnd.${YYYYMMDD}.t06z.bufr_d
        srcobsfile[2]=${OBS_ROOT}/1bamua.${YYYYMMDD}.t06z.bufr_d
        srcobsfile[3]=${OBS_ROOT}/1bhrs4.${YYYYMMDD}.t06z.bufr_d
        srcobsfile[4]=${OBS_ROOT}/1bmhs.${YYYYMMDD}.t06z.bufr_d
        srcobsfile[6]=${OBS_ROOT}/ssmisu.${YYYYMMDD}.t06z.bufr_d
        srcobsfile[7]=${OBS_ROOT}/airsev.${YYYYMMDD}.t06z.bufr_d
        srcobsfile[8]=${OBS_ROOT}/sevcsr.${YYYYMMDD}.t06z.bufr_d
	srcobsfile[9]=${OBS_ROOT}/mtiasi.${YYYYMMDD}.t06z.bufr_d
        srcobsfile[12]=${OBS_ROOT}atms.${YYYYMMDD}.t06z.bufr_d
elif [ "$HH" -ge 9 ] && [ "$HH" -lt 15 ]; then
	srcobsfile[1]=${OBS_ROOT}/satwnd.${YYYYMMDD}.t12z.bufr_d
        srcobsfile[2]=${OBS_ROOT}/1bamua.${YYYYMMDD}.t12z.bufr_d
        srcobsfile[3]=${OBS_ROOT}/1bhrs4.${YYYYMMDD}.t12z.bufr_d
        srcobsfile[4]=${OBS_ROOT}/1bmhs.${YYYYMMDD}.t12z.bufr_d
        srcobsfile[6]=${OBS_ROOT}/ssmisu.${YYYYMMDD}.t12z.bufr_d
        srcobsfile[7]=${OBS_ROOT}/airsev.${YYYYMMDD}.t12z.bufr_d
        srcobsfile[8]=${OBS_ROOT}/sevcsr.${YYYYMMDD}.t12z.bufr_d
	srcobsfile[9]=${OBS_ROOT}/mtiasi.${YYYYMMDD}.t12z.bufr_d
        srcobsfile[12]=${OBS_ROOT}/atms.${YYYYMMDD}.t12z.bufr_d
elif [ "$HH" -ge 15 ] && [ "$HH" -lt 21 ]; then
	srcobsfile[1]=${OBS_ROOT}/satwnd.${YYYYMMDD}.t18z.bufr_d
        srcobsfile[2]=${OBS_ROOT}/1bamua.${YYYYMMDD}.t18z.bufr_d
        srcobsfile[3]=${OBS_ROOT}/1bhrs4.${YYYYMMDD}.t18z.bufr_d
        srcobsfile[4]=${OBS_ROOT}/1bmhs.${YYYYMMDD}.t18z.bufr_d
        srcobsfile[6]=${OBS_ROOT}/ssmisu.${YYYYMMDD}.t18z.bufr_d
        srcobsfile[7]=${OBS_ROOT}/airsev.${YYYYMMDD}.t18z.bufr_d
        srcobsfile[8]=${OBS_ROOT}/sevcsr.${YYYYMMDD}.t18z.bufr_d
	srcobsfile[9]=${OBS_ROOT}/mtiasi.${YYYYMMDD}.t18z.bufr_d
        srcobsfile[12]=${OBS_ROOT}/atms.${YYYYMMDD}.t18z.bufr_d
elif [ "$HH" -ge 21 ]; then
	NEXTDAY=$(date -d "$YYYYMMDD+ 1 days" +"%Y%m%d")
	srcobsfile[1]=${OBS_ROOT}/satwnd.${NEXTDAY}.t00z.bufr_d
        srcobsfile[2]=${OBS_ROOT}/1bamua.${NEXTDAY}.t00z.bufr_d
        srcobsfile[3]=${OBS_ROOT}/1bhrs4.${NEXTDAY}.t00z.bufr_d
        srcobsfile[4]=${OBS_ROOT}/1bmhs.${NEXTDAY}.t00z.bufr_d
        srcobsfile[6]=${OBS_ROOT}/ssmisu.${NEXTDAY}.t00z.bufr_d
        srcobsfile[7]=${OBS_ROOT}/airsev.${NEXTDAY}.t00z.bufr_d
        srcobsfile[8]=${OBS_ROOT}/sevcsr.${NEXTDAY}.t00z.bufr_d
	srcobsfile[9]=${OBS_ROOT}/mtiasi.${NEXTDAY}.t00z.bufr_d
        srcobsfile[12]=${OBS_ROOT}/atms.${NEXTDAY}.t00z.bufr_d
elif [ "$HH" -lt 3 ]; then
	srcobsfile[1]=${OBS_ROOT}/satwnd.${YYYYMMDD}.t00z.bufr_d
        srcobsfile[2]=${OBS_ROOT}/1bamua.${YYYYMMDD}.t00z.bufr_d
        srcobsfile[3]=${OBS_ROOT}/1bhrs4.${YYYYMMDD}.t00z.bufr_d
        srcobsfile[4]=${OBS_ROOT}/1bmhs.${YYYYMMDD}.t00z.bufr_d
        srcobsfile[6]=${OBS_ROOT}/ssmisu.${YYYYMMDD}.t00z.bufr_d
        srcobsfile[7]=${OBS_ROOT}/airsev.${YYYYMMDD}.t00z.bufr_d
        srcobsfile[8]=${OBS_ROOT}/sevcsr.${YYYYMMDD}.t00z.bufr_d
	srcobsfile[9]=${OBS_ROOT}/mtiasi.${YYYYMMDD}.t00z.bufr_d
        srcobsfile[12]=${OBS_ROOT}/atms.${YYYYMMDD}.t00z.bufr_d
fi
gsiobsfile[1]=satwndbufr
gsiobsfile[2]=amsuabufr
gsiobsfile[3]=hirs4bufr
gsiobsfile[4]=mhsbufr
gsiobsfile[5]=amsubbufr
gsiobsfile[6]=ssmirrbufr
gsiobsfile[7]=airsbufr
gsiobsfile[8]=seviribufr
gsiobsfile[9]=iasibufr
gsiobsfile[12]=atmsbufr
gsiobsfile[13]=abibufr

ii=1
while [[ $ii -le 21 ]]; do
   if [ -r "${srcobsfile[$ii]}" ]; then
      ln -sf ${srcobsfile[$ii]}  ${gsiobsfile[$ii]}
      echo "link source obs file ${srcobsfile[$ii]}"
   fi
   (( ii = $ii + 1 ))
done

#
##################################################################################

ifhyb=.false.
if [ ${if_hybrid} = Yes ] ; then
  ls ${ENSEMBLE_FILE_mem}* > filelist02
  if [ ${if_4DEnVar} = Yes ] ; then
    ls ${ENSEMBLE_FILE_mem_p1}* > filelist03
    ls ${ENSEMBLE_FILE_mem_m1}* > filelist01
  fi
  
  nummem=`more filelist02 | wc -l`
  nummem=$((nummem -3 ))

  if [[ ${nummem} -ge 5 ]]; then
    ifhyb=.true.
    ${ECHO} " GSI hybrid uses ${ENSEMBLE_FILE_mem} with n_ens=${nummem}"
  fi
fi
if4d=.false.
if [[ ${ifhyb} = .true. && ${if_4DEnVar} = Yes ]] ; then
  if4d=.true.
fi
#
##################################################################################

echo " Copy fixed files and link CRTM coefficient files to working directory"

# Set fixed files
#   berror   = forecast model background error statistics
#   specoef  = CRTM spectral coefficients
#   trncoef  = CRTM transmittance coefficients
#   emiscoef = CRTM coefficients for IR sea surface emissivity model
#   aerocoef = CRTM coefficients for aerosol effects
#   cldcoef  = CRTM coefficients for cloud effects
#   satinfo  = text file with information about assimilation of brightness temperatures
#   satangl  = angle dependent bias correction file (fixed in time)
#   pcpinfo  = text file with information about assimilation of prepcipitation rates
#   ozinfo   = text file with information about assimilation of ozone data
#   errtable = text file with obs error for conventional data (regional only)
#   convinfo = text file with information about assimilation of conventional data
#   lightinfo= text file with information about assimilation of GLM lightning data
#   bufrtable= text file ONLY needed for single obs test (oneobstest=.true.)
#   bftab_sst= bufr table for sst ONLY needed for sst retrieval (retrieval=.true.)

if [ ${bkcv_option} = GLOBAL ] ; then
  echo ' Use global background error covariance'
  BERROR=${FIX_ROOT}/${BYTE_ORDER}/nam_glb_berror.f77.gcv
  OBERROR=${FIX_ROOT}/prepobs_errtable.global
  if [ ${bk_core} = NMM ] ; then
     ANAVINFO=${FIX_ROOT}/anavinfo_ndas_netcdf_glbe
  fi
  if [ ${bk_core} = ARW ] ; then
    ANAVINFO=${FIX_ROOT}/anavinfo_arw_netcdf_glbe
  fi
  if [ ${bk_core} = NMMB ] ; then
    ANAVINFO=${FIX_ROOT}/anavinfo_nems_nmmb_glb
  fi
else
  echo ' Use NAM background error covariance'
  BERROR=${FIX_ROOT}/${BYTE_ORDER}/nam_nmmstat_na.gcv
  OBERROR=${FIX_ROOT}/nam_errtable.r3dv
  if [ ${bk_core} = NMM ] ; then
     ANAVINFO=${FIX_ROOT}/anavinfo_ndas_netcdf
  fi
  if [ ${bk_core} = ARW ] ; then
     ANAVINFO=${FIX_ROOT}/anavinfo_arw_netcdf
  fi
  if [ ${bk_core} = NMMB ] ; then
     ANAVINFO=${FIX_ROOT}/anavinfo_nems_nmmb
   fi
fi

SATINFO=${BASEDIR}/fix/global_satinfo.txt
CONVINFO=${FIX_ROOT}/global_convinfo.txt
OZINFO=${FIX_ROOT}/global_ozinfo.txt
PCPINFO=${FIX_ROOT}/global_pcpinfo.txt
LIGHTINFO=${FIX_ROOT}/global_lightinfo.txt

#  copy Fixed fields to working directory
 cp $ANAVINFO anavinfo
 cp $BERROR   berror_stats
 cp $SATINFO  satinfo
 cp $CONVINFO convinfo
 cp $OZINFO   ozinfo
 cp $PCPINFO  pcpinfo
 cp $LIGHTINFO lightinfo
 cp $OBERROR  errtable

#    # CRTM Spectral and Transmittance coefficients
CRTM_ROOT_ORDER=${FIX_ROOT}/${BYTE_ORDER}
emiscoef_IRwater=${CRTM_ROOT_ORDER}/Nalli.IRwater.EmisCoeff.bin
emiscoef_IRice=${CRTM_ROOT_ORDER}/NPOESS.IRice.EmisCoeff.bin
emiscoef_IRland=${CRTM_ROOT_ORDER}/NPOESS.IRland.EmisCoeff.bin
emiscoef_IRsnow=${CRTM_ROOT_ORDER}/NPOESS.IRsnow.EmisCoeff.bin
emiscoef_VISice=${CRTM_ROOT_ORDER}/NPOESS.VISice.EmisCoeff.bin
emiscoef_VISland=${CRTM_ROOT_ORDER}/NPOESS.VISland.EmisCoeff.bin
emiscoef_VISsnow=${CRTM_ROOT_ORDER}/NPOESS.VISsnow.EmisCoeff.bin
emiscoef_VISwater=${CRTM_ROOT_ORDER}/NPOESS.VISwater.EmisCoeff.bin
emiscoef_MWwater=${CRTM_ROOT_ORDER}/FASTEM6.MWwater.EmisCoeff.bin
aercoef=${CRTM_ROOT_ORDER}/AerosolCoeff.bin
cldcoef=${CRTM_ROOT_ORDER}/CloudCoeff.bin

ln -s $emiscoef_IRwater ./Nalli.IRwater.EmisCoeff.bin
ln -s $emiscoef_IRice ./NPOESS.IRice.EmisCoeff.bin
ln -s $emiscoef_IRsnow ./NPOESS.IRsnow.EmisCoeff.bin
ln -s $emiscoef_IRland ./NPOESS.IRland.EmisCoeff.bin
ln -s $emiscoef_VISice ./NPOESS.VISice.EmisCoeff.bin
ln -s $emiscoef_VISland ./NPOESS.VISland.EmisCoeff.bin
ln -s $emiscoef_VISsnow ./NPOESS.VISsnow.EmisCoeff.bin
ln -s $emiscoef_VISwater ./NPOESS.VISwater.EmisCoeff.bin
ln -s $emiscoef_MWwater ./FASTEM6.MWwater.EmisCoeff.bin
ln -s $aercoef  ./AerosolCoeff.bin
ln -s $cldcoef  ./CloudCoeff.bin

# Copy CRTM coefficient files based on entries in satinfo file
for file in `awk '{if($1!~"!"){print $1}}' ./satinfo | sort | uniq` ;do
   ln -s ${CRTM_ROOT_ORDER}/${file}.SpcCoeff.bin ./
   ln -s ${CRTM_ROOT_ORDER}/${file}.TauCoeff.bin ./
done


# for satellite bias correction
# Users may need to use their own satbias files for correct bias correction
cp ${BASEDIR}/fix/satbias_in ./satbias_in
cp ${BASEDIR}/fix/satbias_pc_in ./satbias_pc 
cp ${BASEDIR}/fix/satbias_ang ./satbias_ang
cp ${GSI_ROOT}/fix/atms_beamwidth.txt ./atms_beamwidth.txt

# cloudy sky errors
cp ${GSI_ROOT}/fix/cloudy_radiance_info.txt ./cloudy_radiance_info.txt

#
##################################################################################
# Set some parameters for use by the GSI executable and to build the namelist
echo " Build the namelist "

# default is NAM
#   as_op='1.0,1.0,0.5 ,0.7,0.7,0.5,1.0,1.0,'
vs_op='1.0,'
hzscl_op='0.373,0.746,1.50,'
if [ ${bkcv_option} = GLOBAL ] ; then
#   as_op='0.6,0.6,0.75,0.75,0.75,0.75,1.0,1.0'
   vs_op='0.7,'
   hzscl_op='1.7,0.8,0.5,'
fi
if [ ${bk_core} = NMMB ] ; then
   vs_op='0.6,'
fi

# default is NMM
   bk_core_arw='.false.'
   bk_core_nmm='.true.'
   bk_core_nmmb='.false.'
   bk_if_netcdf='.true.'
if [ ${bk_core} = ARW ] ; then
   bk_core_arw='.true.'
   bk_core_nmm='.false.'
   bk_core_nmmb='.false.'
   bk_if_netcdf='.true.'
fi
if [ ${bk_core} = NMMB ] ; then
   bk_core_arw='.false.'
   bk_core_nmm='.false.'
   bk_core_nmmb='.true.'
   bk_if_netcdf='.false.'
fi

if [ ${if_observer} = Yes ] ; then
  nummiter=0
  if_read_obs_save='.true.'
  if_read_obs_skip='.false.'
else
  nummiter=2
  if_read_obs_save='.false.'
  if_read_obs_skip='.false.'
fi

# Build the GSI namelist on-the-fly
. $GSI_NAMELIST

# modify the anavinfo vertical levels based on wrf_inout for WRF ARW and NMM
if [ ${bk_core} = ARW ] || [ ${bk_core} = NMM ] ; then
bklevels=`ncdump -h wrf_inout | grep "bottom_top =" | awk '{print $3}' `
bklevels_stag=`ncdump -h wrf_inout | grep "bottom_top_stag =" | awk '{print $3}' `
anavlevels=`cat anavinfo | grep ' sf ' | tail -1 | awk '{print $2}' `  # levels of sf, vp, u, v, t, etc
anavlevels_stag=`cat anavinfo | grep ' prse ' | tail -1 | awk '{print $2}' `  # levels of prse
sed -i 's/ '$anavlevels'/ '$bklevels'/g' anavinfo
sed -i 's/ '$anavlevels_stag'/ '$bklevels_stag'/g' anavinfo
fi

#
###################################################
#  run  GSI
###################################################
echo ' Run GSI with' ${bk_core} 'background'

#$MPIEXE ./gsi.x > stdout 2>&1 
mpirun -np ${GSIPROC} ./gsi.x > stdout 2>&1

##################################################################
#  run time error check
##################################################################
error=$?

if [ ${error} -ne 0 ]; then
  echo "ERROR: GSI crashed  Exit status=${error}"
  exit ${error}
fi

#
##################################################################
#
#   GSI updating satbias_in
#
# GSI updating satbias_in (only for cycling assimilation)

# Copy the output to more understandable names
ln -sf stdout      stdout.anl.${ANAL_TIME}
ln -sf wrf_inout   wrfanl.${ANAL_TIME}
ln -sf fort.201    fit_p1.${ANAL_TIME}
ln -sf fort.202    fit_w1.${ANAL_TIME}
ln -sf fort.203    fit_t1.${ANAL_TIME}
ln -sf fort.204    fit_q1.${ANAL_TIME}
ln -sf fort.207    fit_rad1.${ANAL_TIME}

# Loop over first and last outer loops to generate innovation
# diagnostic files for indicated observation types (groups)
#
# NOTE:  Since we set miter=2 in GSI namelist SETUP, outer
#        loop 03 will contain innovations with respect to
#        the analysis.  Creation of o-a innovation files
#        is triggered by write_diag(3)=.true.  The setting
#        write_diag(1)=.true. turns on creation of o-g
#        innovation files.
#

loops="01 03"
for loop in $loops; do

case $loop in
  01) string=ges;;
  03) string=anl;;
   *) string=$loop;;
esac

#  Collect diagnostic files for obs types (groups) below
#   listall="conv amsua_metop-a mhs_metop-a hirs4_metop-a hirs2_n14 msu_n14 \
#          sndr_g08 sndr_g10 sndr_g12 sndr_g08_prep sndr_g10_prep sndr_g12_prep \
#          sndrd1_g08 sndrd2_g08 sndrd3_g08 sndrd4_g08 sndrd1_g10 sndrd2_g10 \
#          sndrd3_g10 sndrd4_g10 sndrd1_g12 sndrd2_g12 sndrd3_g12 sndrd4_g12 \
#          hirs3_n15 hirs3_n16 hirs3_n17 amsua_n15 amsua_n16 amsua_n17 \
#          amsub_n15 amsub_n16 amsub_n17 hsb_aqua airs_aqua amsua_aqua \
#          goes_img_g08 goes_img_g10 goes_img_g11 goes_img_g12 \
#          pcp_ssmi_dmsp pcp_tmi_trmm sbuv2_n16 sbuv2_n17 sbuv2_n18 \
#          omi_aura ssmi_f13 ssmi_f14 ssmi_f15 hirs4_n18 amsua_n18 mhs_n18 \
#          amsre_low_aqua amsre_mid_aqua amsre_hig_aqua ssmis_las_f16 \
#          ssmis_uas_f16 ssmis_img_f16 ssmis_env_f16 mhs_metop_b \
#          hirs4_metop_b hirs4_n19 amusa_n19 mhs_n19 goes_glm_16"
listall=`ls pe* | cut -f2 -d"." | awk '{print substr($0, 0, length($0)-2)}' | sort | uniq `

   for type in $listall; do
      count=`ls pe*${type}_${loop}* | wc -l`
      if [[ $count -gt 0 ]]; then
         cat pe*${type}_${loop}* > diag_${type}_${string}.${ANAL_TIME} # For binary diag files
      fi
   done
done

#  Clean working directory to save only important files 
ls -l * > list_run_directory
if [[ ${if_clean} = clean  &&  ${if_observer} != Yes ]]; then
  echo ' Clean working directory after GSI run'
  rm -f *Coeff.bin     # all CRTM coefficient files
  rm -f pe0*           # diag files on each processor
  rm -f obs_input.*    # observation middle files
  rm -f siganl sigf0?  # background middle files
  rm -f fsize_*        # delete temperal file for bufr size
fi
#
#
#################################################
# start to calculate diag files for each member
#################################################
#
if [ ${if_observer} = Yes ] ; then
  string=ges
  for type in $listall; do
    count=0
    if [[ -f diag_${type}_${string}.${ANAL_TIME} ]]; then
       mv diag_${type}_${string}.${ANAL_TIME} diag_${type}_${string}.ensmean
    fi
  done
  mv wrf_inout wrf_inout_ensmean

# Build the GSI namelist on-the-fly for each member
  nummiter=0
  if_read_obs_save='.false.'
  if_read_obs_skip='.true.'
. $GSI_NAMELIST

# Loop through each member
  loop="01"
  ensmem=1
  while [[ $ensmem -le $no_member ]];do

     rm pe0*

     echo "\$ensmem is $ensmem"
     ensmemid=`printf %2.2i $ensmem`

# get new background for each member
     if [[ -f wrf_inout ]]; then
       rm wrf_inout
       rm wrf_inou*
     fi

     cp ${BK_ROOT}/${ensmemid}/wrf_inou* .
     BK_FILE_ANA=wrf_inou4
     ln -sf $BK_FILE_ANA wrf_inout

#  run  GSI
     echo ' Run GSI with' ${bk_core} 'for member ', ${ensmemid}

     mpirun -np ${GSIPROC} ./gsi.x > stdout_mem0${ensmemid} 2>&1

#  run time error check and save run time file status
     error=$?

     if [ ${error} -ne 0 ]; then
       echo "ERROR: ${GSI} crashed for member ${ensmemid} Exit status=${error}"
       exit ${error}
     fi

     ls -l * > list_run_directory_mem0${ensmemid}

# generate diag files

     for type in $listall; do
           count=`ls pe*${type}_${loop}* | wc -l`
        if [[ $count -gt 0 ]]; then
         cat pe*${type}_${loop}* > diag_${type}_${string}.mem0${ensmemid} # For binary diag files
        fi
     done

# next member
     (( ensmem += 1 ))
      
  done

fi

exit 0
