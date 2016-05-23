#!/usr/bin/perl
#
# Filename   : moves2smk_nrinv.pl
# Author     : Catherine Seppanen, UNC
# Version    : 1.0
# Description: Generate FF10 nonroad inventories from NONROAD MySQL tables.
#
# Usage: moves2smk_nrinv.pl <ConfigurationFile>
# where
#   ConfigurationFile - text file containing configuration parameters like database connection information, pollutant mapping, output file, and other options

use strict;
use warnings 'FATAL' => 'all';
use DBI;

#================================================================================================
# Read configuration file

(scalar(@ARGV) == 1) or die <<END;
Usage: $0 <ConfigurationFile>
END

my ($configFile) = @ARGV;

my $configFH;
open($configFH, "<", $configFile) or die "Unable to open configuration file: $configFile\n";

my %config;
my $lineNo = 0;
while (my $line = <$configFH>)
{
  $lineNo++;
  # remove newlines, comments, leading and trailing whitespace
  chomp($line);
  $line =~ s/#.*//;
  $line =~ s/^\s+//;
  $line =~ s/\s+$//;
  next unless length($line);
  
  my ($var, $value) = split(/\s*=\s*/, $line, 2);
  unless (defined $value)
  {
    warn "Skipping invalid line $lineNo in configuration file (missing equals sign)\n";
    next;
  }
  $config{uc($var)} = $value;
}

close($configFH);

#================================================================================================
# Check required configuration parameters

unless (exists $config{'POLLUTANTS'} && length($config{'POLLUTANTS'}))
{
  die "Missing pollutant mapping file (POLLUTANTS) in configuration file\n";
}

unless (exists $config{'OUTPUT'} && length($config{'OUTPUT'}))
{
  die "Missing output file (OUTPUT) in configuration file\n";
}

unless (exists $config{'DB_NAME'} && length($config{'DB_NAME'}))
{
  die "Missing MySQL database name (DB_NAME) in configuration file\n";
}

#================================================================================================
# Read file mapping MOVES pollutant IDs to output names

my $pollutantFile = $config{'POLLUTANTS'};

my $pollFH;
open($pollFH, "<", $pollutantFile) or die "Unable to open pollutant mapping file: $pollutantFile\n";

my %keptPollMap;   # map of MOVES IDs to pollutant names
my %keptPollNames; # list of valid pollutant names

