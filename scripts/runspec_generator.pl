#!/usr/bin/perl
#
# Filename   : runspec_generator_v1.0.pl
# Author     : Michele Jimenez, ENVIRON International Corp.
# Version    : 0.1
# Description: Generate RunSpec control files input to MOVES2010
#
#  In order to optimize computing times in MOVES2010 generate the
#  fewest number of runs that will produce all the necessary
#  emission factors.
#
#  Environ July   v1.0
# 	RunSpec files generated for:
#	a) on-road operating; rate per distance table
#       b) off-network processes; rate per vehicle table
#	c) vapor venting off-network; rate per profile table
#
#  UNC               17 Aug  v0.2 : Modelyear output to NO, roadtype and sourceusetype to NO, 
#                                   onroadscc output to Yes.
#  Huiyan (NESCAUM)  18 Oct  v0.3 : Removed roadtype=1 for RPD and
#                                   roadtype 2-5 for RPV and RPP
#  Huiyan (NESCAUM)  18 Oct  v0.31: Update not to use negative temperautre to create database name
#  Beidler (CSC)     29 Mar  v0.31: Added VOC and Hg to pollutants and refueling process ids for MOVES 2010b 
#  Beidler (CSC)     18 Jan  v0.32: Change MET input data format to match new MET4MOVES output
#                                   Changed run control format to accomadate both new input file and old
#  C. Allen (CSC)    26 Mar 2013 v0.33: Added support for new gridded format RPP metfiles
#  B.H. Baek (UNC)   16 Apr 2014 : Updated to support MOVES2014
#  C. Allen (CSC)    08 Oct 2014 v1.1: Additional updates to support MOVES2014
#  C. Seppanen (UNC) 23 Mar 2015 v1.2: Revised import XML to use newer <fuel> element
#  C. Seppanen (UNC) 23 Apr 2015 v1.3: Removed references to old external databases in runspecs
#  C. Seppanen (UNC) 30 Jul 2015 v1.4: Added CB6 species
#  C. Seppanen (UNC) 20 Oct 2015 v1.5: Add optional mode selection in control.in
#  C. Seppanen (UNC) 07 Apr 2016 v1.6: Update pollutant groups so prerequisites are included; added METALS option
#  C. Seppanen (UNC) 26 Sep 2017 v1.7: Directly use county databases instead of importing CSV files
#  C. Seppanen (UNC) 31 Aug 2022 v2.0: Updates for MOVES3.0.0
#  C. Seppanen (UNC) 07 Feb 2024 v3.0: Updates for MOVES4
#======================================================================
#= Runspec Generator - a MOVES preprocessor utility
#=
#= Copyright (C) 2010 ENVIRON International Corporation
#=
#= The Runspec Generator is free software; you can redistribute it 
#= and/or modify it under the terms of the GNU General Public License
#= as published by the Free Software Foundation; either version 3
#= of the License, or (at your option) any later version.
#=
#= This utility is distributed in the hope that it will be useful,
#= but WITHOUT ANY WARRANTY; without even the implied warranty of
#= MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#= GNU General Public License for more details.
#=
#= You should have received a copy of the GNU General Public License
#= along with this program.  If not, see <http://www.gnu.org/licenses/>.
#=======================================================================

use strict;
use FileHandle;

