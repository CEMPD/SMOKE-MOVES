#!/bin/csh -f

## log w/ EMF server that script is running
$EMF_CLIENT -k $EMF_JOBKEY -s "Running"

## check command line arguments
if ($#argv != 1) then
  $EMF_CLIENT -k $EMF_JOBKEY -m "ERROR: MOVES script did not receive arguments" -t "e"
  exit(1)
endif

set ref_county = $1

## set up directories
set input_dir = `dirname $COUNTY_DB`

if (! -d $INTERMED_ROOT) then
  mkdir $INTERMED_ROOT
endif

set runspec_dir = $INTERMED_ROOT/$ref_county
if (! -d $runspec_dir) then
  mkdir $runspec_dir
endif

if (! -d $OUT_ROOT) then
  mkdir $OUT_ROOT
endif

set output_dir = $OUT_ROOT/$ref_county
if (! -d $output_dir) then
  mkdir $output_dir
endif

## create countyrep.in file
cat <<EOT > $runspec_dir/countyrep.in
<REPCOUNTY>
FIPS=$ref_county
AGE=$input_dir/agedistribution.csv
IM=$input_dir/imcoverage.csv
FUELSUPPLY=$input_dir/fuelsupply.csv
FUELFORM=$input_dir/fuelformulation.csv
FUELUSAGE=$input_dir/fuelusage.csv
FUELAVFT=$input_dir/fuelavft.csv
POP=$input_dir/population.csv
HPMSVMT=$input_dir/hpmsvtypeyear.csv
<ENDREPCOUNTY>
EOT

## extract reference county from meteorology files
grep -v ^0 $METFILE > $runspec_dir/METFILE.txt
grep ^0${ref_county} $METFILE >> $runspec_dir/METFILE.txt

grep -v ^0 $RPMETFILE > $runspec_dir/RPMETFILE.txt
grep ^0${ref_county} $RPMETFILE >> $runspec_dir/RPMETFILE.txt

## create control.in file
cat <<EOT > $runspec_dir/control.in
DBHOST         = localhost
MOVESHOME      = $MOVES_ROOT
BATCHRUN       = $ref_county
OUTDIR         = $runspec_dir/
MODELYEAR      = $BASE_YEAR
POLLUTANTS     = OZONE, TOXICS, PM, GHG
DAYOFWEEK      = WEEKDAY, WEEKEND
METFILE        = $runspec_dir/METFILE.txt
RPMETFILE      = $runspec_dir/RPMETFILE.txt
EOT

## link dummy data files
rm -f $runspec_dir/dummy_avgspeeddistribution.csv
ln -s $input_dir/avgspeeddistribution.csv $runspec_dir/dummy_avgspeeddistribution.csv
rm -f $runspec_dir/dummy_dayvmtfraction.csv
ln -s $input_dir/dayvmtfraction.csv $runspec_dir/dummy_dayvmtfraction.csv
rm -f $runspec_dir/dummy_hourvmtfraction.csv
ln -s $input_dir/hourvmtfraction.csv $runspec_dir/dummy_hourvmtfraction.csv
rm -f $runspec_dir/dummy_monthvmtfraction.csv
ln -s $input_dir/monthvmtfraction.csv $runspec_dir/dummy_monthvmtfraction.csv
rm -f $runspec_dir/dummy_roadtypedistribution.csv
ln -s $input_dir/roadtypedistribution.csv $runspec_dir/dummy_roadtypedistribution.csv

## generate runspec files for reference county
$SMOKE_MOVES_ROOT/scripts/runspec_generator.pl $runspec_dir/control.in $runspec_dir/countyrep.in -csh

## import county-specific data
set importer = $runspec_dir/${ref_county}_${BASE_YEAR}importer.csh
$EMF_CLIENT -k $EMF_JOBKEY -m "Running county data import" -x $importer
/bin/csh $importer

## run MOVES2014
set runner = $runspec_dir/${ref_county}_${BASE_YEAR}runspec.csh
$EMF_CLIENT -k $EMF_JOBKEY -m "Running MOVES2014" -x $runner
/bin/csh $runner

## generate emission factor files
set dblistfile = $runspec_dir/${ref_county}_${BASE_YEAR}outputDBs.txt
$EMF_CLIENT -k $EMF_JOBKEY -m "Generating rate-per-distance emission factors"
$SMOKE_MOVES_ROOT/scripts/moves2smkEF.pl -u moves -p moves \
  -r RPD \
  --formulas $POLLUTANT_FORMULAS \
  --proc_agg $PROCESS_AGG \
  $dblistfile \
  $POLLUTANT_MAPPING \
  $output_dir

$EMF_CLIENT -k $EMF_JOBKEY -m "Generating rate-per-vehicle emission factors"
$SMOKE_MOVES_ROOT/scripts/moves2smkEF.pl -u moves -p moves \
  -r RPV \
  --formulas $POLLUTANT_FORMULAS \
  --proc_agg $PROCESS_AGG_RPV \
  $dblistfile \
  $POLLUTANT_MAPPING \
  $output_dir

$EMF_CLIENT -k $EMF_JOBKEY -m "Generating rate-per-profile emission factors"
$SMOKE_MOVES_ROOT/scripts/moves2smkEF.pl -u moves -p moves \
  -r RPP \
  --formulas $POLLUTANT_FORMULAS \
  --proc_agg $PROCESS_AGG \
  $dblistfile \
  $POLLUTANT_MAPPING \
  $output_dir

$EMF_CLIENT -k $EMF_JOBKEY -m "Generating rate-per-hour emission factors"
$SMOKE_MOVES_ROOT/scripts/moves2smkEF.pl -u moves -p moves \
  -r RPH \
  --formulas $POLLUTANT_FORMULAS \
  --proc_agg $PROCESS_AGG \
  $dblistfile \
  $POLLUTANT_MAPPING \
  $output_dir

$EMF_CLIENT -k $EMF_JOBKEY -s "Completed"
