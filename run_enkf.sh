#PBS -N tutorial-enkf 
#PBS -m abe 
#PBS -l walltime=03:00:00 
#PBS -l nodes=2:ppn=96 
#PBS -j oe 

BASEDIR=/home/paola.corrales/datosmunin3/tutorial_gsi           # Path to the tutorial folder
GSIDIR=/home/paola.corrales/datosmunin3/comGSIv3.7_EnKFv1.3     # Path to where the GSI/EnKF code is compiled
FECHA_INI='11:00:00 2018-11-22'                                 # Init time (analisis time - $ANALISIS)
ANALISIS=3600                                                   # Assimilation cycle in seconds
OBSWIN=1                                                        # Assimilation window in hours
N_MEMBERS=10                                                    # Ensemble size
E_WE=200                                                        # West-East grid points
E_SN=240                                                        # South-North grid points
E_BT=37                                                         # Vertical levels

ENKFPROC=20
export OMP_NUM_THREADS=1

set -x

####################################################
# case set up (users should change this part)
#####################################################
#
# ANAL_TIME= analysis time  (YYYYMMDDHH)
# WORK_ROOT= working directory, where GSI runs
# PREPBURF = path of PreBUFR conventional obs
# OBS_ROOT = path of observations files
# FIX_ROOT = path of fix files
# ENKF_EXE  = path and name of the EnKF executable 
  ANAL_TIME=$(date -d "$FECHA_INI+ $ANALISIS seconds" +"%Y%m%d%H%M%S")
  JOB_DIR=$BASEDIR
  RUN_NAME=ENKF
  OBS_ROOT=$BASEDIR/OBS
  BK_ROOT=$BASEDIR/GUESS/$(date -d "$FECHA_INI + $ANALISIS seconds" +"%Y%m%d%H%M%S")
  GSI_ROOT=$GSIDIR
  CRTM_ROOT=$GSI_ROOT/libsrc/crtm
  diag_ROOT=$BASEDIR/GSI
  ENKF_EXE=${GSI_ROOT}/build/bin/enkf_wrf.x
  WORK_ROOT=${JOB_DIR}/${RUN_NAME}
  FIX_ROOT=${GSI_ROOT}/fix
  ENKF_NAMELIST=${BASEDIR}/namelists/comenkf_namelist.sh

# ensemble parameters
#
  NMEM_ENKF=$N_MEMBERS
  BK_FILE_mem=${BK_ROOT}/00/wrfarw
  NLONS=$((${E_WE}-1))
  NLATS=$((${E_SN}-1))
  NLEVS=${E_BT}
  IF_ARW=.true.
  IF_NMM=.false.

list=`ls $BASEDIR/GSI/pe* | cut -f2 -d"." --complement | cut -f2 -d"." | awk '{print substr($0, 0, length($0)-2)}' | sort | uniq `
echo LISTA  $list
#
#####################################################
# Users should NOT change script after this point
#####################################################
#

# Given the analysis date, compute the date from which the
# first guess comes.  Extract cycle and set prefix and suffix
# for guess and observation data files
# gdate=`$ndate -06 $adate`
#gdate=$ANAL_TIME
#YYYYMMDD=`echo $adate | cut -c1-8`
#HH=`echo $adate | cut -c9-10`

# Fixed files
# CONVINFO=${FIX_ROOT}/global_convinfo.txt
# SATINFO=${FIX_ROOT}/global_satinfo.txt
SCANINFO=${FIX_ROOT}/global_scaninfo.txt
# OZINFO=${FIX_ROOT}/global_ozinfo.txt
ANAVINFO=${diag_ROOT}/anavinfo
CONVINFO=${diag_ROOT}/convinfo
SATINFO=${diag_ROOT}/satinfo
#SCANINFO=${diag_ROOT}/scaninfo
OZINFO=${diag_ROOT}/ozinfo
# LOCINFO=${FIX_ROOT}/global_hybens_locinfo.l64.txt

# Set up workdir
mkdir $WORK_ROOT
cd $WORK_ROOT
#rm *

cp $ENKF_EXE enkf.x

cp $ANAVINFO        ./anavinfo
cp $CONVINFO        ./convinfo
cp $SATINFO         ./satinfo
cp $SCANINFO        ./scaninfo
cp $OZINFO          ./ozinfo
# cp $LOCINFO         ./hybens_locinfo

cp ${BASEDIR}/namelists/fix/satbias_in ./satbias_in
cp ${BASEDIR}/namelists/fix/satbias_pc_in ./satbias_pc
cp ${BASEDIR}/namelists/fix/satbias_ang ./satbias_ang
cp ${GSI_ROOT}/fix/atms_beamwidth.txt ./atms_beamwidth.txt

# get mean
ln -sf ${BK_FILE_mem}.ensmean ./firstguess.ensmean
for type in $list; do
   ln -sf $diag_ROOT/diag_${type}_ges.ensmean .
done

# get each member
imem=1
while [[ $imem -le $NMEM_ENKF ]]; do
   member=`printf %02i $imem`
   ln -sf ${BK_ROOT}/${member}/wrf_inou4 ./firstguess.mem0${member}
   for type in $list; do
      ln -sf $diag_ROOT/diag_${type}_ges.mem0${member} .
   done
   (( imem = $imem + 1 ))
done

# Build the GSI namelist on-the-fly
. $ENKF_NAMELIST

# make analysis files
cp firstguess.ensmean analysis.ensmean

# get each member
imem=1
while [[ $imem -le $NMEM_ENKF ]]; do
   member="mem"`printf %03i $imem`
   cp firstguess.${member} analysis.${member}
   (( imem = $imem + 1 ))
done

#
###################################################
#  run  EnKF
###################################################
echo ' Run EnKF'

mpirun -np ${ENKFPROC} ./enkf.x < enkf.nml > stdout 2>&1

##################################################################
#  run time error check
##################################################################
error=$?

if [ ${error} -ne 0 ]; then
  echo "ERROR: ${ENKF_EXE} crashed  Exit status=${error}"
  exit ${error}
fi

exit 0
