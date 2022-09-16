# SMOKE-MOVES

SMOKE-MOVES is a set of methodologies and software tools to help use output from MOVES3 as inputs to SMOKE. [Section 3.2](https://www.cmascenter.org/smoke/documentation/4.9/html/ch03s02.html) of the SMOKE User's Manual describes the various scripts and files that make up SMOKE-MOVES.

The current version of SMOKE-MOVES creates run specification files designed for use in MOVES3.0.0 through MOVES3.0.3. This version of SMOKE-MOVES hasn't been tested in MOVES3.0.4 and may not work due to the removal of chemical mechanism outputs in MOVES.

<!-- If you would like to download a package of SMOKE-MOVES scripts and inputs used in EPA's modeling platform, please visit the EPA's [Emissions Modeling Platforms](https://www.epa.gov/air-emissions-modeling/emissions-modeling-platforms) page.

For information on installing MOVES2014a on Linux, read the [wiki page](https://github.com/CEMPD/SMOKE-MOVES/wiki/Installing-MOVES2014a-on-Linux). -->

## SMOKE-MOVES Processing Scripts

The latest version of SMOKE-MOVES can be downloaded as a [zip archive](https://github.com/CEMPD/SMOKE-MOVES/archive/master.zip). This package assumes a base directory of `/opt/SMOKE-MOVES/`. Update the following input files with your installation location:

```
inputs/countyrep.in
inputs/06001/control.in
```

Also, set the location of your MOVES installation in `inputs/06001/control.in`:

`MOVESHOME      = /opt/MOVES2014`

Generate import scripts and runspec files:

`> scripts/runspec_generator.pl inputs/06001/control.in inputs/countyrep.in -csh`

Import custom county data:

`> csh runspec_files/06001/06001_2011importer.csh`

Run MOVES:

`> csh runspec_files/06001/06001_2011runspec.csh`

After MOVES finishes running, generate the emission factor files. Note that MOVES3 can produce rate-per-start and off-network idling emission factors.

```
> mkdir efs
> mkdir efs/06001
```

Rate-per-distance factors:

```
> scripts/moves2smkEF.pl -r RPD \
    --formulas scripts/pollutant_formulas_AQ.txt \
    --proc_agg scripts/process_aggregation.csv \
    runspec_files/06001/06001_2011outputDBs.txt \
    scripts/pollutant_mapping_AQ_CB05.csv efs/06001/
```

Rate-per-vehicle factors. If using MOVES3 to generate rate-per-start emission factors, specify the process aggregation file `scripts/process_aggregation_rpv_no_rps.csv`. This will ensure that no start processes are included in the rate-per-vehicle emission factors. The rate-per-start factors will be exported in a separate step.

```
> scripts/moves2smkEF.pl -r RPV \
    --formulas scripts/pollutant_formulas_AQ.txt \
    --proc_agg scripts/process_aggregation_rpv.csv \
    runspec_files/06001/06001_2011outputDBs.txt \
    scripts/pollutant_mapping_AQ_CB05.csv efs/06001/
```

Rate-per-profile factors:

```
> scripts/moves2smkEF.pl -r RPP \
    --formulas scripts/pollutant_formulas_AQ.txt \
    --proc_agg scripts/process_aggregation.csv \
    runspec_files/06001/06001_2011outputDBs.txt \
    scripts/pollutant_mapping_AQ_CB05.csv efs/06001/
```

Rate-per-hour factors:

```
> scripts/moves2smkEF.pl -r RPH \
    --formulas scripts/pollutant_formulas_AQ.txt \
    --proc_agg scripts/process_aggregation.csv \
    runspec_files/06001/06001_2011outputDBs.txt \
    scripts/pollutant_mapping_AQ_CB05.csv efs/06001/
```

MOVES3 only, rate-per-start factors:

```
> scripts/moves2smkEF.pl -r RPS \
    --formulas scripts/pollutant_formulas_AQ.txt \
    --proc_agg scripts/process_aggregation.csv \
    runspec_files/06001/06001_2011outputDBs.txt \
    scripts/pollutant_mapping_AQ_CB05.csv efs/06001/
```

MOVES3 only, off-network idling factors:

```
> scripts/moves2smkEF.pl -r RPHO \
    --formulas scripts/pollutant_formulas_AQ.txt \
    --proc_agg scripts/process_aggregation_rpho.csv \
    runspec_files/06001/06001_2011outputDBs.txt \
    scripts/pollutant_mapping_AQ_CB05.csv efs/06001/
```

## Data sources

### County-specific MOVES data

Previously, SMOKE-MOVES loaded county-specific data into MOVES via CSV files. Now, the input file `inputs/countyrep.in` specifies the database to use for each representative county. For example:

```
<REPCOUNTY>
FIPS=06001
CDB=c06001y2011_20150522
<ENDREPCOUNTY>
```

Default county input databases are available for download from the EPA. Note that the database schema for the county inputs changed with the release of MOVES3.

For MOVES2014:

- 2016: ftp://newftp.epa.gov/Air/emismod/2016/v1/2016emissions/repCountyCDBs_2016_20190717.zip
- 2017: ftp://newftp.epa.gov/air/nei/2017/doc/supporting_data/onroad/CDBs_for_rep_counties/

The 2016 platform also has county databases for 2020, 2023, and 2028. For 2017, county databases are also available for all inventory counties.

For MOVES3:
- 2017: ftp://newftp.epa.gov/Air/MOVES3/2017/2017repCDBs_20201209.zip

### Meteorology files

```
inputs/MOVES_DAILY_12US2_2011001-2011365.txt
inputs/MOVES_RH_DAILY_12US2_2011001-2011365.txt
```

National versions of these [Met4moves](https://www.cmascenter.org/smoke/documentation/4.8.1/html/ch06s07.html) output files are available from the EPA at ftp://newftp.epa.gov/Air/emismod/2016/v1/ancillary_data/ge_dat_for_2016v1_other_31oct2019.zip

Example Met4moves scripts are available from the EPA at ftp://newftp.epa.gov/Air/emismod/2017/met4moves_example_scripts_2017.zip
