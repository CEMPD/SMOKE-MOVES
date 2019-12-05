#!/usr/bin/perl
#
# Filename   : ExtractActivity_nr.pl
# Author     : Catherine Seppanen, UNC
# Description: Dump the movesactivityoutput table after running MOVES nonroad
#
# Usage: ExtractActivity_nr.pl <ConfigurationFile>
# where
#   ConfigurationFile - text file containing configuration parameters like database connection information and output file

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

unless (exists $config{'ACTOUTPUT'} && length($config{'ACTOUTPUT'}))
{
  die "Missing output file (ACTOUTPUT) in configuration file\n";
}

unless (exists $config{'DB_NAME'} && length($config{'DB_NAME'}))
{
  die "Missing MySQL database name (DB_NAME) in configuration file\n";
}

#================================================================================================
# Check output file

my $outFile = $config{'ACTOUTPUT'};

my $outFH;
open($outFH, ">", $outFile) or die "Unable to open output file: $outFile\n";

#================================================================================================
# Open database connection

my $dbHost = exists $config{'DB_HOST'} ? $config{'DB_HOST'} : "localhost";
my $dbUser = exists $config{'DB_USER'} ? $config{'DB_USER'} : "";
my $dbPass = exists $config{'DB_PASS'} ? $config{'DB_PASS'} : "";
my $dbName = $config{'DB_NAME'};
my $dbTable = "movesactivityoutput";

my $connectionInfo = "dbi:mysql:$dbName;$dbHost";
my $dbh = DBI->connect($connectionInfo, $dbUser, $dbPass) or die "Could not connect to database: $dbName\n";

# check that table exists
my $sth = $dbh->prepare("SELECT 1 FROM $dbTable");
$sth->execute() or die "Could not query database table: $dbTable\n";

#================================================================================================
# Output activity data

my @fields = (
'MOVESRunID',
'iterationID',
'yearID',
'monthID',
'dayID',
'hourID',
'stateID',
'countyID',
'zoneID',
'linkID',
'sourceTypeID',
'regClassID',
'fuelTypeID',
'modelYearID',
'roadTypeID',
'SCC',
'engTechID',
'sectorID',
'hpID',
'activityTypeID',
'activity',
'activityMean',
'activitySigma');

print $outFH join(',', @fields) . "\n";

my $sql = "SELECT " . join(',', @fields) . " FROM ${dbTable}";
$sth = $dbh->prepare($sql);
$sth->execute() or die 'Error executing query: ' . $sth->errstr;

while (my @data = $sth->fetchrow_array())
{
  print $outFH join(',', map { defined($_) ? $_ : '' } @data) . "\n";
}

close($outFH);
