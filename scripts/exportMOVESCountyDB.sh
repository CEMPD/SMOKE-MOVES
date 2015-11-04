#!/bin/bash

county="06001"
db="c06001y2011_20150301"
user="moves"
pass="moves"

if [ ! -d $county ]; then
  mkdir $county
fi

echo 'sourceTypeID,yearID,ageID,ageFraction' > $county/agedistribution.csv
mysql -u $user -p$pass $db -Ns -e "SELECT * FROM sourcetypeagedistribution" | tr '\t' ',' >> $county/agedistribution.csv

echo 'sourceTypeID,roadTypeID,hourDayID,avgSpeedBinID,avgSpeedFraction' > $county/avgspeeddistribution.csv
mysql -u $user -p$pass $db -Ns -e "SELECT * FROM avgspeeddistribution" | tr '\t' ',' >> $county/avgspeeddistribution.csv

echo 'sourceTypeID,monthID,roadTypeID,dayID,dayVMTFraction' > $county/dayvmtfraction.csv
mysql -u $user -p$pass $db -Ns -e "SELECT * FROM dayvmtfraction" | tr '\t' ',' >> $county/dayvmtfraction.csv

echo 'sourceTypeID,modelYearID,fuelTypeID,engTechID,fuelEngFraction' > $county/fuelavft.csv
mysql -u $user -p$pass $db -Ns -e "SELECT * FROM avft" | tr '\t' ',' >> $county/fuelavft.csv

echo 'fuelFormulationID,fuelSubtypeID,RVP,sulfurLevel,ETOHVolume,MTBEVolume,ETBEVolume,TAMEVolume,aromaticContent,olefinContent,benzeneContent,e200,e300,BioDieselEsterVolume,CetaneIndex,PAHContent,T50,T90' > $county/fuelformulation.csv
mysql -u $user -p$pass $db -Ns -e "SELECT * FROM fuelformulation" | tr '\t' ',' >> $county/fuelformulation.csv

echo 'fuelRegionID,fuelYearID,monthGroupID,fuelFormulationID,marketShare,marketShareCV' > $county/fuelsupply.csv
mysql -u $user -p$pass $db -Ns -e "SELECT * FROM fuelsupply" | tr '\t' ',' >> $county/fuelsupply.csv

echo 'countyID,fuelYearID,modelYearGroupID,sourceBinFuelTypeID,fuelSupplyFuelTypeID,usageFraction' > $county/fuelusage.csv
mysql -u $user -p$pass $db -Ns -e "SELECT * FROM fuelusagefraction" | tr '\t' ',' >> $county/fuelusage.csv

echo 'sourceTypeID,roadTypeID,dayID,hourID,hourVMTFraction' > $county/hourvmtfraction.csv
mysql -u $user -p$pass $db -Ns -e "SELECT * FROM hourvmtfraction" | tr '\t' ',' >> $county/hourvmtfraction.csv

echo 'HPMSVtypeID,yearID,VMTGrowthFactor,HPMSBaseYearVMT' > $county/hpmsvtypeyear.csv
mysql -u $user -p$pass $db -Ns -e "SELECT * FROM hpmsvtypeyear" | tr '\t' ',' >> $county/hpmsvtypeyear.csv

echo 'polProcessID,stateID,countyID,yearID,sourceTypeID,fuelTypeID,IMProgramID,begModelYearID,endModelYearID,inspectFreq,testStandardsID,useIMyn,complianceFactor' > $county/imcoverage.csv
mysql -u $user -p$pass $db -Ns -e "SELECT * FROM imcoverage" | tr '\t' ',' >> $county/imcoverage.csv

echo 'sourceTypeID,monthID,monthVMTFraction' > $county/monthvmtfraction.csv
mysql -u $user -p$pass $db -Ns -e "SELECT * FROM monthvmtfraction" | tr '\t' ',' >> $county/monthvmtfraction.csv

echo 'yearID,sourceTypeID,salesGrowthFactor,sourceTypePopulation,migrationrate' > $county/population.csv
mysql -u $user -p$pass $db -Ns -e "SELECT * FROM sourcetypeyear" | tr '\t' ',' >> $county/population.csv

echo 'sourceTypeID,roadTypeID,roadTypeVMTFraction' > $county/roadtypedistribution.csv
mysql -u $user -p$pass $db -Ns -e "SELECT * FROM roadtypedistribution" | tr '\t' ',' >> $county/roadtypedistribution.csv
