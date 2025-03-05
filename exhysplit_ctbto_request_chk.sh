#!/bin/ksh
#--------------------------------------------------------------------------
# Program Name: exhysplit_ctbto_request_chk.sh
# Contact: Binyu Wang, EMC
# Author: Barbara Stunder, ARL
# Abstract: Driver script for checking input files for CTBTO forecast
#
# Usage:
#  Input Files: converted ARL format GDAS files, gdas.YYYYMM,current7days
#              initial file
#  Output Files:
#    CONTROL.*, latlons*
#
#last revised: 28 FEB 2017 (HHC) - start the log section
#               28 FEB 2017 (HCH) - modified for mpmd processing
#--------------------------------------------------------------------------
#
set -ax 
export SLEEP_LOOP_MAX=${SLEEP_LOOP_MAX:-25}
export SLEEP_INT=${SLEEP_INT:-30}
export NETNAME=`dirname $ECF_NAME`

echo "Parsing request email ..."

INFILE="ctbto_input_$YR$MN$DD$HH.txt"
INFILEprev="ctbto_input_$YR$MN$DD$HHprev.txt"

cd $DATA
## if [ $PARAFLAG = "YES" ]; then 
##  if [ -f ${GESDIR}/ctbto.ini ] ; then
##   cp -rp  ${GESDIR}/ctbto.ini  .
##  else
##   err_exit "${GESDIR}/ctbto.ini does not exist"
##  fi
## fi

export ic=1
while [ $ic -le $SLEEP_LOOP_MAX ]
do
   if [ -f ${DCOM}/${INFILE} ] ; then
      sleep 10
      break
   elif [ -f ${DCOM}/${INFILEprev} ]; then
      echo "previous hour input file found... proceed..."
      INFILE=${INFILEprev}
      sleep 10
      break
   else
      ic=`expr $ic + 1`
      sleep $SLEEP_INT
   fi
   if [ $ic -eq $SLEEP_LOOP_MAX ] ; then
      echo "FATAL ERROR: ${DCOM}/${INFILE} not found after waiting 10 minutes. Rerun when file is available"
      export err=1; err_chk
   fi
done

cp -rp ${DCOM}/${INFILE}  ctbto.ini
cp -rp ${DCOM}/${INFILE}  ${GESDIR}/

flag_next=no
while read line
do
   proc_std=`echo ${line} | awk -F" " '{ print $1 }'`
   echo ${proc_std}
   if [ "${flag_next}" == "yes" ]; then break; fi
   if [ "${proc_std}" == "Source-receptor" ]; then flag_next=yes; fi
done < ctbto.ini
echo " total stations to be processed = ${proc_std}"
num_std=`echo ${proc_std} | cut -c1-3`
##
## Based on NCO request, all gdas1 weekly files of a month are 
## now stored in individual subdirectory (w1-w4 or w1-w5), i.e.,
## /com/hysplit/prod/gdas.yyyymm/gdas1${CHR_MON(mm)}yy.w${i} (COMINgdas)
## where i is from 1-4(5) and CHR_MON is the 3 characters description
## of the month such as "nov" for November.
## The current7days file will be put in the directory of current
## month (COMINgdaslatest), e.g, today is 20151112, the file is in gdas.201511.
## Note COMINgdaslatest & COMINgdas maybe different, e.g., CTBTO request received
## on 20151107 but some of the case is started on 20151031.
##
cp ${COMINgdasm1}/gdas1* .
cp  ${COMINgdas}/gdas1* .
cp  ${COMINgdaslatest}/current7days .

#remove the leading zero
num_sites=$(echo $num_std | sed 's/^0*//')
${EXEChysplit}/hysplit_set4ctbt ${num_sites} >>${DATA}/run.log
export err=$?;err_chk

workid=()
##let i=${#workid[*]}
let i=0
while [ ${i} -lt ${num_sites} ]; do
   if [ ${i} -lt 10 ]; then
      chrid="00"${i}
   elif [ ${i} -lt 100 ]; then
      chrid="0"${i}
   else
      chrid=${i}
   fi
   workid[${i}]=${chrid}
   ((i++))
done
for i in "${workid[@]}"
do
   if [ ! -f ${DATA}/latlons.c${i} ]; then
      echo "Input file latlons.c${i} not found!" >>${DATA}/RUNLOG
      if [ ${i} -lt ${num_std} ]; then
         err_exit "Input file latlonsc${i} not found!"
      fi
   else
      echo "Control files ${DATA}/latlons.c${i} generated!"
      cp -p latlons.c${i}     $COMOUT
      cp -p CONTROL.c${i}.*   $COMOUT
   fi
done
cp -p latlons.master    $COMOUT/latlons
cp -p latlons.mapping   $COMOUT


  # if [ "${RUN_ENVIR}" != "emc" ]; then
     for job in $CTBTO_JOB_LIST
     do
        ecflow_client --force queued $NETNAME/$job
     done
  ## else
  ##    for job in $CTBTO_JOB_LIST; do
  ##       $HOMEhysplit/ecf/hysplit/ctbto/$job.ecf
  ##    done
  #fi

exit