while (my $line = <$pollFH>)
{
  chomp($line);

  # example lines:
  #   1,"Total Gaseous Hydrocarbons","THC_INV"
  #   20,"Benzene","71432"
  # notes:
  #   NONROAD pollutant ID (column 1) must be integer, not in quotes
  #   MOVES2014 and SMOKE pollutant names (columns 2 and 3) must be in quotes
  my ($pollID, $pollName) = ($line =~ /^(\d+),"[^"]+","([^"]+)"/);
  next unless $pollID && $pollName; # skip lines without data
  
  $keptPollMap{$pollID} = $pollName;
  $keptPollNames{$pollName} = 1;
}

close($pollFH);

# build case statement to convert pollutant IDs to names
my $pollSql = 'CASE pollutantID ';
while (my ($pollID, $pollName) = each %keptPollMap)
{
  $pollSql .= "WHEN $pollID THEN '$pollName' ";
}
$pollSql .= 'ELSE NULL END';

# check if speciation profile IDs should be appended to names
if (exists $config{'USE_SPC_ID'} && $config{'USE_SPC_ID'} eq 'Y')
{
  $pollSql .= ", IFNULL(nrtogspecprofileid, '')";
}

#================================================================================================
# Read process mapping file

my ($procSql, $emisTypeSql) = ('', '');

if (exists $config{'PROCESSES'} && length($config{'PROCESSES'}))
{
  my $procFile = $config{'PROCESSES'};
  
  my $procFH;
  open($procFH, "<", $procFile) or die "Unable to open process mapping file: $procFile\n";
  
  while (my $line = <$procFH>)
  {
    chomp($line);
    
    my ($procID, $procPrefix, $emisTypeCode) = ($line =~ /^(\d\d?),"?([^"]+)"?,"?([^"]+)"?,/);
    next unless $procID && $procPrefix && $emisTypeCode; # skip lines without data
    
    $procSql .= "WHEN $procID THEN '$procPrefix' ";
    $emisTypeSql .= "WHEN $procID THEN '$emisTypeCode' ";
  }
  
  close($procFH);
  
  if ($procSql)
  {
    $procSql = "CASE processID $procSql ELSE NULL END,";
    $emisTypeSql = "CASE processID $emisTypeSql ELSE NULL END";
  }
}

unless ($emisTypeSql)
{
  $emisTypeSql = '""';
}

#================================================================================================
# Check output file

my $outFile = $config{'OUTPUT'};

my $outFH;
open($outFH, ">", $outFile) or die "Unable to open output file: $outFile\n";

#================================================================================================
# Open database connection

my $dbHost = exists $config{'DB_HOST'} ? $config{'DB_HOST'} : "localhost";
my $dbUser = exists $config{'DB_USER'} ? $config{'DB_USER'} : "";
my $dbPass = exists $config{'DB_PASS'} ? $config{'DB_PASS'} : "";
my $dbName = $config{'DB_NAME'};
my $dbTable = "allequip";
if (exists $config{'DB_TABLE'} && length($config{'DB_TABLE'}))
{
  $dbTable = $config{'DB_TABLE'};
}

my $connectionInfo = "dbi:mysql:$dbName;$dbHost";
my $dbh = DBI->connect($connectionInfo, $dbUser, $dbPass) or die "Could not connect to database: $dbName\n";

# check that table exists
my $sth = $dbh->prepare("SELECT 1 FROM $dbTable");
$sth->execute() or die "Could not query database table: $dbTable\n";

# remove temporary table if it exists
$sth = $dbh->prepare(<<END);
DROP TABLE IF EXISTS ${dbTable}_smoke
END

$sth->execute() or die 'Error executing query: ' . $sth->errstr;

#================================================================================================
# Create temporary table with aggregated monthly emissions 

my $sql = <<END;
CREATE TABLE ${dbTable}_smoke
SELECT yearID, countyID, SCC,
       CONCAT($procSql
              $pollSql) AS pollutant,
       $emisTypeSql AS emisType,
       SUM(IF(monthID =  1, monthemiss, NULL)) AS jan_value,
       SUM(IF(monthID =  2, monthemiss, NULL)) AS feb_value,
       SUM(IF(monthID =  3, monthemiss, NULL)) AS mar_value,
       SUM(IF(monthID =  4, monthemiss, NULL)) AS apr_value,
       SUM(IF(monthID =  5, monthemiss, NULL)) AS may_value,
       SUM(IF(monthID =  6, monthemiss, NULL)) AS jun_value,
       SUM(IF(monthID =  7, monthemiss, NULL)) AS jul_value,
       SUM(IF(monthID =  8, monthemiss, NULL)) AS aug_value,
       SUM(IF(monthID =  9, monthemiss, NULL)) AS sep_value,
       SUM(IF(monthID = 10, monthemiss, NULL)) AS oct_value,
       SUM(IF(monthID = 11, monthemiss, NULL)) AS nov_value,
       SUM(IF(monthID = 12, monthemiss, NULL)) AS dec_value,
       SUM(monthemiss) AS ann_value
  FROM $dbTable
 GROUP BY SCC, pollutant
HAVING pollutant IS NOT NULL
END
$sth = $dbh->prepare($sql);
$sth->execute() or die 'Error executing query: ' . $sth->errstr;

#================================================================================================
# Output emissions inventory

$sql = <<END;
SELECT 'US' AS country,
       countyID AS fips,
       '' AS tribal_code,
       '' AS census_tract,
       '' AS shape_id,
       SCC,
       emisType,
       pollutant,
       ann_value,
       '' AS ann_pct_red,
       '' AS control_ids,
       '' AS control_measures,
       '' AS current_cost,
       '' AS cumulative_cost,
       '' AS projection_factor,
       '' AS reg_codes,
       '' AS calc_method,
       yearID,
       '' AS date_updated,
       '' AS data_set_id,
       jan_value,
       feb_value,
       mar_value,
       apr_value,
       may_value,
       jun_value,
       jul_value,
       aug_value,
       sep_value,
       oct_value,
       nov_value,
       dec_value,
       '' AS jan_pctred,
       '' AS feb_pctred,
       '' AS mar_pctred,
       '' AS apr_pctred,
       '' AS may_pctred,
       '' AS jun_pctred,
       '' AS jul_pctred,
       '' AS aug_pctred,
       '' AS sep_pctred,
       '' AS oct_pctred,
       '' AS nov_pctred,
       '' AS dec_pctred,
       '' AS comment
  FROM ${dbTable}_smoke
 ORDER BY SCC, pollutant
END
$sth = $dbh->prepare($sql);
$sth->execute() or die 'Error executing query: ' . $sth->errstr;

while (my @data = $sth->fetchrow_array())
{
  print $outFH join(',', map { defined($_) ? $_ : '' } @data) . "\n";
}

close($outFH);

#================================================================================================
# Clean up temporary tables

unless (exists $config{'DEBUG'} && $config{'DEBUG'} eq 'Y')
{
  $sth = $dbh->prepare(<<END);
DROP TABLE IF EXISTS ${dbTable}_smoke
END

  $sth->execute() or die 'Error executing query: ' . $sth->errstr;
}