($#ARGV >= 1) or die "Usage: runspec_generator.pl RunControlfile RepCounty [-csh]\n";
# input file variables
my ($RunControlFile, $RepCntyFile, $GenCSH, $batchFile, $importBatchFile, $dbListFile, $fileout);

$RunControlFile = $ARGV[0];
$RepCntyFile = $ARGV[1];
$GenCSH = ($#ARGV > 1 && $ARGV[2] eq "-csh") ? 1 : 0;

# run control variables
my ($line, $i, $j, $ip, $ic, $jj, @line);
my ($dbhost, $batchrun, $outdir, $moveshome, $modelyear, $User_polls, $dayofweek, $MetFile, $RPMetFile, $user_modes);
my (@User_polls, @dayofweek, @user_modes);
my ($pollsFlg, $WeekDayFlag, $WeekEndFlag);

# repcounty variables
my ($cntRepCnty, @repFips, @repCDB);

#=========================================================================================================
# Set Parameters
#=========================================================================================================
  
my ( @pollOptions, @pollsListID, @pollsListName);
my ( @pollsByOptionOZONE, @pollsByOptionTOXICS, @pollsByOptionPM, @pollsByOptionGHG, @pollsByOptionMETALS );
my ( @pollsOutList );

@pollsListID = ( 1, 2, 3, 5, 6, 20, 21, 22, 23, 24, 25, 26, 27, 30, 31, 32, 33, 34, 35, 36, 40, 41, 42, 43, 44, 45, 46, 
                51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 
		78, 79, 80, 81, 82, 83, 84, 86, 87, 90, 91, 100, 106, 107, 110, 111, 112, 115, 116, 117, 118, 119, 121, 
		122, 123, 124, 130, 131, 132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142, 143, 144, 145, 146, 168, 169, 170, 
		171, 172, 173, 174, 175, 176, 177, 178, 181, 182, 183, 184, 185, 1000, 1500, 2500, 3000 );

@pollsListName = ("Total Gaseous Hydrocarbons",
                 "Carbon Monoxide (CO)",
                 "Oxides of Nitrogen (NOx)",
                 "Methane (CH4)",
                 "Nitrous Oxide (N2O)",
                 "Benzene",
                 "Ethanol",
                 "MTBE",
                 "Naphthalene particle",
                 "1,3-Butadiene",
                 "Formaldehyde",
                 "Acetaldehyde",
                 "Acrolein",
                 "Ammonia (NH3)",
                 "Sulfur Dioxide (SO2)",
                 "Nitrogen Oxide (NO)",
                 "Nitrogen Dioxide (NO2)",
                 "Nitrous Acid (HONO)",
                 "Nitrate (NO3)",
                 "Ammonium (NH4)",
                 "2,2,4-Trimethylpentane",
                 "Ethyl Benzene",
                 "Hexane",
                 "Propionaldehyde",
                 "Styrene",
                 "Toluene",
                 "Xylene",
                 "Chloride",
                 "Sodium",
                 "Potassium",
                 "Magnesium",
                 "Calcium",
                 "Titanium",
                 "Silicon",
                 "Aluminum",
                 "Iron",
                 "Mercury Elemental Gaseous",
                 "Mercury Divalent Gaseous",
                 "Mercury Particulate",
                 "Arsenic Compounds",
                 "Chromium 6+",
                 "Manganese Compounds",
                 "Nickel Compounds",
                 "Dibenzo(a,h)anthracene particle",
                 "Fluoranthene particle",
                 "Acenaphthene particle",
                 "Acenaphthylene particle",
                 "Anthracene particle",
                 "Benz(a)anthracene particle",
                 "Benzo(a)pyrene particle",
                 "Benzo(b)fluoranthene particle",
                 "Benzo(g,h,i)perylene particle",
                 "Benzo(k)fluoranthene particle",
                 "Chrysene particle",
                 "Non-Methane Hydrocarbons",
                 "Non-Methane Organic Gases",
                 "Fluorene particle",
                 "Indeno(1,2,3,c,d)pyrene particle",
                 "Phenanthrene particle",
                 "Pyrene particle",
                 "Total Organic Gases",
                 "Volatile Organic Compounds",
                 "Atmospheric CO2",
                 "Total Energy Consumption",
                 "Primary Exhaust PM10  - Total",
                 "Primary PM10 - Brakewear Particulate",
                 "Primary PM10 - Tirewear Particulate",
                 "Primary Exhaust PM2.5 - Total",
                 "Organic Carbon",
                 "Elemental Carbon",
                 "Sulfate Particulate",
                 "Primary PM2.5 - Brakewear Particulate",
                 "Primary PM2.5 - Tirewear Particulate",
                 "Composite - NonECPM",
                 "H2O (aerosol)",
                 "CMAQ5.0 Unspeciated (PMOTHR)",
                 "Non-carbon Organic Matter (NCOM)",
                 "Total Organic Matter (TOM)",
                 "Residual PM (NonECNonSO4NonOM)",
                 "1,2,3,7,8,9-Hexachlorodibenzo-p-Dioxin",
                 "Octachlorodibenzo-p-dioxin",
                 "1,2,3,4,6,7,8-Heptachlorodibenzo-p-Dioxin",
                 "Octachlorodibenzofuran",
                 "1,2,3,4,7,8-Hexachlorodibenzo-p-Dioxin",
                 "1,2,3,7,8-Pentachlorodibenzo-p-Dioxin",
                 "2,3,7,8-Tetrachlorodibenzofuran",
                 "1,2,3,4,7,8,9-Heptachlorodibenzofuran",
                 "2,3,4,7,8-Pentachlorodibenzofuran",
                 "1,2,3,7,8-Pentachlorodibenzofuran",
                 "1,2,3,6,7,8-Hexachlorodibenzofuran",
                 "1,2,3,6,7,8-Hexachlorodibenzo-p-Dioxin",
                 "2,3,7,8-Tetrachlorodibenzo-p-Dioxin",
                 "2,3,4,6,7,8-Hexachlorodibenzofuran",
                 "1,2,3,4,6,7,8-Heptachlorodibenzofuran",
                 "1,2,3,4,7,8-Hexachlorodibenzofuran",
                 "1,2,3,7,8,9-Hexachlorodibenzofuran",
                 "Dibenzo(a,h)anthracene gas",
                 "Fluoranthene gas",
                 "Acenaphthene gas",
                 "Acenaphthylene gas",
                 "Anthracene gas",
                 "Benz(a)anthracene gas",
                 "Benzo(a)pyrene gas",
                 "Benzo(b)fluoranthene gas",
                 "Benzo(g,h,i)perylene gas",
                 "Benzo(k)fluoranthene gas",
                 "Chrysene gas",
                 "Fluorene gas",
                 "Indeno(1,2,3,c,d)pyrene gas",
                 "Phenanthrene gas",
                 "Pyrene gas",
                 "Naphthalene gas",
                 "CB05 Mechanism",
                 "CB6CMAQ Mechanism",
                 "CB6AE7 Mechanism",
                 "NonHAPTOG Mechanism");


@pollOptions = ("OZONE", "PM", "TOXICS", "GHG", "METALS");

#  A subset of MOVES2010 pollutants are generated for each user option specified.
#  Taken from the design document of Task4, Table 4.
#  For MOVES2014 edits, C. Allen placed most of the newer pollutants under "TOXICS", except PM species.
#  I don't know how often these pollutant subset options are used in practice.
#  March 2016 - reorganized options and made sure all prerequisites are included for each set;
#    see https://github.com/CEMPD/SMOKE-MOVES/wiki/Runspec-generator-pollutant-options
@pollsByOptionOZONE = (1,2,3,5,20,21,23,24,25,26,27,32,33,34,40,41,42,43,44,45,46,79,80,86,87,185,3000);
@pollsByOptionPM = (1,30,31,35,36,51,52,53,54,55,56,57,58,59,66,91,100,106,107,110,111,112,115,116,117,118,119,121,122,123,124);
@pollsByOptionTOXICS = (1,68,69,70,71,72,73,74,75,76,77,78,79,81,82,83,84,87,111,115,118,119,
130,131,132,133,134,135,136,137,138,139,140,141,142,143,144,145,146,168,169,170,171,172,173,174,175,176,177,178,181,182,183,184);
@pollsByOptionGHG = (1,5,6,90,91);
@pollsByOptionMETALS = (1,60,61,62,63,65,67);

# Process Types ------------------------------------------------------------------
my (@processID, %processName, %PollProc_tablemap);

# Added process 91 for MOVES2014
@processID = (1,2,9,10,11,12,13,15,16,17,18,19,90,91);
$processName{"01"} = "Running Exhaust";
$processName{"02"} = "Start Exhaust";
$processName{"09"} = "Brakewear";
$processName{"10"} = "Tirewear"; 
$processName{"11"} = "Evap Permeation";
$processName{"12"} = "Evap Fuel Vapor Venting"; 
$processName{"13"} = "Evap Fuel Leaks"; 
$processName{"15"} = "Crankcase Running Exhaust";
$processName{"16"} = "Crankcase Start Exhaust"; 
$processName{"17"} = "Crankcase Extended Idle Exhaust"; 
$processName{"18"} = "Refueling Displacement Vapor Loss";
$processName{"19"} = "Refueling Spillage Loss";
$processName{"90"} = "Extended Idle Exhaust";
$processName{"91"} = "Auxiliary Power Exhaust";

# Process Types ------------------------------------------------------------------
# Table to map pollutant-process IDs to the output runspec files by EF table type
# Pollutant.Process reference - process is the last two characters of the code
# Binary: 1000 = rate/distance   100 = rate/vehicle   10 = rate/profile   1 = r/d evap
# Rebuilt from scratch for MOVES2014 based on sample runspecs provided by Harvey Michaels, OTAQ

$PollProc_tablemap{"101"} = "1000";
$PollProc_tablemap{"102"} = "0100";
$PollProc_tablemap{"111"} = "0101";
$PollProc_tablemap{"112"} = "0011";
$PollProc_tablemap{"113"} = "0101";
$PollProc_tablemap{"115"} = "1000";
$PollProc_tablemap{"116"} = "0100";
$PollProc_tablemap{"117"} = "0100";
$PollProc_tablemap{"118"} = "0001";
$PollProc_tablemap{"119"} = "0001";
$PollProc_tablemap{"190"} = "0100";
$PollProc_tablemap{"191"} = "0100";
$PollProc_tablemap{"201"} = "1000";
$PollProc_tablemap{"202"} = "0100";
$PollProc_tablemap{"215"} = "1000";
$PollProc_tablemap{"216"} = "0100";
$PollProc_tablemap{"217"} = "0100";
$PollProc_tablemap{"290"} = "0100";
$PollProc_tablemap{"291"} = "0100";
$PollProc_tablemap{"301"} = "1000";
$PollProc_tablemap{"302"} = "0100";
$PollProc_tablemap{"315"} = "1000";
$PollProc_tablemap{"316"} = "0100";
$PollProc_tablemap{"317"} = "0100";
$PollProc_tablemap{"390"} = "0100";
$PollProc_tablemap{"391"} = "0100";
$PollProc_tablemap{"501"} = "1000";
$PollProc_tablemap{"502"} = "0100";
$PollProc_tablemap{"515"} = "1000";
$PollProc_tablemap{"516"} = "0100";
$PollProc_tablemap{"517"} = "0100";
$PollProc_tablemap{"590"} = "0100";
$PollProc_tablemap{"591"} = "0100";
$PollProc_tablemap{"601"} = "1000";
$PollProc_tablemap{"602"} = "0100";
$PollProc_tablemap{"615"} = "1000";
$PollProc_tablemap{"616"} = "0100";
$PollProc_tablemap{"2001"} = "1000";
$PollProc_tablemap{"2002"} = "0100";
$PollProc_tablemap{"2011"} = "0101";
$PollProc_tablemap{"2012"} = "0011";
$PollProc_tablemap{"2013"} = "0101";
$PollProc_tablemap{"2015"} = "1000";
$PollProc_tablemap{"2016"} = "0100";
$PollProc_tablemap{"2017"} = "0100";
$PollProc_tablemap{"2018"} = "0001";
$PollProc_tablemap{"2019"} = "0001";
$PollProc_tablemap{"2090"} = "0100";
$PollProc_tablemap{"2091"} = "0100";
$PollProc_tablemap{"2101"} = "1000";
$PollProc_tablemap{"2102"} = "0100";
$PollProc_tablemap{"2111"} = "0101";
$PollProc_tablemap{"2112"} = "0011";
$PollProc_tablemap{"2113"} = "0101";
$PollProc_tablemap{"2115"} = "1000";
$PollProc_tablemap{"2116"} = "0100";
$PollProc_tablemap{"2118"} = "0001";
$PollProc_tablemap{"2119"} = "0001";
$PollProc_tablemap{"2201"} = "1000";
$PollProc_tablemap{"2202"} = "0100";
$PollProc_tablemap{"2211"} = "0101";
$PollProc_tablemap{"2212"} = "0011";
$PollProc_tablemap{"2213"} = "0101";
$PollProc_tablemap{"2215"} = "1000";
$PollProc_tablemap{"2216"} = "0100";
$PollProc_tablemap{"2218"} = "0001";
$PollProc_tablemap{"2219"} = "0001";
$PollProc_tablemap{"2301"} = "1000";
$PollProc_tablemap{"2302"} = "0100";
$PollProc_tablemap{"2315"} = "1000";
$PollProc_tablemap{"2316"} = "0100";
$PollProc_tablemap{"2317"} = "0100";
$PollProc_tablemap{"2390"} = "0100";
$PollProc_tablemap{"2391"} = "0100";
$PollProc_tablemap{"2401"} = "1000";
$PollProc_tablemap{"2402"} = "0100";
$PollProc_tablemap{"2415"} = "1000";
$PollProc_tablemap{"2416"} = "0100";
$PollProc_tablemap{"2417"} = "0100";
$PollProc_tablemap{"2490"} = "0100";
$PollProc_tablemap{"2491"} = "0100";
$PollProc_tablemap{"2501"} = "1000";
$PollProc_tablemap{"2502"} = "0100";
$PollProc_tablemap{"2515"} = "1000";
$PollProc_tablemap{"2516"} = "0100";
$PollProc_tablemap{"2517"} = "0100";
$PollProc_tablemap{"2590"} = "0100";
$PollProc_tablemap{"2591"} = "0100";
$PollProc_tablemap{"2601"} = "1000";
$PollProc_tablemap{"2602"} = "0100";
$PollProc_tablemap{"2615"} = "1000";
$PollProc_tablemap{"2616"} = "0100";
$PollProc_tablemap{"2617"} = "0100";
$PollProc_tablemap{"2690"} = "0100";
$PollProc_tablemap{"2691"} = "0100";
$PollProc_tablemap{"2701"} = "1000";
$PollProc_tablemap{"2702"} = "0100";
$PollProc_tablemap{"2715"} = "1000";
$PollProc_tablemap{"2716"} = "0100";
$PollProc_tablemap{"2717"} = "0100";
$PollProc_tablemap{"2790"} = "0100";
$PollProc_tablemap{"2791"} = "0100";
$PollProc_tablemap{"3001"} = "1000";
$PollProc_tablemap{"3002"} = "0100";
$PollProc_tablemap{"3015"} = "1000";
$PollProc_tablemap{"3016"} = "0100";
$PollProc_tablemap{"3017"} = "0100";
$PollProc_tablemap{"3090"} = "0100";
$PollProc_tablemap{"3091"} = "0100";
$PollProc_tablemap{"3101"} = "1000";
$PollProc_tablemap{"3102"} = "0100";
$PollProc_tablemap{"3115"} = "1000";
$PollProc_tablemap{"3116"} = "0100";
$PollProc_tablemap{"3117"} = "0100";
$PollProc_tablemap{"3190"} = "0100";
$PollProc_tablemap{"3191"} = "0100";
$PollProc_tablemap{"3201"} = "1000";
$PollProc_tablemap{"3202"} = "0100";
$PollProc_tablemap{"3215"} = "1000";
$PollProc_tablemap{"3216"} = "0100";
$PollProc_tablemap{"3217"} = "0100";
$PollProc_tablemap{"3290"} = "0100";
$PollProc_tablemap{"3291"} = "0100";
$PollProc_tablemap{"3301"} = "1000";
$PollProc_tablemap{"3302"} = "0100";
$PollProc_tablemap{"3315"} = "1000";
$PollProc_tablemap{"3316"} = "0100";
$PollProc_tablemap{"3317"} = "0100";
$PollProc_tablemap{"3390"} = "0100";
$PollProc_tablemap{"3391"} = "0100";
$PollProc_tablemap{"3401"} = "1000";
$PollProc_tablemap{"3402"} = "0100";
$PollProc_tablemap{"3415"} = "1000";
$PollProc_tablemap{"3416"} = "0100";
$PollProc_tablemap{"3417"} = "0100";
$PollProc_tablemap{"3490"} = "0100";
$PollProc_tablemap{"3491"} = "0100";
$PollProc_tablemap{"3501"} = "1000";
$PollProc_tablemap{"3502"} = "0100";
$PollProc_tablemap{"3515"} = "1000";
$PollProc_tablemap{"3516"} = "0100";
$PollProc_tablemap{"3517"} = "0100";
$PollProc_tablemap{"3590"} = "0100";
$PollProc_tablemap{"3591"} = "0100";
$PollProc_tablemap{"3601"} = "1000";
$PollProc_tablemap{"3602"} = "0100";
$PollProc_tablemap{"3615"} = "1000";
$PollProc_tablemap{"3616"} = "0100";
$PollProc_tablemap{"3617"} = "0100";
$PollProc_tablemap{"3690"} = "0100";
$PollProc_tablemap{"3691"} = "0100";
$PollProc_tablemap{"4001"} = "1000";
$PollProc_tablemap{"4002"} = "0100";
$PollProc_tablemap{"4011"} = "0101";
$PollProc_tablemap{"4012"} = "0011";
$PollProc_tablemap{"4013"} = "0101";
$PollProc_tablemap{"4015"} = "1000";
$PollProc_tablemap{"4016"} = "0100";
$PollProc_tablemap{"4017"} = "0100";
$PollProc_tablemap{"4018"} = "0001";
$PollProc_tablemap{"4019"} = "0001";
$PollProc_tablemap{"4090"} = "0100";
$PollProc_tablemap{"4091"} = "0100";
$PollProc_tablemap{"4101"} = "1000";
$PollProc_tablemap{"4102"} = "0100";
$PollProc_tablemap{"4111"} = "0101";
$PollProc_tablemap{"4112"} = "0011";
$PollProc_tablemap{"4113"} = "0101";
$PollProc_tablemap{"4115"} = "1000";
$PollProc_tablemap{"4116"} = "0100";
$PollProc_tablemap{"4117"} = "0100";
$PollProc_tablemap{"4118"} = "0001";
$PollProc_tablemap{"4119"} = "0001";
$PollProc_tablemap{"4190"} = "0100";
$PollProc_tablemap{"4191"} = "0100";
$PollProc_tablemap{"4201"} = "1000";
$PollProc_tablemap{"4202"} = "0100";
$PollProc_tablemap{"4211"} = "0101";
$PollProc_tablemap{"4212"} = "0011";
$PollProc_tablemap{"4213"} = "0101";
$PollProc_tablemap{"4215"} = "1000";
$PollProc_tablemap{"4216"} = "0100";
$PollProc_tablemap{"4217"} = "0100";
$PollProc_tablemap{"4218"} = "0001";
$PollProc_tablemap{"4219"} = "0001";
$PollProc_tablemap{"4290"} = "0100";
$PollProc_tablemap{"4291"} = "0100";
$PollProc_tablemap{"4301"} = "1000";
$PollProc_tablemap{"4302"} = "0100";
$PollProc_tablemap{"4315"} = "1000";
$PollProc_tablemap{"4316"} = "0100";
$PollProc_tablemap{"4317"} = "0100";
$PollProc_tablemap{"4390"} = "0100";
$PollProc_tablemap{"4391"} = "0100";
$PollProc_tablemap{"4401"} = "1000";
$PollProc_tablemap{"4402"} = "0100";
$PollProc_tablemap{"4415"} = "1000";
$PollProc_tablemap{"4416"} = "0100";
$PollProc_tablemap{"4417"} = "0100";
$PollProc_tablemap{"4490"} = "0100";
$PollProc_tablemap{"4491"} = "0100";
$PollProc_tablemap{"4501"} = "1000";
$PollProc_tablemap{"4502"} = "0100";
$PollProc_tablemap{"4511"} = "0101";
$PollProc_tablemap{"4512"} = "0011";
$PollProc_tablemap{"4513"} = "0101";
$PollProc_tablemap{"4515"} = "1000";
$PollProc_tablemap{"4516"} = "0100";
$PollProc_tablemap{"4517"} = "0100";
$PollProc_tablemap{"4518"} = "0001";
$PollProc_tablemap{"4519"} = "0001";
$PollProc_tablemap{"4590"} = "0100";
$PollProc_tablemap{"4591"} = "0100";
$PollProc_tablemap{"4601"} = "1000";
$PollProc_tablemap{"4602"} = "0100";
$PollProc_tablemap{"4611"} = "0101";
$PollProc_tablemap{"4612"} = "0011";
$PollProc_tablemap{"4613"} = "0101";
$PollProc_tablemap{"4615"} = "1000";
$PollProc_tablemap{"4616"} = "0100";
$PollProc_tablemap{"4617"} = "0100";
$PollProc_tablemap{"4618"} = "0001";
$PollProc_tablemap{"4619"} = "0001";
$PollProc_tablemap{"4690"} = "0100";
$PollProc_tablemap{"4691"} = "0100";
$PollProc_tablemap{"5101"} = "1000";
$PollProc_tablemap{"5102"} = "0100";
$PollProc_tablemap{"5115"} = "1000";
$PollProc_tablemap{"5116"} = "0100";
$PollProc_tablemap{"5117"} = "0100";
$PollProc_tablemap{"5190"} = "0100";
$PollProc_tablemap{"5191"} = "0100";
$PollProc_tablemap{"5201"} = "1000";
$PollProc_tablemap{"5202"} = "0100";
$PollProc_tablemap{"5215"} = "1000";
$PollProc_tablemap{"5216"} = "0100";
$PollProc_tablemap{"5217"} = "0100";
$PollProc_tablemap{"5290"} = "0100";
$PollProc_tablemap{"5291"} = "0100";
$PollProc_tablemap{"5301"} = "1000";
$PollProc_tablemap{"5302"} = "0100";
$PollProc_tablemap{"5315"} = "1000";
$PollProc_tablemap{"5316"} = "0100";
$PollProc_tablemap{"5317"} = "0100";
$PollProc_tablemap{"5390"} = "0100";
$PollProc_tablemap{"5391"} = "0100";
$PollProc_tablemap{"5401"} = "1000";
$PollProc_tablemap{"5402"} = "0100";
$PollProc_tablemap{"5415"} = "1000";
$PollProc_tablemap{"5416"} = "0100";
$PollProc_tablemap{"5417"} = "0100";
$PollProc_tablemap{"5490"} = "0100";
$PollProc_tablemap{"5491"} = "0100";
$PollProc_tablemap{"5501"} = "1000";
$PollProc_tablemap{"5502"} = "0100";
$PollProc_tablemap{"5515"} = "1000";
$PollProc_tablemap{"5516"} = "0100";
$PollProc_tablemap{"5517"} = "0100";
$PollProc_tablemap{"5590"} = "0100";
$PollProc_tablemap{"5591"} = "0100";
$PollProc_tablemap{"5601"} = "1000";
$PollProc_tablemap{"5602"} = "0100";
$PollProc_tablemap{"5615"} = "1000";
$PollProc_tablemap{"5616"} = "0100";
$PollProc_tablemap{"5617"} = "0100";
$PollProc_tablemap{"5690"} = "0100";
$PollProc_tablemap{"5691"} = "0100";
$PollProc_tablemap{"5701"} = "1000";
$PollProc_tablemap{"5702"} = "0100";
$PollProc_tablemap{"5715"} = "1000";
$PollProc_tablemap{"5716"} = "0100";
$PollProc_tablemap{"5717"} = "0100";
$PollProc_tablemap{"5790"} = "0100";
$PollProc_tablemap{"5791"} = "0100";
$PollProc_tablemap{"5801"} = "1000";
$PollProc_tablemap{"5802"} = "0100";
$PollProc_tablemap{"5815"} = "1000";
$PollProc_tablemap{"5816"} = "0100";
$PollProc_tablemap{"5817"} = "0100";
$PollProc_tablemap{"5890"} = "0100";
$PollProc_tablemap{"5891"} = "0100";
$PollProc_tablemap{"5901"} = "1000";
$PollProc_tablemap{"5902"} = "0100";
$PollProc_tablemap{"5915"} = "1000";
$PollProc_tablemap{"5916"} = "0100";
$PollProc_tablemap{"5917"} = "0100";
$PollProc_tablemap{"5990"} = "0100";
$PollProc_tablemap{"5991"} = "0100";
$PollProc_tablemap{"6001"} = "1000";
$PollProc_tablemap{"6101"} = "1000";
$PollProc_tablemap{"6201"} = "1000";
$PollProc_tablemap{"6301"} = "1000";
$PollProc_tablemap{"6501"} = "1000";
$PollProc_tablemap{"6601"} = "1000";
$PollProc_tablemap{"6701"} = "1000";
$PollProc_tablemap{"6801"} = "1000";
$PollProc_tablemap{"6802"} = "0100";
$PollProc_tablemap{"6815"} = "1000";
$PollProc_tablemap{"6816"} = "0100";
$PollProc_tablemap{"6817"} = "0100";
$PollProc_tablemap{"6890"} = "0100";
$PollProc_tablemap{"6891"} = "0100";
$PollProc_tablemap{"6901"} = "1000";
$PollProc_tablemap{"6902"} = "0100";
$PollProc_tablemap{"6915"} = "1000";
$PollProc_tablemap{"6916"} = "0100";
$PollProc_tablemap{"6917"} = "0100";
$PollProc_tablemap{"6990"} = "0100";
$PollProc_tablemap{"6991"} = "0100";
$PollProc_tablemap{"7001"} = "1000";
$PollProc_tablemap{"7002"} = "0100";
$PollProc_tablemap{"7015"} = "1000";
$PollProc_tablemap{"7016"} = "0100";
$PollProc_tablemap{"7017"} = "0100";
$PollProc_tablemap{"7090"} = "0100";
$PollProc_tablemap{"7091"} = "0100";
$PollProc_tablemap{"7101"} = "1000";
$PollProc_tablemap{"7102"} = "0100";
$PollProc_tablemap{"7115"} = "1000";
$PollProc_tablemap{"7116"} = "0100";
$PollProc_tablemap{"7117"} = "0100";
$PollProc_tablemap{"7190"} = "0100";
$PollProc_tablemap{"7191"} = "0100";
$PollProc_tablemap{"7201"} = "1000";
$PollProc_tablemap{"7202"} = "0100";
$PollProc_tablemap{"7215"} = "1000";
$PollProc_tablemap{"7216"} = "0100";
$PollProc_tablemap{"7217"} = "0100";
$PollProc_tablemap{"7290"} = "0100";
$PollProc_tablemap{"7291"} = "0100";
$PollProc_tablemap{"7301"} = "1000";
$PollProc_tablemap{"7302"} = "0100";
$PollProc_tablemap{"7315"} = "1000";
$PollProc_tablemap{"7316"} = "0100";
$PollProc_tablemap{"7317"} = "0100";
$PollProc_tablemap{"7390"} = "0100";
$PollProc_tablemap{"7391"} = "0100";
$PollProc_tablemap{"7401"} = "1000";
$PollProc_tablemap{"7402"} = "0100";
$PollProc_tablemap{"7415"} = "1000";
$PollProc_tablemap{"7416"} = "0100";
$PollProc_tablemap{"7417"} = "0100";
$PollProc_tablemap{"7490"} = "0100";
$PollProc_tablemap{"7491"} = "0100";
$PollProc_tablemap{"7501"} = "1000";
$PollProc_tablemap{"7502"} = "0100";
$PollProc_tablemap{"7515"} = "1000";
$PollProc_tablemap{"7516"} = "0100";
$PollProc_tablemap{"7517"} = "0100";
$PollProc_tablemap{"7590"} = "0100";
$PollProc_tablemap{"7591"} = "0100";
$PollProc_tablemap{"7601"} = "1000";
$PollProc_tablemap{"7602"} = "0100";
$PollProc_tablemap{"7615"} = "1000";
$PollProc_tablemap{"7616"} = "0100";
$PollProc_tablemap{"7617"} = "0100";
$PollProc_tablemap{"7690"} = "0100";
$PollProc_tablemap{"7691"} = "0100";
$PollProc_tablemap{"7701"} = "1000";
$PollProc_tablemap{"7702"} = "0100";
$PollProc_tablemap{"7715"} = "1000";
$PollProc_tablemap{"7716"} = "0100";
$PollProc_tablemap{"7717"} = "0100";
$PollProc_tablemap{"7790"} = "0100";
$PollProc_tablemap{"7791"} = "0100";
$PollProc_tablemap{"7801"} = "1000";
$PollProc_tablemap{"7802"} = "0100";
$PollProc_tablemap{"7815"} = "1000";
$PollProc_tablemap{"7816"} = "0100";
$PollProc_tablemap{"7817"} = "0100";
$PollProc_tablemap{"7890"} = "0100";
$PollProc_tablemap{"7891"} = "0100";
$PollProc_tablemap{"7901"} = "1000";
$PollProc_tablemap{"7902"} = "0100";
$PollProc_tablemap{"7911"} = "0101";
$PollProc_tablemap{"7912"} = "0011";
$PollProc_tablemap{"7913"} = "0101";
$PollProc_tablemap{"7915"} = "1000";
$PollProc_tablemap{"7916"} = "0100";
$PollProc_tablemap{"7917"} = "0100";
$PollProc_tablemap{"7918"} = "0001";
$PollProc_tablemap{"7919"} = "0001";
$PollProc_tablemap{"7990"} = "0100";
$PollProc_tablemap{"7991"} = "0100";
$PollProc_tablemap{"8001"} = "1000";
$PollProc_tablemap{"8002"} = "0100";
$PollProc_tablemap{"8011"} = "0101";
$PollProc_tablemap{"8012"} = "0011";
$PollProc_tablemap{"8013"} = "0101";
$PollProc_tablemap{"8015"} = "1000";
$PollProc_tablemap{"8016"} = "0100";
$PollProc_tablemap{"8017"} = "0100";
$PollProc_tablemap{"8018"} = "0001";
$PollProc_tablemap{"8019"} = "0001";
$PollProc_tablemap{"8090"} = "0100";
$PollProc_tablemap{"8091"} = "0100";
$PollProc_tablemap{"8101"} = "1000";
$PollProc_tablemap{"8102"} = "0100";
$PollProc_tablemap{"8115"} = "1000";
$PollProc_tablemap{"8116"} = "0100";
$PollProc_tablemap{"8117"} = "0100";
$PollProc_tablemap{"8190"} = "0100";
$PollProc_tablemap{"8191"} = "0100";
$PollProc_tablemap{"8201"} = "1000";
$PollProc_tablemap{"8202"} = "0100";
$PollProc_tablemap{"8215"} = "1000";
$PollProc_tablemap{"8216"} = "0100";
$PollProc_tablemap{"8217"} = "0100";
$PollProc_tablemap{"8290"} = "0100";
$PollProc_tablemap{"8291"} = "0100";
$PollProc_tablemap{"8301"} = "1000";
$PollProc_tablemap{"8302"} = "0100";
$PollProc_tablemap{"8315"} = "1000";
$PollProc_tablemap{"8316"} = "0100";
$PollProc_tablemap{"8317"} = "0100";
$PollProc_tablemap{"8390"} = "0100";
$PollProc_tablemap{"8391"} = "0100";
$PollProc_tablemap{"8401"} = "1000";
$PollProc_tablemap{"8402"} = "0100";
$PollProc_tablemap{"8415"} = "1000";
$PollProc_tablemap{"8416"} = "0100";
$PollProc_tablemap{"8417"} = "0100";
$PollProc_tablemap{"8490"} = "0100";
$PollProc_tablemap{"8491"} = "0100";
$PollProc_tablemap{"8601"} = "1000";
$PollProc_tablemap{"8602"} = "0100";
$PollProc_tablemap{"8611"} = "0101";
$PollProc_tablemap{"8612"} = "0011";
$PollProc_tablemap{"8613"} = "0101";
$PollProc_tablemap{"8615"} = "1000";
$PollProc_tablemap{"8616"} = "0100";
$PollProc_tablemap{"8617"} = "0100";
$PollProc_tablemap{"8618"} = "0001";
$PollProc_tablemap{"8619"} = "0001";
$PollProc_tablemap{"8690"} = "0100";
$PollProc_tablemap{"8691"} = "0100";
$PollProc_tablemap{"8701"} = "1000";
$PollProc_tablemap{"8702"} = "0100";
$PollProc_tablemap{"8711"} = "0101";
$PollProc_tablemap{"8712"} = "0011";
$PollProc_tablemap{"8713"} = "0101";
$PollProc_tablemap{"8715"} = "1000";
$PollProc_tablemap{"8716"} = "0100";
$PollProc_tablemap{"8717"} = "0100";
$PollProc_tablemap{"8718"} = "0001";
$PollProc_tablemap{"8719"} = "0001";
$PollProc_tablemap{"8790"} = "0100";
$PollProc_tablemap{"8791"} = "0100";
$PollProc_tablemap{"9001"} = "1000";
$PollProc_tablemap{"9002"} = "0100";
$PollProc_tablemap{"9090"} = "0100";
$PollProc_tablemap{"9091"} = "0100";
$PollProc_tablemap{"9101"} = "1000";
$PollProc_tablemap{"9102"} = "0100";
$PollProc_tablemap{"9190"} = "0100";
$PollProc_tablemap{"9191"} = "0100";
$PollProc_tablemap{"10001"} = "1000";
$PollProc_tablemap{"10002"} = "0100";
$PollProc_tablemap{"10015"} = "1000";
$PollProc_tablemap{"10016"} = "0100";
$PollProc_tablemap{"10017"} = "0100";
$PollProc_tablemap{"10090"} = "0100";
$PollProc_tablemap{"10091"} = "0100";
$PollProc_tablemap{"10609"} = "1000";
$PollProc_tablemap{"10710"} = "1000";
$PollProc_tablemap{"11001"} = "1000";
$PollProc_tablemap{"11002"} = "0100";
$PollProc_tablemap{"11015"} = "1000";
$PollProc_tablemap{"11016"} = "0100";
$PollProc_tablemap{"11017"} = "0100";
$PollProc_tablemap{"11090"} = "0100";
$PollProc_tablemap{"11091"} = "0100";
$PollProc_tablemap{"11101"} = "1000";
$PollProc_tablemap{"11102"} = "0100";
$PollProc_tablemap{"11115"} = "1000";
$PollProc_tablemap{"11116"} = "0100";
$PollProc_tablemap{"11117"} = "0100";
$PollProc_tablemap{"11190"} = "0100";
$PollProc_tablemap{"11191"} = "0100";
$PollProc_tablemap{"11201"} = "1000";
$PollProc_tablemap{"11202"} = "0100";
$PollProc_tablemap{"11215"} = "1000";
$PollProc_tablemap{"11216"} = "0100";
$PollProc_tablemap{"11217"} = "0100";
$PollProc_tablemap{"11290"} = "0100";
$PollProc_tablemap{"11291"} = "0100";
$PollProc_tablemap{"11501"} = "1000";
$PollProc_tablemap{"11502"} = "0100";
$PollProc_tablemap{"11515"} = "1000";
$PollProc_tablemap{"11516"} = "0100";
$PollProc_tablemap{"11517"} = "0100";
$PollProc_tablemap{"11590"} = "0100";
$PollProc_tablemap{"11591"} = "0100";
$PollProc_tablemap{"11609"} = "1000";
$PollProc_tablemap{"11710"} = "1000";
$PollProc_tablemap{"11801"} = "1000";
$PollProc_tablemap{"11802"} = "0100";
$PollProc_tablemap{"11815"} = "1000";
$PollProc_tablemap{"11816"} = "0100";
$PollProc_tablemap{"11817"} = "0100";
$PollProc_tablemap{"11890"} = "0100";
$PollProc_tablemap{"11891"} = "0100";
$PollProc_tablemap{"11901"} = "1000";
$PollProc_tablemap{"11902"} = "0100";
$PollProc_tablemap{"11915"} = "1000";
$PollProc_tablemap{"11916"} = "0100";
$PollProc_tablemap{"11917"} = "0100";
$PollProc_tablemap{"11990"} = "0100";
$PollProc_tablemap{"11991"} = "0100";
$PollProc_tablemap{"12101"} = "1000";
$PollProc_tablemap{"12102"} = "0100";
$PollProc_tablemap{"12115"} = "1000";
$PollProc_tablemap{"12116"} = "0100";
$PollProc_tablemap{"12117"} = "0100";
$PollProc_tablemap{"12190"} = "0100";
$PollProc_tablemap{"12191"} = "0100";
$PollProc_tablemap{"12201"} = "1000";
$PollProc_tablemap{"12202"} = "0100";
$PollProc_tablemap{"12215"} = "1000";
$PollProc_tablemap{"12216"} = "0100";
$PollProc_tablemap{"12217"} = "0100";
$PollProc_tablemap{"12290"} = "0100";
$PollProc_tablemap{"12291"} = "0100";
$PollProc_tablemap{"12301"} = "1000";
$PollProc_tablemap{"12302"} = "0100";
$PollProc_tablemap{"12315"} = "1000";
$PollProc_tablemap{"12316"} = "0100";
$PollProc_tablemap{"12317"} = "0100";
$PollProc_tablemap{"12390"} = "0100";
$PollProc_tablemap{"12391"} = "0100";
$PollProc_tablemap{"12401"} = "1000";
$PollProc_tablemap{"12402"} = "0100";
$PollProc_tablemap{"12415"} = "1000";
$PollProc_tablemap{"12416"} = "0100";
$PollProc_tablemap{"12417"} = "0100";
$PollProc_tablemap{"12490"} = "0100";
$PollProc_tablemap{"12491"} = "0100";
$PollProc_tablemap{"13001"} = "1000";
$PollProc_tablemap{"13101"} = "1000";
$PollProc_tablemap{"13201"} = "1000";
$PollProc_tablemap{"13301"} = "1000";
$PollProc_tablemap{"13401"} = "1000";
$PollProc_tablemap{"13501"} = "1000";
$PollProc_tablemap{"13601"} = "1000";
$PollProc_tablemap{"13701"} = "1000";
$PollProc_tablemap{"13801"} = "1000";
$PollProc_tablemap{"13901"} = "1000";
$PollProc_tablemap{"14001"} = "1000";
$PollProc_tablemap{"14101"} = "1000";
$PollProc_tablemap{"14201"} = "1000";
$PollProc_tablemap{"14301"} = "1000";
$PollProc_tablemap{"14401"} = "1000";
$PollProc_tablemap{"14501"} = "1000";
$PollProc_tablemap{"14601"} = "1000";
$PollProc_tablemap{"16801"} = "1000";
$PollProc_tablemap{"16802"} = "0100";
$PollProc_tablemap{"16815"} = "1000";
$PollProc_tablemap{"16816"} = "0100";
$PollProc_tablemap{"16817"} = "0100";
$PollProc_tablemap{"16890"} = "0100";
$PollProc_tablemap{"16891"} = "0100";
$PollProc_tablemap{"16901"} = "1000";
$PollProc_tablemap{"16902"} = "0100";
$PollProc_tablemap{"16915"} = "1000";
$PollProc_tablemap{"16916"} = "0100";
$PollProc_tablemap{"16917"} = "0100";
$PollProc_tablemap{"16990"} = "0100";
$PollProc_tablemap{"16991"} = "0100";
$PollProc_tablemap{"17001"} = "1000";
$PollProc_tablemap{"17002"} = "0100";
$PollProc_tablemap{"17015"} = "1000";
$PollProc_tablemap{"17016"} = "0100";
$PollProc_tablemap{"17017"} = "0100";
$PollProc_tablemap{"17090"} = "0100";
$PollProc_tablemap{"17091"} = "0100";
$PollProc_tablemap{"17101"} = "1000";
$PollProc_tablemap{"17102"} = "0100";
$PollProc_tablemap{"17115"} = "1000";
$PollProc_tablemap{"17116"} = "0100";
$PollProc_tablemap{"17117"} = "0100";
$PollProc_tablemap{"17190"} = "0100";
$PollProc_tablemap{"17191"} = "0100";
$PollProc_tablemap{"17201"} = "1000";
$PollProc_tablemap{"17202"} = "0100";
$PollProc_tablemap{"17215"} = "1000";
$PollProc_tablemap{"17216"} = "0100";
$PollProc_tablemap{"17217"} = "0100";
$PollProc_tablemap{"17290"} = "0100";
$PollProc_tablemap{"17291"} = "0100";
$PollProc_tablemap{"17301"} = "1000";
$PollProc_tablemap{"17302"} = "0100";
$PollProc_tablemap{"17315"} = "1000";
$PollProc_tablemap{"17316"} = "0100";
$PollProc_tablemap{"17317"} = "0100";
$PollProc_tablemap{"17390"} = "0100";
$PollProc_tablemap{"17391"} = "0100";
$PollProc_tablemap{"17401"} = "1000";
$PollProc_tablemap{"17402"} = "0100";
$PollProc_tablemap{"17415"} = "1000";
$PollProc_tablemap{"17416"} = "0100";
$PollProc_tablemap{"17417"} = "0100";
$PollProc_tablemap{"17490"} = "0100";
$PollProc_tablemap{"17491"} = "0100";
$PollProc_tablemap{"17501"} = "1000";
$PollProc_tablemap{"17502"} = "0100";
$PollProc_tablemap{"17515"} = "1000";
$PollProc_tablemap{"17516"} = "0100";
$PollProc_tablemap{"17517"} = "0100";
$PollProc_tablemap{"17590"} = "0100";
$PollProc_tablemap{"17591"} = "0100";
$PollProc_tablemap{"17601"} = "1000";
$PollProc_tablemap{"17602"} = "0100";
$PollProc_tablemap{"17615"} = "1000";
$PollProc_tablemap{"17616"} = "0100";
$PollProc_tablemap{"17617"} = "0100";
$PollProc_tablemap{"17690"} = "0100";
$PollProc_tablemap{"17691"} = "0100";
$PollProc_tablemap{"17701"} = "1000";
$PollProc_tablemap{"17702"} = "0100";
$PollProc_tablemap{"17715"} = "1000";
$PollProc_tablemap{"17716"} = "0100";
$PollProc_tablemap{"17717"} = "0100";
$PollProc_tablemap{"17790"} = "0100";
$PollProc_tablemap{"17791"} = "0100";
$PollProc_tablemap{"17801"} = "1000";
$PollProc_tablemap{"17802"} = "0100";
$PollProc_tablemap{"17815"} = "1000";
$PollProc_tablemap{"17816"} = "0100";
$PollProc_tablemap{"17817"} = "0100";
$PollProc_tablemap{"17890"} = "0100";
$PollProc_tablemap{"17891"} = "0100";
$PollProc_tablemap{"18101"} = "1000";
$PollProc_tablemap{"18102"} = "0100";
$PollProc_tablemap{"18115"} = "1000";
$PollProc_tablemap{"18116"} = "0100";
$PollProc_tablemap{"18117"} = "0100";
$PollProc_tablemap{"18190"} = "0100";
$PollProc_tablemap{"18191"} = "0100";
$PollProc_tablemap{"18201"} = "1000";
$PollProc_tablemap{"18202"} = "0100";
$PollProc_tablemap{"18215"} = "1000";
$PollProc_tablemap{"18216"} = "0100";
$PollProc_tablemap{"18217"} = "0100";
$PollProc_tablemap{"18290"} = "0100";
$PollProc_tablemap{"18291"} = "0100";
$PollProc_tablemap{"18301"} = "1000";
$PollProc_tablemap{"18302"} = "0100";
$PollProc_tablemap{"18315"} = "1000";
$PollProc_tablemap{"18316"} = "0100";
$PollProc_tablemap{"18317"} = "0100";
$PollProc_tablemap{"18390"} = "0100";
$PollProc_tablemap{"18391"} = "0100";
$PollProc_tablemap{"18401"} = "1000";
$PollProc_tablemap{"18402"} = "0100";
$PollProc_tablemap{"18415"} = "1000";
$PollProc_tablemap{"18416"} = "0100";
$PollProc_tablemap{"18417"} = "0100";
$PollProc_tablemap{"18490"} = "0100";
$PollProc_tablemap{"18491"} = "0100";
$PollProc_tablemap{"18501"} = "1000";
$PollProc_tablemap{"18502"} = "0100";
$PollProc_tablemap{"18511"} = "0101";
$PollProc_tablemap{"18512"} = "0011";
$PollProc_tablemap{"18513"} = "0101";
$PollProc_tablemap{"18515"} = "1000";
$PollProc_tablemap{"18516"} = "0100";
$PollProc_tablemap{"18517"} = "0100";
$PollProc_tablemap{"18518"} = "0001";
$PollProc_tablemap{"18519"} = "0001";
$PollProc_tablemap{"18590"} = "0100";
$PollProc_tablemap{"18591"} = "0100";
$PollProc_tablemap{"100001"} = "1000";
$PollProc_tablemap{"100002"} = "0100";
$PollProc_tablemap{"100011"} = "0101";
$PollProc_tablemap{"100012"} = "0011";
$PollProc_tablemap{"100013"} = "0101";
$PollProc_tablemap{"100015"} = "1000";
$PollProc_tablemap{"100016"} = "0100";
$PollProc_tablemap{"100017"} = "0100";
$PollProc_tablemap{"100018"} = "0001";
$PollProc_tablemap{"100019"} = "0001";
$PollProc_tablemap{"100090"} = "0100";
$PollProc_tablemap{"100091"} = "0100";
$PollProc_tablemap{"150001"} = "1000";
$PollProc_tablemap{"150002"} = "0100";
$PollProc_tablemap{"150011"} = "0101";
$PollProc_tablemap{"150012"} = "0011";
$PollProc_tablemap{"150013"} = "0101";
$PollProc_tablemap{"150015"} = "1000";
$PollProc_tablemap{"150016"} = "0100";
$PollProc_tablemap{"150017"} = "0100";
$PollProc_tablemap{"150018"} = "0001";
$PollProc_tablemap{"150019"} = "0001";
$PollProc_tablemap{"150090"} = "0100";
$PollProc_tablemap{"150091"} = "0100";
$PollProc_tablemap{"250001"} = "1000";
$PollProc_tablemap{"250002"} = "0100";
$PollProc_tablemap{"250011"} = "0101";
$PollProc_tablemap{"250012"} = "0011";
$PollProc_tablemap{"250013"} = "0101";
$PollProc_tablemap{"250015"} = "1000";
$PollProc_tablemap{"250016"} = "0100";
$PollProc_tablemap{"250017"} = "0100";
$PollProc_tablemap{"250018"} = "0001";
$PollProc_tablemap{"250019"} = "0001";
$PollProc_tablemap{"250090"} = "0100";
$PollProc_tablemap{"250091"} = "0100";
$PollProc_tablemap{"300001"} = "1000";
$PollProc_tablemap{"300002"} = "0100";
$PollProc_tablemap{"300011"} = "0101";
$PollProc_tablemap{"300012"} = "0011";
$PollProc_tablemap{"300013"} = "0101";
$PollProc_tablemap{"300015"} = "1000";
$PollProc_tablemap{"300016"} = "0100";
$PollProc_tablemap{"300017"} = "0100";
$PollProc_tablemap{"300018"} = "0001";
$PollProc_tablemap{"300019"} = "0001";
$PollProc_tablemap{"300090"} = "0100";
$PollProc_tablemap{"300091"} = "0100";

my %modeOptions = ("RPD" => 0, "RPV" => 0, "RPP" => 0, "RPH" => 0);

#=========================================================================================================
# Read  RUN CONTROL file
#=========================================================================================================
#
# Example of run control file.  Format: KEYWORD = input parameters
#
#          DBHOST	= hostname   
#          BATCHRUN	= CENRAP
#          OUTDIR       = C:\Program Files\MOVES20091214\runspec_files\tests\
#          MODELYEAR	= 2005
#          POLLUTANTS 	= OZONE, TOXICS, PM, GHG, METALS
#          DAYOFWEEK	= WEEKDAY, WEEKEND
#          METFILE	= c:\movesdata\cenrap\2005\MOVES_RH_2005.csv
#          RPMETFILE    = c:\movesdata\cenrap\2005\2005_repcounty_met.in

# open run control file
open(CONTROLFILE, "$RunControlFile") or die "Unable to open run Control file: $RunControlFile\n";


while (<CONTROLFILE>)
{
    chomp;
    $line = trim($_);

    if (($line eq "") || (substr($line, 0, 1) eq "#"))
    {
        next;
    }

    @line = split(/=/, $_);
    NXTLINE:
    {
        if (uc trim($line[0]) eq "DBHOST")           { $dbhost           = trim($line[1]); last NXTLINE; }
        if (uc trim($line[0]) eq "BATCHRUN")         { $batchrun         = trim($line[1]); last NXTLINE; }
        if (uc trim($line[0]) eq "OUTDIR")           { $outdir           = trim($line[1]); last NXTLINE; }
        if (uc trim($line[0]) eq "MOVESHOME")        { $moveshome        = trim($line[1]); last NXTLINE; }
        if (uc trim($line[0]) eq "MODELYEAR")        { $modelyear        = trim($line[1]); last NXTLINE; }
        if (uc trim($line[0]) eq "POLLUTANTS")       { $User_polls       = uc trim($line[1]); last NXTLINE; }
        if (uc trim($line[0]) eq "DAYOFWEEK")        { $dayofweek        = uc trim($line[1]); last NXTLINE; }
        if (uc trim($line[0]) eq "METFILE")          { $MetFile          = trim($line[1]); last NXTLINE; }
	if (uc trim($line[0]) eq "RPMETFILE")        { $RPMetFile        = trim($line[1]); last NXTLINE; }
        if (uc trim($line[0]) eq "MODES")            { $user_modes       = uc trim($line[1]); last NXTLINE; }
    }
}

# close the file
close CONTROLFILE;

# split up the multiple-value inputs -------------
@User_polls = split(/,/, $User_polls);
@dayofweek  = split(/,/, $dayofweek);
@user_modes = split(/,/, $user_modes);

# Verify user run control file contains valid parameters ----------------

$moveshome = "C:\\Program Files\\MOVES20100826" if ($moveshome eq '');
printf "MOVES home directory is - %s\n",$moveshome;

die "ERROR - invalid value for MODELYEAR ('$modelyear'). Valid values are 1990 and 1999 - 2050 inclusive."
if !(($modelyear == 1990) || ($modelyear >= 1999 && $modelyear <= 2050));

for($i=0;$i<=$#User_polls;++$i) {
	for($j=0;$j<=$#pollOptions;++$j) {
		goto NXTPOLL if ( uc trim($User_polls[$i]) eq $pollOptions[$j] );
	}
	die "ERROR - invalid value for POLLUTANTS ('$User_polls[$i]'). Valid values are 'OZONE','TOXICS','HC','PM','GHG','METALS'.";
NXTPOLL:
}
$pollsFlg = "_";
for($i=0;$i<=$#User_polls;++$i) {
	$pollsFlg = $pollsFlg . (uc trim ($User_polls[$i]));
}
for($i=0;$i<=$#dayofweek;++$i) {
	die "ERROR - invalid value for DAYOFWEEK ('$dayofweek[$i]'). Valid values are 'WEEKDAY' and 'WEEKEND'."
	if (trim($dayofweek[$i]) ne 'WEEKDAY' && trim($dayofweek[$i]) ne 'WEEKEND');
	$WeekDayFlag = 1 if (trim($dayofweek[$i]) eq 'WEEKDAY');
	$WeekEndFlag = 1 if (trim($dayofweek[$i]) eq 'WEEKEND');
}
#  if day of week not specified, assume both weekday and weekend day run
if ( $WeekDayFlag == 0 && $WeekEndFlag == 0 ) {
	$WeekDayFlag = 1;
	$WeekEndFlag = 1;
}

# check last character of output directory name - it must include the slash
die "ERROR - invalid pathname OUTDIR ('$outdir'). Directory name must end in a slash."
if !( (substr($outdir,-1,1) eq "/") || (substr($outdir,-1,1) eq "\\") );

# check emission mode options
for($i=0;$i<=$#user_modes;++$i) {
  die "ERROR - invalid value for MODES ('$user_modes[$i]'). Valid values are 'RPD','RPV','RPP','RPH'."
  unless exists $modeOptions{trim($user_modes[$i])};
  $modeOptions{trim($user_modes[$i])} = 1;
}
# if no modes specified, assume all
if (scalar(@user_modes) == 0) {
  $modeOptions{"RPD"} = 1;
  $modeOptions{"RPV"} = 1;
  $modeOptions{"RPP"} = 1;
  $modeOptions{"RPH"} = 1;
}

# end of run control file reading and parsing
 
#=========================================================================================================
#   open the batch files for list of runspec and data importer filenames
#=========================================================================================================
my $olen = length($outdir); 
my $slash = substr($outdir,-1,1);

$batchFile = $outdir . $batchrun . "_" . $modelyear . "runspec.";
$batchFile .= $GenCSH ? "csh" : "bat";
open(BATFILE, ">$batchFile") or die "Unable to open batch file for list of run spec filenames: $batchFile\n";
printf BATFILE "#!/bin/csh -xf\n" if $GenCSH;
printf BATFILE "cd \"%s\"\n",$moveshome;
printf BATFILE "source setenv.csh\n" if $GenCSH;
printf BATFILE "call setenv.bat\n" unless $GenCSH;
printf BATFILE "\@echo on\n" unless $GenCSH;
printf BATFILE "echo \"\"" if $GenCSH;
printf BATFILE "type null" unless $GenCSH;
printf BATFILE " > \"%s\"%s%s\n", substr($outdir,0,$olen-1),$slash,"runlog_".$batchrun."_".$modelyear.".txt";

$importBatchFile = $outdir . "/" . $batchrun . "_" . $modelyear . "importer.";
$importBatchFile .= $GenCSH ? "csh" : "bat";
open(IMPFILE, ">$importBatchFile") or die "Unable to open batch file for list of data importer filenames: $importBatchFile\n";
printf IMPFILE "#!/bin/csh -xf\n" if $GenCSH;
printf IMPFILE "cd \"%s\"\n",$moveshome;
printf IMPFILE "source setenv.csh\n" if $GenCSH;
printf IMPFILE "call setenv.bat\n" unless $GenCSH;
printf IMPFILE "\@echo on\n" unless $GenCSH;
printf IMPFILE "echo \"\"" if $GenCSH;
printf IMPFILE "type null" unless $GenCSH;
printf IMPFILE " > \"%s\"%s%s\n", substr($outdir,0,$olen-1),$slash,"importlog_".$batchrun."_".$modelyear.".txt";
 
#=========================================================================================================
# Generate complete list of pollutants and processes 

for($i=0;$i<=$#User_polls;++$i) {
	for($j=0;$j<=$#pollOptions;++$j) {
		&setPollsList(@pollsByOptionOZONE)  if ( uc trim($User_polls[$i]) eq "OZONE" );
		&setPollsList(@pollsByOptionTOXICS) if ( uc trim($User_polls[$i]) eq "TOXICS" );
		&setPollsList(@pollsByOptionPM)     if ( uc trim($User_polls[$i]) eq "PM" );
		&setPollsList(@pollsByOptionGHG)    if ( uc trim($User_polls[$i]) eq "GHG" );
		&setPollsList(@pollsByOptionMETALS) if ( uc trim($User_polls[$i]) eq "METALS" );
	}
}

#qa
#for($i=0;$i<=$#pollsListID;++$i) {
#printf "%2.2d %d %d\n",$i,$pollsListID[$i], $pollsOutList[$i];
#}

#=========================================================================================================
# Read the RepCounty file
#=========================================================================================================

# open rep county input file

$cntRepCnty = 0;

open(REPFILE, "$RepCntyFile") or die "Unable to open representative county file: $RepCntyFile\n";

while (<REPFILE>)
{
    chomp;
    $line = trim($_);

    @line = split(/=/, $_);
    NXTREP:
    {
    if (($line eq "") || (substr($line, 0, 1) eq "#"))    { last NXTREP; }
    if (uc substr($line,0,10) eq "<REPCOUNTY")            { ++$cntRepCnty; last NXTREP; }
    if (uc trim($line[0]) eq "FIPS")                      { $repFips[$cntRepCnty] = trim($line[1]); last NXTREP; }
    if (uc trim($line[0]) eq "CDB")                       { $repCDB[$cntRepCnty] = trim($line[1]); last NXTREP; }
    }
}
#qa printf "check repcounty in repc %s\n",$repFips[$cntRepCnty];

#=========================================================================================================
# Read the met4moves input met file and call routines to generate RunSpec files and DataImport files
#=========================================================================================================

# open the met data for RPD and RPV
open(METFILE, "$MetFile") or die "Unable to open met file: $MetFile\n";
my ($MetRep, $MetMonth, $MetRH, %fipsList);
my ($cntTemp, $repTemp, $prevCty, $prevMonth, @RDtemps, $RDcnt, $t);
my ($outputDB, $scenarioID, $scenarioDB, @scenarioIDList);
my ($cntyidx,$flg,$ref,$pp,$process,$code,$tID,$codeOut,$pollRef,$cnty);

# --- read met data records for RPD and RPV ==============================
#
$prevCty = '';
$cntTemp = 0;
$RDcnt = 0;
while (<METFILE>)
{
	chomp;
	$line = trim($_);
	@line = split(/\s+/, trim($_));

	# read header record for temperature bin increments for RPD and RPV
	NXTMET:
	{
		if (($line eq "") || (substr($line, 0, 1) eq "#") || (substr($line, 0, 3) eq "Ref"))    { last NXTMET; }

		# split data fields, determine record types, and parse each appropriately

		@line = split(',', $_);
		$MetRep = trim($line[0]);

		# Fix FIPS length to five characters
		while (length($MetRep) < 5) { $MetRep = "0" . $MetRep; } 
		while (length($MetRep) > 5) { $MetRep = substr($MetRep, 1); } 
			
		$cntyidx = &getRepCnty();
		if ($cntyidx <= 0) {die "ERROR : Repcounty input file incomplete.  Missing county:  $MetRep\nREPCOUNTY packets must exist for all FIPS in input met file.\n";}

		$MetMonth = trim($line[1]);
		$MetRH = $line[2];
		$outputDB = $MetRep . "_" . $modelyear . $pollsFlg;
		$fipsList{$MetRep} = 1;

		# Set initial RPD output file data
		if (($cntTemp eq 0) && ($prevCty eq '')) { $RDtemps[$RDcnt][$cntTemp] = [$MetRep, $MetMonth]; $prevCty = $MetRep; $prevMonth = $MetMonth; }

		$repTemp = $line[5];

		# Reset to next RPD output file data
		if (($MetRep ne $prevCty) || ($MetMonth ne $prevMonth) || ($cntTemp eq 24))
		{
			# Store number of temperatures to be written for set
			$RDtemps[$RDcnt][0][2] = $cntTemp;
 
			$cntTemp = 0;
			$prevCty = $MetRep;
			$prevMonth = $MetMonth;

			# Move to next set of RPD output data
			++$RDcnt;
			$RDtemps[$RDcnt][$cntTemp] = [$MetRep, $MetMonth]
		}

		++$cntTemp;

		# Store RPD output file data for temperature and RH
		$RDtemps[$RDcnt][$cntTemp] = [$repTemp, $MetRH]; 

		#        --- rate per vehicle runs --- ========================================================================
		last NXTMET unless ($modeOptions{"RPV"} || $modeOptions{"RPH"});
		if(int($repTemp) lt 0)
		{
			$scenarioID = "RV_" . $MetRep . "_" . $modelyear . "_" . $MetMonth . "_Tn" . abs($repTemp);
		}
		else
		{
			$scenarioID = "RV_" . $MetRep . "_" . $modelyear . "_" . $MetMonth . "_T" . int($repTemp);
		}
		$scenarioDB = $scenarioID;

		#	   --- write the meteorology MOVES input csv formatted file
		$fileout = $outdir . "/".  $scenarioID . "_zmh.csv";
		open (OUTFL,">$fileout") || die "Cannot open file: $fileout\n";
		printf OUTFL "monthID,zoneID,hourID,temperature,relHumidity\n";
		for($i=0;$i<=23;++$i) 
		{ 
			printf OUTFL "%d,%s0,%d,%5.1f,%5.1f\n",$MetMonth,$MetRep,$i+1, $repTemp, $MetRH;
		}
		close(OUTFL);

		#         --- write the data importer for this runspec 
		$fileout = $outdir . "/".  $scenarioID . "_imp.xml";
		open (OUTFL,">$fileout") || die "Cannot open file: $fileout\n";
		printf IMPFILE "java gov.epa.otaq.moves.master.commandline.MOVESCommandLine -i \"%s\"%s%s", 
								    substr($outdir,0,$olen-1),$slash,$scenarioID."_imp.xml";
		printf IMPFILE " >> \"%s\"%s%s\n", substr($outdir,0,$olen-1),$slash,"importlog_".$batchrun."_".$modelyear.".txt";
		RV_writeDataImporter();
		close(OUTFL);

		#          --- write the runspec file
		$fileout = $outdir . "/".  $scenarioID . "_mrs.xml";
		open (OUTFL,">$fileout") || die "Cannot open file: $fileout\n";
		printf BATFILE "java gov.epa.otaq.moves.master.commandline.MOVESCommandLine -r \"%s\"%s%s", 
								    substr($outdir,0,$olen-1),$slash,$scenarioID."_mrs.xml";
		printf BATFILE " >> \"%s\"%s%s\n", substr($outdir,0,$olen-1),$slash,"runlog_".$batchrun."_".$modelyear.".txt";
		RV_writeRunSpec();
		close(OUTFL);
		# end of RPV write

	} # end of NXTMET

} # end of RPD / RPV met input file read

# --- write the rate per distance runs
$RDtemps[$RDcnt][0][2] = $cntTemp;  # store the final count total for last RPD file
if ($modeOptions{"RPD"})
{
  for ($t=0;$t<=$RDcnt;++$t)
  {
    # Retrieve meta data for RPD file to be written
    $MetRep = $RDtemps[$t][0][0];
    $MetMonth = $RDtemps[$t][0][1]; 
    $cntTemp = $RDtemps[$t][0][2];
    $outputDB = $MetRep . "_" . $modelyear . $pollsFlg;
  
    # Definte scenario ID, adjusting name for bins with negative temperature starts
    if (int($RDtemps[$t][1][0]) lt 0)
    {
      $scenarioID = "RD_" . $MetRep . "_" . $modelyear . "_" . $MetMonth . "_Tn" . abs($RDtemps[$t][1][0]) . "_" . int($RDtemps[$t][$cntTemp][0]);
    } else {
      $scenarioID = "RD_" . $MetRep . "_" . $modelyear . "_" . $MetMonth . "_T" . int($RDtemps[$t][1][0]) . "_" . int($RDtemps[$t][$cntTemp][0]);
    }
    $scenarioDB = $scenarioID;

    #	   --- write the meteorology MOVES input csv formatted file
    $fileout = $outdir .  $scenarioID . "_zmh.csv";
    open (OUTFL,">$fileout") || die "Cannot open file: $fileout\n";
    printf OUTFL "monthID,zoneID,hourID,temperature,relHumidity\n";

    for($i=1;$i<=24;++$i) 
    {
      if ($i <= $cntTemp)
      { 
        printf OUTFL "%d,%s0,%d,%5.1f,%5.1f\n",$MetMonth,$MetRep,$i, $RDtemps[$t][$i][0], $RDtemps[$t][$i][1];
      } else { 
        printf OUTFL "%d,%s0,%d,%5.1f,%5.1f\n",$MetMonth,$MetRep,$i, $RDtemps[$t][$cntTemp][0], $RDtemps[$t][$cntTemp][1];
      }

    }
    close(OUTFL);

    #          --- write the data importer for this runspec 
    $fileout = $outdir . $scenarioID . "_imp.xml";
    open (OUTFL,">$fileout") || die "Cannot open file: $fileout\n";
    printf IMPFILE "java gov.epa.otaq.moves.master.commandline.MOVESCommandLine -i \"%s\"%s%s", 
                    substr($outdir,0,$olen-1),$slash,$scenarioID."_imp.xml";
    printf IMPFILE " >> \"%s\"%s%s\n", substr($outdir,0,$olen-1),$slash,"importlog_".$batchrun."_".$modelyear.".txt";
    RD_writeDataImporter();
    close(OUTFL);

    # Need to reset outputDB

    #          --- write the runspec file
    $fileout = $outdir . "/".  $scenarioID . "_mrs.xml";
    open (OUTFL,">$fileout") || die "Cannot open file: $fileout\n";
    printf BATFILE "java gov.epa.otaq.moves.master.commandline.MOVESCommandLine -r \"%s\"%s%s", 
                    substr($outdir,0,$olen-1),$slash,$scenarioID."_mrs.xml";
    printf BATFILE " >> \"%s\"%s%s\n", substr($outdir,0,$olen-1),$slash,"runlog_".$batchrun."_".$modelyear.".txt";
    RD_writeRunSpec(0);
    close(OUTFL);
    
    # write evap rate-per-distance runspec
    $scenarioID =~ s/^RD_/RE_/;
    $fileout = $outdir . "/".  $scenarioID . "_mrs.xml";
    open (OUTFL,">$fileout") || die "Cannot open file: $fileout\n";
    printf BATFILE "java gov.epa.otaq.moves.master.commandline.MOVESCommandLine -r \"%s\"%s%s", 
                    substr($outdir,0,$olen-1),$slash,$scenarioID."_mrs.xml";
    printf BATFILE " >> \"%s\"%s%s\n", substr($outdir,0,$olen-1),$slash,"runlog_".$batchrun."_".$modelyear.".txt";
    $scenarioID =~ s/^RE_/RD_/; # use original RD_ scenario ID in runspec
    RD_writeRunSpec(1);
    close(OUTFL);
  }
} # end of RPD write

# Read the RPP met data and write for RPP
open(METFILE, "$RPMetFile") or die "Unable to open RPP met file: $RPMetFile\n";
my ($VV_TempInc, $MetProfId, $oldornew, $temp1col);

# (C. Allen, 26 Mar 2013) $oldornew is a flag, set to "old" for old format RPmetfiles, "new" for net format RPmetfiles.
# It's set according to whether PP_TEMP_INCREMENT is preceded with a # or not. 
# "PP_TEMP_INCREMENT" = old, "#PP_TEMP_INCREMENT" = new. 
$oldornew = "unknown";

# --- read the RPP met data records
#
while (<METFILE>)
{
	chomp;
	$line = trim($_);
	@line = split(/\s+/, trim($_));

	# read header record for temperature bin increments
	
	NXTMET:
	{
		if (uc trim($line[0]) eq "PP_TEMP_INCREMENT") { $VV_TempInc = trim($line[1]); $oldornew = "old"; last NXTMET; }
		if (uc trim($line[0]) eq "#PP_TEMP_INCREMENT") { $VV_TempInc = trim($line[1]); $oldornew = "new"; last NXTMET; }
		if (($line eq "") || (substr($line, 0, 1) eq "#") || (substr($line, 0, 3) eq "Ref"))    { last NXTMET; }
		if ((uc trim($line[0]) eq "PD_TEMP_INCREMENT") || (uc trim($line[0]) eq "PV_TEMP_INCREMENT"))  { last NXTMET; }
		
		# split data fields, determine record types, and parse
		# diurnal record: fips, fuelMonth, key, rh, temp1, temp2, ... temp24

		# new format delimited by commas, not spaces
		# old format delimited by spaces only. header in new format can be delimited by spaces, so split both by spaces
		# until it's known whether it's new or old format
		if ($oldornew eq "new") {@line = split(',', $_);} 
		if (($oldornew eq "old") || ($oldornew eq "unknown")) {@line = split(/\s+/, $_);}

		$MetRep = substr(trim($line[0]),-5);
		$cntyidx = &getRepCnty();
		if ($cntyidx <= 0) {die "ERROR : Repcounty input file incomplete.  Missing county:  $MetRep\nREPCOUNTY packets must exist for all FIPS in input met file.\n";}

		$MetMonth = trim($line[1]);
		$MetProfId = trim($line[2]);

		# temp1col: In old format, temp1 is column 4 (with FIPS in column 0). In new format, temp1 is column 5.
		if ($oldornew eq "old")
		{
			$MetRH = $line[3];
			$temp1col = 4;
		} # if oldornew = old

		if ($oldornew eq "new")
		{
			$MetRH = 50; # RH not listed in new format files. Not needed for RPP anyway, so just set to 50.
			$temp1col = 5;
		} # if oldornew = new
		
		$outputDB = $MetRep . "_" . $modelyear . $pollsFlg;
		$fipsList{$MetRep} = 1;

		#   24-hour temperature profiles required for vapor venting emissions mode
		if ($modeOptions{"RPP"} && $MetProfId ne "min_max")
		{
			$scenarioID = "RP_" . $MetRep . "_" . $modelyear . "_" . $MetMonth . "_prof" . $MetProfId;
			$scenarioDB = $scenarioID;

			#	--- write the meteorology MOVES input csv formatted file
			$fileout = $outdir . "/".  $scenarioID . "_zmh.csv";
			open (OUTFL,">$fileout") || die "Cannot open file: $fileout\n";
			printf OUTFL "monthID,zoneID,hourID,temperature,relHumidity\n";
			for($i=0;$i<=23;++$i) 
			{ 
				printf OUTFL "%d,%s0,%d,%5.1f,%5.1f\n",$MetMonth,$MetRep,$i+1, $line[$temp1col+$i], $MetRH;
			}
			close(OUTFL);

			#       --- write the data importer for this runspec 
			$fileout = $outdir . "/".  $scenarioID . "_imp.xml";
			open (OUTFL,">$fileout") || die "Cannot open file: $fileout\n";
			printf IMPFILE "java gov.epa.otaq.moves.master.commandline.MOVESCommandLine -i \"%s\"%s%s", 
											 substr($outdir,0,$olen-1),$slash,$scenarioID."_imp.xml";
			printf IMPFILE " >> \"%s\"%s%s\n", substr($outdir,0,$olen-1),$slash,"importlog_".$batchrun."_".$modelyear.".txt";
			VV_writeDataImporter(); 
			close(OUTFL);

			#       --- write the runspec file
			$fileout = $outdir . "/".  $scenarioID."_mrs.xml";
			open (OUTFL,">$fileout") || die "Cannot open file: $fileout\n";
			printf BATFILE "java gov.epa.otaq.moves.master.commandline.MOVESCommandLine -r \"%s\"%s%s", 
											 substr($outdir,0,$olen-1),$slash,$scenarioID."_mrs.xml";
			printf BATFILE " >> \"%s\"%s%s\n", substr($outdir,0,$olen-1),$slash,"runlog_".$batchrun."_".$modelyear.".txt";
			VV_writeRunSpec();
			close(OUTFL);
		}  # end if for profileid types

	}  # end of NXTMET

}  # end read met file for RPP

$dbListFile = $outdir . "/" . $batchrun . "_" . $modelyear . "outputDBs.txt";
open(DBFILE, ">$dbListFile") or die "Unable to open file for list of output DB names: $dbListFile\n";

printf DBFILE "%s\n",$dbhost;
printf DBFILE "%s\n",$outdir;
foreach $cnty (sort(keys(%fipsList)))
{
	printf DBFILE "%5.5d_%4.4d%s\n",$cnty, $modelyear, $pollsFlg;
}
#=========================================================================================================
#               SUBROUTINES
#=========================================================================================================

#=========================================================================================================
# Set the output pollutant list flag for each User pollutant option
#=========================================================================================================
sub setPollsList()
{
	foreach $_ (@_)
		{
			for($ip=0;$ip<=$#pollsListID;++$ip) {
				$pollsOutList[$ip] = 1 if ($pollsListID[$ip] == $_);
			}
		}
}  #end subroutine setPollsList

#=========================================================================================================
#  Determine the repcounty file county index
#=========================================================================================================
sub getRepCnty
{
   for($ic=1;$ic<=$cntRepCnty;++$ic) 
   {
	if ($repFips[$ic] eq $MetRep)
	{
	   return $ic;
	}
   }

}  # end subroutine getRepCnty

#=========================================================================================================
#  Generate the RunSpec files for categoryA; on-network operating mode
#=========================================================================================================
sub RD_writeRunSpec
{
   my $evap_flg = $_[0];
   
   printf OUTFL "\t<runspec version=\"MOVES4.0\">\n";
   printf OUTFL "\t<description><![CDATA[RunSpec Generator for MOVES4 - %s]]></description>\n",$scenarioID;
   printf OUTFL "\t<models>\n";
   printf OUTFL "\t\t<model value=\"ONROAD\"/>\n";
   printf OUTFL "\t</models>\n";
   printf OUTFL "\t<modelscale value=\"Rates\"/>\n";
   printf OUTFL "\t<modeldomain value=\"SINGLE\"/>\n";

   &geoselect();
   &timespan(1);
   &vehsel();
   
   printf OUTFL "\t<offroadvehicleselections>\n";
   printf OUTFL "\t</offroadvehicleselections>\n";
   printf OUTFL "\t<offroadvehiclesccs>\n";
   printf OUTFL "\t</offroadvehiclesccs>\n";

   printf OUTFL "\t<roadtypes>\n";
   if ($evap_flg == 0) {
      printf OUTFL "\t\t<roadtype roadtypeid=\"1\" roadtypename=\"Off-Network\" modelCombination=\"M1\"/>\n";
   }
   printf OUTFL "\t\t<roadtype roadtypeid=\"2\" roadtypename=\"Rural Restricted Access\" modelCombination=\"M1\"/>\n";
   printf OUTFL "\t\t<roadtype roadtypeid=\"3\" roadtypename=\"Rural Unrestricted Access\" modelCombination=\"M1\"/>\n";
   printf OUTFL "\t\t<roadtype roadtypeid=\"4\" roadtypename=\"Urban Restricted Access\" modelCombination=\"M1\"/>\n";
   printf OUTFL "\t\t<roadtype roadtypeid=\"5\" roadtypename=\"Urban Unrestricted Access\" modelCombination=\"M1\"/>\n";
   printf OUTFL "\t</roadtypes>\n";

   if ($evap_flg == 1) {
      &pollProc (4);   # pass the column of interest for this runspec type
   } else {
      &pollProc (1);   # pass the column of interest for this runspec type
   }

   &rspend();
}  # end subroutine RD_writeRunSpec

#=========================================================================================================
#  Generate the Data Importer files for categoryA; on-network operating mode
#=========================================================================================================
sub RD_writeDataImporter
{
   printf OUTFL "\t<moves>\n";
   printf OUTFL "\t\t<importer mode=\"county\">\n";
   printf OUTFL "\t\t<filters>\n";

   &geoselect();
   &timespan(1);
   &vehsel();

   printf OUTFL "\t<roadtypes>\n";
   printf OUTFL "\t\t<roadtype roadtypeid=\"1\" roadtypename=\"Off-Network\"/>\n";
   printf OUTFL "\t\t<roadtype roadtypeid=\"2\" roadtypename=\"Rural Restricted Access\"/>\n";
   printf OUTFL "\t\t<roadtype roadtypeid=\"3\" roadtypename=\"Rural Unrestricted Access\"/>\n";
   printf OUTFL "\t\t<roadtype roadtypeid=\"4\" roadtypename=\"Urban Restricted Access\"/>\n";
   printf OUTFL "\t\t<roadtype roadtypeid=\"5\" roadtypename=\"Urban Unrestricted Access\"/>\n";
   printf OUTFL "\t</roadtypes>\n";

   &pollProc (1);   # pass the column of interest for this runspec type
   printf OUTFL "\t\t</filters>\n";

   &dataImporter();
}  # end subroutine RD_writeDataImporter

#=========================================================================================================
#  Generate the RunSpec files for categoryB; offnetwork processes
#=========================================================================================================
sub RV_writeRunSpec
{
   printf OUTFL "\t<runspec version=\"MOVES4.0\">\n";
   printf OUTFL "\t<description><![CDATA[RunSpec Generator for MOVES4 - %s]]></description>\n",$scenarioID;
   printf OUTFL "\t<models>\n";
   printf OUTFL "\t\t<model value=\"ONROAD\"/>\n";
   printf OUTFL "\t</models>\n";
   printf OUTFL "\t<modelscale value=\"Rates\"/>\n";
   printf OUTFL "\t<modeldomain value=\"SINGLE\"/>\n";

   &geoselect();
   &timespan(0);
   &vehsel();

   printf OUTFL "\t<offroadvehicleselections>\n";
   printf OUTFL "\t</offroadvehicleselections>\n";
   printf OUTFL "\t<offroadvehiclesccs>\n";
   printf OUTFL "\t</offroadvehiclesccs>\n";

   printf OUTFL "\t<roadtypes>\n";
   printf OUTFL "\t\t<roadtype roadtypeid=\"1\" roadtypename=\"Off-Network\" modelCombination=\"M1\"/>\n";
   #printf OUTFL "\t\t<roadtype roadtypeid=\"2\" roadtypename=\"Rural Restricted Access\"/>\n";
   #printf OUTFL "\t\t<roadtype roadtypeid=\"3\" roadtypename=\"Rural Unrestricted Access\"/>\n";
   #printf OUTFL "\t\t<roadtype roadtypeid=\"4\" roadtypename=\"Urban Restricted Access\"/>\n";
   #printf OUTFL "\t\t<roadtype roadtypeid=\"5\" roadtypename=\"Urban Unrestricted Access\"/>\n";
   printf OUTFL "\t</roadtypes>\n";

   &pollProc (2);   # pass the column of interest for this runspec type

   &rspend();
}  # end subroutine RV_writeRunSpec

#=========================================================================================================
#  Generate the Data Importer files for categoryB; offnetwork processes
#=========================================================================================================
sub RV_writeDataImporter
{
   printf OUTFL "\t<moves>\n";
   printf OUTFL "\t\t<importer mode=\"county\">\n";
   printf OUTFL "\t\t<filters>\n";

   &geoselect();
   &timespan(0);
   &vehsel();

   printf OUTFL "\t<roadtypes>\n";
   printf OUTFL "\t\t<roadtype roadtypeid=\"1\" roadtypename=\"Off-Network\"/>\n";
   printf OUTFL "\t\t<roadtype roadtypeid=\"2\" roadtypename=\"Rural Restricted Access\"/>\n";
   printf OUTFL "\t\t<roadtype roadtypeid=\"3\" roadtypename=\"Rural Unrestricted Access\"/>\n";
   printf OUTFL "\t\t<roadtype roadtypeid=\"4\" roadtypename=\"Urban Restricted Access\"/>\n";
   printf OUTFL "\t\t<roadtype roadtypeid=\"5\" roadtypename=\"Urban Unrestricted Access\"/>\n";
   printf OUTFL "\t</roadtypes>\n";

   &pollProc (2);   # pass the column of interest for this runspec type
   printf OUTFL "\t\t</filters>\n";

   &dataImporter();
}  # end subroutine RV_writeDataImporter

#=========================================================================================================
#  Generate the RunSpec files for categoryC; vapor venting
#=========================================================================================================
sub VV_writeRunSpec
{
   printf OUTFL "\t<runspec version=\"MOVES4.0\">\n";
   printf OUTFL "\t<description><![CDATA[RunSpec Generator for MOVES4 - %s]]></description>\n",$scenarioID;
   printf OUTFL "\t<models>\n";
   printf OUTFL "\t\t<model value=\"ONROAD\"/>\n";
   printf OUTFL "\t</models>\n";
   printf OUTFL "\t<modelscale value=\"Rates\"/>\n";
   printf OUTFL "\t<modeldomain value=\"SINGLE\"/>\n";

   &geoselect();
   &timespan(0);
   &vehsel();

   printf OUTFL "\t<offroadvehicleselections>\n";
   printf OUTFL "\t</offroadvehicleselections>\n";
   printf OUTFL "\t<offroadvehiclesccs>\n";
   printf OUTFL "\t</offroadvehiclesccs>\n";

   printf OUTFL "\t<roadtypes>\n";
   printf OUTFL "\t\t<roadtype roadtypeid=\"1\" roadtypename=\"Off-Network\" modelCombination=\"M1\"/>\n";
   #printf OUTFL "\t\t<roadtype roadtypeid=\"2\" roadtypename=\"Rural Restricted Access\"/>\n";
   #printf OUTFL "\t\t<roadtype roadtypeid=\"3\" roadtypename=\"Rural Unrestricted Access\"/>\n";
   #printf OUTFL "\t\t<roadtype roadtypeid=\"4\" roadtypename=\"Urban Restricted Access\"/>\n";
   #printf OUTFL "\t\t<roadtype roadtypeid=\"5\" roadtypename=\"Urban Unrestricted Access\"/>\n";
   printf OUTFL "\t</roadtypes>\n";

   &pollProc (3);   # pass the column of interest for this runspec type

   &rspend();
}  # end subroutine VV_writeRunSpec

#=========================================================================================================
#  Generate the Data Importer files for categoryC; vapor venting
#=========================================================================================================
sub VV_writeDataImporter
{
   printf OUTFL "\t<moves>\n";
   printf OUTFL "\t\t<importer mode=\"county\">\n";
   printf OUTFL "\t\t<filters>\n";

   &geoselect();
   &timespan(0);
   &vehsel();

   printf OUTFL "\t<roadtypes>\n";
   printf OUTFL "\t\t<roadtype roadtypeid=\"1\" roadtypename=\"Off-Network\"/>\n";
   printf OUTFL "\t\t<roadtype roadtypeid=\"2\" roadtypename=\"Rural Restricted Access\"/>\n";
   printf OUTFL "\t\t<roadtype roadtypeid=\"3\" roadtypename=\"Rural Unrestricted Access\"/>\n";
   printf OUTFL "\t\t<roadtype roadtypeid=\"4\" roadtypename=\"Urban Restricted Access\"/>\n";
   printf OUTFL "\t\t<roadtype roadtypeid=\"5\" roadtypename=\"Urban Unrestricted Access\"/>\n";
   printf OUTFL "\t</roadtypes>\n";

   &pollProc (3);   # pass the column of interest for this runspec type
   printf OUTFL "\t\t</filters>\n";

   &dataImporter();
}  # end subroutine VV_writeDataImporter

# --- geographic selections - ========================================================================
sub geoselect
{
   printf OUTFL "\t<geographicselections>\n";
   printf OUTFL "\t\t<geographicselection type=\"COUNTY\" key=\"%d\" description=\"\"/>\n", $MetRep;
   printf OUTFL "\t</geographicselections>\n";
        
}  # end geoselect subroutine

# --- timespan - ====================================================================================
sub timespan
{
   $flg = $_[0];

   printf OUTFL "\t<timespan>\n";
   printf OUTFL "\t\t<year key=\"%4d\"/>\n", $modelyear;
   printf OUTFL "\t\t<month id=\"%d\"/>\n", $MetMonth;
   if ( $flg == 1 ) {
       printf OUTFL "\t\t<day id=\"5\"/>\n"; }
   else {
       printf OUTFL "\t\t<day id=\"5\"/>\n" if ($WeekDayFlag);
       printf OUTFL "\t\t<day id=\"2\"/>\n" if ($WeekEndFlag);
   }
   printf OUTFL "\t\t<beginhour id=\"1\"/>\n";
   printf OUTFL "\t\t<endhour id=\"24\"/>\n";
   printf OUTFL "\t\t<aggregateBy key=\"Hour\"/>\n";
   printf OUTFL "\t</timespan>\n";
} # end timespan subroutine

# --- onroad vehicle selections - ====================================================================
sub vehsel
{
   #--Note - gas/E-85 intercity bus, gas/E-85 combination long-haul truck, diesel motorcycles not supported in MOVES2014 DB
   printf OUTFL "\t<onroadvehicleselections>\n";
   printf OUTFL "\t\t<onroadvehicleselection fueltypeid=\"1\" fueltypedesc=\"Gasoline\" sourcetypeid=\"11\" sourcetypename=\"Motorcycle\"/>\n";
   printf OUTFL "\t\t<onroadvehicleselection fueltypeid=\"1\" fueltypedesc=\"Gasoline\" sourcetypeid=\"21\" sourcetypename=\"Passenger Car\"/>\n";
   printf OUTFL "\t\t<onroadvehicleselection fueltypeid=\"1\" fueltypedesc=\"Gasoline\" sourcetypeid=\"31\" sourcetypename=\"Passenger Truck\"/>\n";
   printf OUTFL "\t\t<onroadvehicleselection fueltypeid=\"1\" fueltypedesc=\"Gasoline\" sourcetypeid=\"32\" sourcetypename=\"Light Commercial Truck\"/>\n";
   printf OUTFL "\t\t<onroadvehicleselection fueltypeid=\"1\" fueltypedesc=\"Gasoline\" sourcetypeid=\"41\" sourcetypename=\"Other Buses\"/>\n";
   printf OUTFL "\t\t<onroadvehicleselection fueltypeid=\"1\" fueltypedesc=\"Gasoline\" sourcetypeid=\"42\" sourcetypename=\"Transit Bus\"/>\n";
   printf OUTFL "\t\t<onroadvehicleselection fueltypeid=\"1\" fueltypedesc=\"Gasoline\" sourcetypeid=\"43\" sourcetypename=\"School Bus\"/>\n";
   printf OUTFL "\t\t<onroadvehicleselection fueltypeid=\"1\" fueltypedesc=\"Gasoline\" sourcetypeid=\"51\" sourcetypename=\"Refuse Truck\"/>\n";
   printf OUTFL "\t\t<onroadvehicleselection fueltypeid=\"1\" fueltypedesc=\"Gasoline\" sourcetypeid=\"52\" sourcetypename=\"Single Unit Short-haul Truck\"/>\n";
   printf OUTFL "\t\t<onroadvehicleselection fueltypeid=\"1\" fueltypedesc=\"Gasoline\" sourcetypeid=\"53\" sourcetypename=\"Single Unit Long-haul Truck\"/>\n";
   printf OUTFL "\t\t<onroadvehicleselection fueltypeid=\"1\" fueltypedesc=\"Gasoline\" sourcetypeid=\"54\" sourcetypename=\"Motor Home\"/>\n";
   printf OUTFL "\t\t<onroadvehicleselection fueltypeid=\"1\" fueltypedesc=\"Gasoline\" sourcetypeid=\"61\" sourcetypename=\"Combination Short-haul Truck\"/>\n";
   printf OUTFL "\t\t<onroadvehicleselection fueltypeid=\"2\" fueltypedesc=\"Diesel Fuel\" sourcetypeid=\"21\" sourcetypename=\"Passenger Car\"/> \n";
   printf OUTFL "\t\t<onroadvehicleselection fueltypeid=\"2\" fueltypedesc=\"Diesel Fuel\" sourcetypeid=\"31\" sourcetypename=\"Passenger Truck\" />\n";
   printf OUTFL "\t\t<onroadvehicleselection fueltypeid=\"2\" fueltypedesc=\"Diesel Fuel\" sourcetypeid=\"32\" sourcetypename=\"Light Commercial Truck\"/>\n";
   printf OUTFL "\t\t<onroadvehicleselection fueltypeid=\"2\" fueltypedesc=\"Diesel Fuel\" sourcetypeid=\"41\" sourcetypename=\"Other Buses\"/> \n";
   printf OUTFL "\t\t<onroadvehicleselection fueltypeid=\"2\" fueltypedesc=\"Diesel Fuel\" sourcetypeid=\"42\" sourcetypename=\"Transit Bus\"/>\n";
   printf OUTFL "\t\t<onroadvehicleselection fueltypeid=\"2\" fueltypedesc=\"Diesel Fuel\" sourcetypeid=\"43\" sourcetypename=\"School Bus\"/>\n";
   printf OUTFL "\t\t<onroadvehicleselection fueltypeid=\"2\" fueltypedesc=\"Diesel Fuel\" sourcetypeid=\"51\" sourcetypename=\"Refuse Truck\"/>\n";
   printf OUTFL "\t\t<onroadvehicleselection fueltypeid=\"2\" fueltypedesc=\"Diesel Fuel\" sourcetypeid=\"52\" sourcetypename=\"Single Unit Short-haul Truck\"/>\n";
   printf OUTFL "\t\t<onroadvehicleselection fueltypeid=\"2\" fueltypedesc=\"Diesel Fuel\" sourcetypeid=\"53\" sourcetypename=\"Single Unit Long-haul Truck\"/>\n";
   printf OUTFL "\t\t<onroadvehicleselection fueltypeid=\"2\" fueltypedesc=\"Diesel Fuel\" sourcetypeid=\"54\" sourcetypename=\"Motor Home\"/>\n";
   printf OUTFL "\t\t<onroadvehicleselection fueltypeid=\"2\" fueltypedesc=\"Diesel Fuel\" sourcetypeid=\"61\" sourcetypename=\"Combination Short-haul Truck\"/>\n";
   printf OUTFL "\t\t<onroadvehicleselection fueltypeid=\"2\" fueltypedesc=\"Diesel Fuel\" sourcetypeid=\"62\" sourcetypename=\"Combination Long-haul Truck\"/>\n";
   printf OUTFL "\t\t<onroadvehicleselection fueltypeid=\"3\" fueltypedesc=\"Compressed Natural Gas (CNG)\" sourcetypeid=\"41\" sourcetypename=\"Other Buses\"/> \n";
   printf OUTFL "\t\t<onroadvehicleselection fueltypeid=\"3\" fueltypedesc=\"Compressed Natural Gas (CNG)\" sourcetypeid=\"42\" sourcetypename=\"Transit Bus\"/>\n";
   printf OUTFL "\t\t<onroadvehicleselection fueltypeid=\"3\" fueltypedesc=\"Compressed Natural Gas (CNG)\" sourcetypeid=\"43\" sourcetypename=\"School Bus\"/>\n";
   printf OUTFL "\t\t<onroadvehicleselection fueltypeid=\"3\" fueltypedesc=\"Compressed Natural Gas (CNG)\" sourcetypeid=\"51\" sourcetypename=\"Refuse Truck\"/>\n";
   printf OUTFL "\t\t<onroadvehicleselection fueltypeid=\"3\" fueltypedesc=\"Compressed Natural Gas (CNG)\" sourcetypeid=\"52\" sourcetypename=\"Single Unit Short-haul Truck\"/>\n";
   printf OUTFL "\t\t<onroadvehicleselection fueltypeid=\"3\" fueltypedesc=\"Compressed Natural Gas (CNG)\" sourcetypeid=\"53\" sourcetypename=\"Single Unit Long-haul Truck\"/>\n";
   printf OUTFL "\t\t<onroadvehicleselection fueltypeid=\"3\" fueltypedesc=\"Compressed Natural Gas (CNG)\" sourcetypeid=\"54\" sourcetypename=\"Motor Home\"/>\n";
   printf OUTFL "\t\t<onroadvehicleselection fueltypeid=\"3\" fueltypedesc=\"Compressed Natural Gas (CNG)\" sourcetypeid=\"61\" sourcetypename=\"Combination Short-haul Truck\"/>\n";
   printf OUTFL "\t\t<onroadvehicleselection fueltypeid=\"3\" fueltypedesc=\"Compressed Natural Gas (CNG)\" sourcetypeid=\"62\" sourcetypename=\"Combination Long-haul Truck\"/>\n";
   printf OUTFL "\t\t<onroadvehicleselection fueltypeid=\"5\" fueltypedesc=\"Ethanol (E-85)\" sourcetypeid=\"21\" sourcetypename=\"Passenger Car\"/> \n";
   printf OUTFL "\t\t<onroadvehicleselection fueltypeid=\"5\" fueltypedesc=\"Ethanol (E-85)\" sourcetypeid=\"31\" sourcetypename=\"Passenger Truck\" />\n";
   printf OUTFL "\t\t<onroadvehicleselection fueltypeid=\"5\" fueltypedesc=\"Ethanol (E-85)\" sourcetypeid=\"32\" sourcetypename=\"Light Commercial Truck\"/>\n";
   printf OUTFL "\t\t<onroadvehicleselection fueltypeid=\"9\" fueltypedesc=\"Electricity\" sourcetypeid=\"21\" sourcetypename=\"Passenger Car\"/> \n";
   printf OUTFL "\t\t<onroadvehicleselection fueltypeid=\"9\" fueltypedesc=\"Electricity\" sourcetypeid=\"31\" sourcetypename=\"Passenger Truck\" />\n";
   printf OUTFL "\t\t<onroadvehicleselection fueltypeid=\"9\" fueltypedesc=\"Electricity\" sourcetypeid=\"32\" sourcetypename=\"Light Commercial Truck\"/>\n";
   printf OUTFL "\t\t<onroadvehicleselection fueltypeid=\"9\" fueltypedesc=\"Electricity\" sourcetypeid=\"41\" sourcetypename=\"Other Buses\"/> \n";
   printf OUTFL "\t\t<onroadvehicleselection fueltypeid=\"9\" fueltypedesc=\"Electricity\" sourcetypeid=\"42\" sourcetypename=\"Transit Bus\"/>\n";
   printf OUTFL "\t\t<onroadvehicleselection fueltypeid=\"9\" fueltypedesc=\"Electricity\" sourcetypeid=\"43\" sourcetypename=\"School Bus\"/>\n";
   printf OUTFL "\t\t<onroadvehicleselection fueltypeid=\"9\" fueltypedesc=\"Electricity\" sourcetypeid=\"51\" sourcetypename=\"Refuse Truck\"/>\n";
   printf OUTFL "\t\t<onroadvehicleselection fueltypeid=\"9\" fueltypedesc=\"Electricity\" sourcetypeid=\"52\" sourcetypename=\"Single Unit Short-haul Truck\"/>\n";
   printf OUTFL "\t\t<onroadvehicleselection fueltypeid=\"9\" fueltypedesc=\"Electricity\" sourcetypeid=\"53\" sourcetypename=\"Single Unit Long-haul Truck\"/>\n";
   printf OUTFL "\t\t<onroadvehicleselection fueltypeid=\"9\" fueltypedesc=\"Electricity\" sourcetypeid=\"54\" sourcetypename=\"Motor Home\"/>\n";
   printf OUTFL "\t\t<onroadvehicleselection fueltypeid=\"9\" fueltypedesc=\"Electricity\" sourcetypeid=\"61\" sourcetypename=\"Combination Short-haul Truck\"/>\n";
   printf OUTFL "\t\t<onroadvehicleselection fueltypeid=\"9\" fueltypedesc=\"Electricity\" sourcetypeid=\"62\" sourcetypename=\"Combination Long-haul Truck\"/>\n";
   printf OUTFL "\t</onroadvehicleselections>\n";
}  # end vehsel subroutine

# --- pollutant process associations - ====================================================================
sub pollProc
{
   $ref = $_[0];
   $ref = $ref - 1;

#qa printf "reference is %d\n", $ref;
my ($qac);
$qac = 0;
   printf OUTFL "\t<pollutantprocessassociations>\n";
   foreach $pp (sort keys %PollProc_tablemap)
   {
	++$qac;
	$process = substr($pp,-2);
	$code = $PollProc_tablemap{$pp};
	$codeOut = substr($code,$ref,1);
#qa	printf "pp %s process %s code %s codeout %s\n", $pp, $process,$code,$codeOut if ($qac < 10);
	if ($codeOut eq "1") 
	{
		$pollRef = substr($pp,0,length($pp)-2);

		for($ip=0;$ip<=$#pollsListID;++$ip) {
			if ( $pollRef eq $pollsListID[$ip] && $pollsOutList[$ip] == 1)
			{
			#  print to output file
				printf OUTFL "\t\t<pollutantprocessassociation pollutantkey=\"%d\" ", $pollsListID[$ip];
				printf OUTFL "pollutantname=\"%s\" ", $pollsListName[$ip];
				printf OUTFL "processkey=\"%d\" ", $process;
				printf OUTFL "processname=\"%s\"/>\n", $processName{$process};
			}
		}

	} # end for this runspec table
   } # end each of pollutant - process mappings
   printf OUTFL "\t</pollutantprocessassociations>\n";
} # end pollProc subroutine


# --- finish up the data importer file - ====================================================================
sub dataImporter
{
   printf OUTFL "\t<databaseselection servername=\"localhost\" databasename=\"%s\"/>\n",$scenarioDB."_in";

   printf OUTFL "\t<zonemonthhour>\n";
   printf OUTFL "\t\t<description><![CDATA[]]></description>\n";
   printf OUTFL "\t\t<parts>\n";
   printf OUTFL "\t\t\t<zoneMonthHour>\n";
   printf OUTFL "\t\t\t<filename>%s</filename>\n", $outdir.$scenarioID."_zmh.csv";
   printf OUTFL "\t\t\t</zoneMonthHour>\n";
   printf OUTFL "\t\t</parts>\n";
   printf OUTFL "\t</zonemonthhour>\n";

   printf OUTFL "\t</importer>\n";
   printf OUTFL "</moves>\n";

}  # end of dataImporter subroutine


# --- finish up the runspec  file - ====================================================================
sub rspend
{
   printf OUTFL "\t<internalcontrolstrategies>\n";
   printf OUTFL "\t<internalcontrolstrategy classname=\"gov.epa.otaq.moves.master.implementation.ghg.internalcontrolstrategies.rateofprogress.RateOfProgressStrategy\"><![CDATA[\n";
   printf OUTFL "useParameters	No\n";
   printf OUTFL "]]></internalcontrolstrategy>\n";
   printf OUTFL "\t</internalcontrolstrategies>\n";
   printf OUTFL "\t<inputdatabase servername=\"\" databasename=\"\" description=\"\"/>\n";
   printf OUTFL "\t<uncertaintyparameters uncertaintymodeenabled=\"false\" numberofrunspersimulation=\"0\" numberofsimulations=\"0\"/>\n";
   printf OUTFL "\t<geographicoutputdetail description=\"LINK\"/>\n";

   printf OUTFL "\t<outputemissionsbreakdownselection>\n";
   printf OUTFL "\t\t<modelyear selected=\"false\"/>\n";
   printf OUTFL "\t\t<fueltype selected=\"true\"/>\n";
   printf OUTFL "\t\t<fuelsubtype selected=\"false\"/>\n";
   printf OUTFL "\t\t<emissionprocess selected=\"true\"/>\n";
   printf OUTFL "\t\t<onroadoffroad selected=\"true\"/>\n";
   printf OUTFL "\t\t<roadtype selected=\"true\"/>\n";
   printf OUTFL "\t\t<sourceusetype selected=\"true\"/>\n";
   printf OUTFL "\t\t<movesvehicletype selected=\"false\"/>\n";
   printf OUTFL "\t\t<onroadscc selected=\"true\"/>\n";
   printf OUTFL "\t\t<estimateuncertainty selected=\"false\" numberOfIterations=\"2\" keepSampledData=\"false\" keepIterations=\"false\"/>\n";
   printf OUTFL "\t\t<sector selected=\"false\"/>\n";
   printf OUTFL "\t\t<engtechid selected=\"false\"/>\n";
   printf OUTFL "\t\t<hpclass selected=\"false\"/>\n";
   printf OUTFL "\t\t<regclassid selected=\"false\"/>\n";
   printf OUTFL "\t</outputemissionsbreakdownselection>\n";

   printf OUTFL "\t<outputdatabase servername=\"%s\" databasename=\"%s\" description=\"\"/>\n",$dbhost,$outputDB;

   printf OUTFL "\t<outputtimestep value=\"Hour\"/>\n";
   printf OUTFL "\t<outputvmtdata value=\"false\"/>\n";
   printf OUTFL "\t<outputsho value=\"false\"/>\n";
   printf OUTFL "\t<outputsh value=\"false\"/>\n";
   printf OUTFL "\t<outputshp value=\"false\"/>\n";
   printf OUTFL "\t<outputshidling value=\"true\"/>\n";
   printf OUTFL "\t<outputstarts value=\"true\"/>\n";
   printf OUTFL "\t<outputpopulation value=\"true\"/>\n";
   printf OUTFL "\t<databaseselections>\n";
   printf OUTFL "\t\t<databaseselection servername=\"%s\" databasename=\"%s\" description=\"\"/>\n",$dbhost,$scenarioDB."_in";
   printf OUTFL "\t</databaseselections>\n";
   printf OUTFL "\t<scaleinputdatabase servername=\"%s\" databasename=\"%s\" description=\"\"/>\n",$dbhost,$repCDB[$cntyidx];
   printf OUTFL "\t<pmsize value=\"0\"/>\n";
   printf OUTFL "\t<outputfactors>\n";
   printf OUTFL "\t\t<timefactors selected=\"true\" units=\"Hours\"/>\n";
   printf OUTFL "\t\t<distancefactors selected=\"true\" units=\"Miles\"/>\n";
   printf OUTFL "\t\t<massfactors selected=\"true\" units=\"Grams\" energyunits=\"Joules\"/>\n";
   printf OUTFL "\t</outputfactors>\n";
   printf OUTFL "\t<savedata>\n";
   printf OUTFL "\t</savedata>\n";
   printf OUTFL "\t<donotexecute>\n";
   printf OUTFL "\t</donotexecute>\n";

   printf OUTFL "\t<generatordatabase shouldsave=\"false\" servername=\"\" databasename=\"\" description=\"\"/>\n";
   printf OUTFL	"\t\t<donotperformfinalaggregation selected=\"false\"/>\n";
   printf OUTFL "\t<lookuptableflags scenarioid=\"%s\" truncateoutput=\"true\" truncateactivity=\"true\" truncatebaserates=\"true\"/>\n",$scenarioID;
   printf OUTFL "\t<skipdomaindatabasevalidation selected=\"true\"/>\n";

   printf OUTFL "</runspec>\n";

}  # end of rspend subroutine

sub trim
{
    my $s = shift;
    # remove leading spaces
    $s =~ s/^\s+//;
    # remove trailing spaces
    $s =~ s/\s+$//;
    # remove leading tabs
    $s =~ s/^\t+//;
    # remove trailing tabs
    $s =~ s/\t+$//;
    return $s; 
}
