#!/usr/bin/env bash

#
# export data (batch processing)
#
if [ "$#" -ne "1" ]; then
    echo "Usage: <project folder>"
    exit;
fi

folder="$1"
if [ ! -e "${folder}" ]; then
   echo "Error: control file ${folder} does not exist, or structure file not found."
   exit;
fi

output=`jq -r ".output" "${folder}"`
echo "OK, we are ready to start processing on the information in ${folder}."

# lets start with creating the folder structure
# each .data[i] has a key which is the StudyInstanceUID and a value which is a list of
# SeriesInstanceUIDs

for row in $(jq -r '.data[] | @base64' "${folder}"); do
    _jq() {
        echo ${row} | base64 --decode | jq -r ${1}
    }
    
   echo $(_jq '.key')
done
