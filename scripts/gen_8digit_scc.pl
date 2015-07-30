#!/usr/bin/perl
#
# Filename   : gen_8digit_scc_v1.0.pl
# Author     : Catherine Seppanen, UNC
# Version    : 1.0
# Description: Generate mapping of 8-digit SCCs to aggregated SCCs.
#
# Usage: gen_8digit_scc_v1.0.pl --fuel_agg <FuelTypeMappingFile>
#                               --src_agg <SourceTypeMappingFile>
#                               --road_agg <RoadTypeMappingFile>
#                               --proc_agg <ProcessTypeMappingFile>
# where
#   FuelTypeMappingFile - list of MOVES fuel type IDs and corresponding aggregated fuel type ID
#   SourceTypeMappingFile - list of MOVES source type IDs and corresponding aggregated source type ID
#   RoadTypeMappingFile - list of MOVES road type IDs and corresponding aggregated road type ID
#   ProcessTypeMappingFile - list of MOVES process type IDs and corresponding aggregated process type ID

use strict;
use warnings 'FATAL' => 'all';
use Getopt::Long;

my ($fuelAggFile, $srcAggFile, $roadAggFile, $procAggFile) = '';
GetOptions('fuel_agg=s' => \$fuelAggFile, 
           'src_agg=s' => \$srcAggFile, 
           'road_agg=s' => \$roadAggFile, 
           'proc_agg=s' => \$procAggFile);

my @codes = ('22');
for my $fileInfo (['fuel', $fuelAggFile], 
                  ['source', $srcAggFile], 
                  ['road', $roadAggFile], 
                  ['process', $procAggFile])
{
  my ($type, $file) = @$fileInfo;
  die "No $type type file specified\n" unless $file;
  
  my $fileHandle;
  open ($fileHandle, "<", $file) or die "Unable to open $type type aggregation file: $file\n";
  
  my @tmpCodes;
  my %seen;
  while (my $line = <$fileHandle>)
  {
    chomp($line);
  
    my ($inputID, $outputID) = ($line =~ /^(\d\d?),(\d\d?),/);
    next unless $inputID && $outputID; # skip lines without data

    $inputID = '0' . $inputID if length($inputID) == 1;
    $outputID = '0' . $outputID if length($outputID) == 1;
    
    next if $seen{$outputID};
    $seen{$outputID} = 1;

    for my $base (@codes)
    {
      push(@tmpCodes, $base . $outputID);
    }
  }
  
  close($fileHandle);
  
  @codes = @tmpCodes;
}

print '"Full SCC","Abbreviated SCC"' . "\n";
for my $scc (@codes)
{
  print $scc . ',' . substr($scc, 0, 8) . "00\n";
}

