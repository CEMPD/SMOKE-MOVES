#!/bin/csh -f

## log w/ EMF server that script is running
$EMF_CLIENT -k $EMF_JOBKEY -s "Running"

# create directories
if ( ! -e $IMD_ROOT ) mkdir -p $IMD_ROOT
if ( ! -e $IMD_ROOT/logs ) mkdir -p $IMD_ROOT/logs
if ( ! -e $OUT_ROOT ) mkdir -p $OUT_ROOT

# standard settings
setenv SMK_SOURCE M
setenv PROMPTFLAG N

setenv IOAPI_GRIDNAME_1 $REGION_IOAPI_GRIDNAME

# define directories based on assigns file
setenv IOAPIDIR $SMK_HOME/ioapi/Linux3_x86_64ifort
setenv SMKROOT $SMK_HOME/smoke3.6
setenv SCRIPTS $SMKROOT/scripts
setenv SMK_BIN $SMKROOT/Linux3_x86_64ifort

# set start and end dates
set year = `echo $EPI_STDATE_TIME | cut -d\- -f1`
set month = `echo $EPI_STDATE_TIME | cut -d\- -f2`
set day   = `echo $EPI_STDATE_TIME | cut -d\- -f3 | cut -d" " -f1`
setenv STDATE `$IOAPIDIR/juldate $month $day $year | grep $year | cut -d, -f2`

set year_end = `echo $EPI_ENDATE_TIME | cut -d\- -f1`
set month_end = `echo $EPI_ENDATE_TIME | cut -d\- -f2`
set day_end   = `echo $EPI_ENDATE_TIME | cut -d\- -f3 | cut -d" " -f1`
setenv ENDATE `$IOAPIDIR/juldate $month_end $day_end $year_end | grep $year_end | cut -d, -f2`

# create METLIST file
setenv METLIST $IMD_ROOT/metlist.txt
if ( -e $METLIST ) /bin/rm -rf $METLIST
ls $MET_ROOT/$REGION_ABBREV/mcip_out/METCOMBO* > $METLIST

# set surrogates path
set srgpro_temp = `$SCRIPTS/run/path_parser.py $SRGPRO`
setenv SRGPRO_PATH ${srgpro_temp}/

# set output files
setenv SMOKE_OUTFILE $OUT_ROOT/SMOKE_${REGION_ABBREV}_${STDATE}_${ENDATE}.ncf
setenv MOVES_OUTFILE $OUT_ROOT/MOVES_${REGION_ABBREV}_${STDATE}_${ENDATE}.txt
setenv MOVES_RH_OUTFILE $OUT_ROOT/MOVES_RH_${REGION_ABBREV}_${STDATE}_${ENDATE}.txt
setenv LOGFILE $IMD_ROOT/logs/met4moves_${REGION_ABBREV}_${STDATE}_${ENDATE}.log

# clean up old outputs
if ( -e $SMOKE_OUTFILE ) /bin/rm -rf $SMOKE_OUTFILE
if ( -e $MOVES_OUTFILE ) /bin/rm -rf $MOVES_OUTFILE
if ( -e $MOVES_RH_OUTFILE ) /bin/rm -rf $MOVES_RH_OUTFILE
if ( -e $LOGFILE ) /bin/rm -rf $LOGFILE

$EMF_CLIENT -k $EMF_JOBKEY -m "Running Met4moves" -x $SMK_BIN/met4moves
$SMK_BIN/met4moves

# remove temporary output file
rm -f TMP_COMBINED_SRG.txt

# check for normal completion
$SCRIPTS/run/checklogfile.csh
if ( $status != 0 ) then
  $EMF_CLIENT -k $EMF_JOBKEY -m "ERROR: detected in Met4moves" -t "e"
  exit( 1 )
endif

# register output files
$EMF_CLIENT -k $EMF_JOBKEY -F $SMOKE_OUTFILE -T "Meteorology Temperature Profiles (External)"
$EMF_CLIENT -k $EMF_JOBKEY -F $MOVES_OUTFILE -T "MOVES2014 Meteorology RPP"
$EMF_CLIENT -k $EMF_JOBKEY -F $MOVES_RH_OUTFILE -T "MOVES2014 Meteorology RPD, RPV, RPH"

$EMF_CLIENT -k $EMF_JOBKEY -s "Completed"
