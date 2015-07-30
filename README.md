# SMOKE-MOVES
SMOKE-MOVES2014 Processing Scripts

This package assumes a base directory of `/opt/SMOKE-MOVES/`. Update the following input files with your installation location:

```
inputs/countyrep.in
inputs/06001/control.in
```

Also, set the location of your MOVES2014 installation in `inputs/06001/control.in`:

`MOVESHOME      = /opt/MOVES2014`

Generate import scripts and runspec files:

`> scripts/runspec_generator.pl inputs/06001/control.in inputs/countyrep.in -csh`

Import custom county data:

`> runspec_files/06001/06001_2011importer.csh`

Run MOVES2014:

`> runspec_files/06001/06001_2011runspec.csh`

After MOVES finishes running, generate emission factor files:

```
> mkdir efs
> mkdir efs/06001
> scripts/moves2smkEF.pl -r RPD \
    --formulas scripts/pollutant_formulas_AQ.txt \
    --proc_agg scripts/process_aggregation.csv \
    runspec_files/06001/06001_2011outputDBs.txt \
    scripts/pollutant_mapping_AQ_CB05.csv efs/06001/
> scripts/moves2smkEF.pl -r RPV \
    --formulas scripts/pollutant_formulas_AQ.txt \
    --proc_agg scripts/process_aggregation_rpv.csv \
    runspec_files/06001/06001_2011outputDBs.txt \
    scripts/pollutant_mapping_AQ_CB05.csv efs/06001/
> scripts/moves2smkEF.pl -r RPP \
    --formulas scripts/pollutant_formulas_AQ.txt \
    --proc_agg scripts/process_aggregation.csv \
    runspec_files/06001/06001_2011outputDBs.txt \
    scripts/pollutant_mapping_AQ_CB05.csv efs/06001/
> scripts/moves2smkEF.pl -r RPH \
    --formulas scripts/pollutant_formulas_AQ.txt \
    --proc_agg scripts/process_aggregation.csv \
    runspec_files/06001/06001_2011outputDBs.txt \
    scripts/pollutant_mapping_AQ_CB05.csv efs/06001/
```
