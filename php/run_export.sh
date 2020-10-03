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

name=`jq -r ".name" "${folder}"`
output=`jq -r ".output" "${folder}"`
echo "OK, we are ready to start processing on the information in ${folder} (${output})."


# lets start with creating the folder structure
# each .data[i] has a key which is the StudyInstanceUID and a value which is a list of
# SeriesInstanceUIDs

for row in $(jq -r '.data | @base64' "${folder}"); do
    _jq() {
        echo ${row} | base64 --decode | jq -r ${1}
    }

    #echo $(_jq 'keys' | jq ".[]")                                                                                                                                                                                                                                                  
    for u in $(_jq 'keys' | jq ".[]"); do
        echo "work on this study: ${u}"
        for v in $(_jq ".[${u}][]"); do
            echo "  series: ${v}"
            # ok, now where is the data?
            p=$(echo ${output}/${u}/${name}/${v} | tr -d '"')
            if [ ! -d "${p}" ]; then
                # we can have the directory already from a previous run
                mkdir -p "${p}"
            fi
        done
    done
done
