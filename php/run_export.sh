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
id=`jq -r ".id" "${folder}"`
project_name=`jq -r ".project" "${folder}"`
echo "OK, we are ready to start processing on the information in ${folder} (${output})."

tmp="$(mktemp)"
/usr/bin/jq '. |= .+ { "startdate": "'"${stime}"'" }' "$folder" > "$tmp"
mv "$tmp" $folder

# lets start with creating the folder structure
# each .data[i] has a key which is the StudyInstanceUID and a value which is a list of
# SeriesInstanceUIDs

c=0
for row in $(jq -r '.data | @base64' "${folder}"); do
    _jq() {
        echo ${row} | base64 --decode | jq -r ${1}
    }
    for u in $(_jq 'keys' | jq ".[]"); do
        echo "work on this study: ${u}"
        StudyInstanceUID=$(echo ${u} | tr -d '"')
        for v in $(_jq ".[${u}][]"); do
            echo "  series: ${v}"
            # ok, now where is the data?
            # This could be a problem if the path to the data contains double quotes...
            p=$(echo ${output}/${u}/${name}/${v} | tr -d '"')
            if [ ! -d "${p}" ]; then
                # we can have the directory already from a previous run
                mkdir -p "${p}"
            fi
            c=$(( c + 1 ))
            /usr/bin/cp -L -R "/var/www/html/php/project_cache/${project_name}/${StudyInstanceUID}/${v}/"* "${p}/"
            # store the number of exported image series
            tmp="$(mktemp)"
            /usr/bin/jq '. |= .+ { "num_exported": "'"${c}"'" }' "$folder" > "$tmp"
            mv "$tmp" $folder
        done
    done
done

tmp="$(mktemp)"
/usr/bin/jq '. |= .+ { "enddate": "'"${stime}"'" }' "$folder" > "$tmp"
mv "$tmp" $folder
