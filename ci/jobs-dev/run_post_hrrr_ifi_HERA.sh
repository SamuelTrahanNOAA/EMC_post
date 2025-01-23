#!/bin/sh 
 
#SBATCH -o out.post.hrrr_ifi
#SBATCH -e out.post.hrrr_ifi
#SBATCH -J hrrr_ifi_test
#SBATCH -t 00:30:00
##SBATCH -q debug
#SBATCH -q batch
#SBATCH -A ovp
#SBATCH -N 2 --ntasks-per-node=24

# specify computation resource
export MP_LABELIO=yes
export threads=1
export OMP_NUM_THREADS=$threads
export APRUN="srun"

echo "starting time"
date

######################################################################
# Purpose: to run RAP post processing
######################################################################

# EXPORT list here

module purge
module use /contrib/spack-stack/spack-stack-1.8.0/envs/ue-intel-2021.5.0/install/modulefiles/Core
module load stack-intel/2021.5.0
module load stack-intel-oneapi-mpi/2021.5.1
module load libpng/1.6.37
module load jasper/2.0.32
module load prod_util/2.1.1
module load crtm/2.4.0.1
module list

msg="Starting hrrr_ifi test"
postmsg "$logfile" "$msg"

export cmp_grib2_grib2=/home/Wen.Meng/bin/cmp_grib2_grib2_new
export POSTGPEXEC=${svndir}/exec/upp.x

# CALL executable job script here

# specify your running and output directory
export startdate=2020060118
export fhr=04
export DATA=$rundir/hrrr_ifi_${startdate}

export NEWDATE=`${NDATE} +${fhr} $startdate`

export YY=`echo ${NEWDATE} | cut -c1-4`
export MM=`echo ${NEWDATE} | cut -c5-6`
export DD=`echo ${NEWDATE} | cut -c7-8`
export HH=`echo ${NEWDATE} | cut -c9-10`

rm -rf $DATA; mkdir -p $DATA
cd $DATA

cat > itag <<EOF
&model_inputs
fileName='$homedir/data_in/hrrr/wrfout_d01_${YY}-${MM}-${DD}_${HH}_00_00'
IOFORM='netcdf'
grib='grib2'
DateStr='${YY}-${MM}-${DD}_${HH}:00:00'
MODELNAME='RAPR'
/
&NAMPGB
KPO=47,PO=2.,5.,7.,10.,20.,30.,50.,70.,75.,100.,125.,150.,175.,200.,225.,250.,275.,300.,325.,350.,375.,400.,425.,450.,475.,500.,525.,550.,575.,600.,625.,650.,675.,700.,725.,750.,775.,800.,825.,850.,875.,900.,925.,950.,975.,1000.,1013.2
write_ifi_debug_files=.true.
/
EOF
#FMIN

#copy fix data
cp $homedir/fix/fix_2.3.0/*bin .

#copy xml
cp ${svndir}/parm/params_grib2_tbl_new params_grib2_tbl_new
cp ${svndir}/parm/postxconfig-NT-hrrr.txt postxconfig-NT.txt
cp ${svndir}/fix/rap_micro_lookup.dat eta_micro_lookup.dat

${APRUN} ${POSTGPEXEC} < itag > wrfpost2.out

# operational hrrr post processing generates 3 files
filelist="IFIFIP.GrbF04"

for file in $filelist; do
export filein2=$file
ls -l ${filein2}
export err=$?

if [ $err = "0" ] ; then

 # operational hrrr post processing generates 3 files, start with BGDAWP first
 # use cmp to see if new pgb files are identical to the control one
 cmp ${filein2} $homedir/data_out/hrrr_ifi/${filein2}.${machine}

 # if not bit-identical, use cmp_grib2_grib2 to compare each grib record
 export err1=$?
 if [ $err1 -eq 0 ] ; then
  msg="hrrr_ifi test: your new post executable generates bit-identical ${filein2} as the trunk"
  echo $msg
 else
  msg="hrrr_ifi test: your new post executable did not generate bit-identical ${filein2} as the trunk"
  echo $msg
  echo " start comparing each grib record and write the comparison result to *diff files"
  echo " check these *diff files to make sure your new post only change variables which you intend to change"
  $cmp_grib2_grib2 $homedir/data_out/hrrr_ifi/${filein2}.${machine} ${filein2} > ${filein2}.diff
 fi


else

 msg="hrrr_ifi test: post failed using your new post executable to generate ${filein2}"
 echo $msg

fi
postmsg "$logfile" "$msg"
done

echo "PROGRAM IS COMPLETE!!!!!"
msg="Ending hrrr_ifi test"
postmsg "$logfile" "$msg"


