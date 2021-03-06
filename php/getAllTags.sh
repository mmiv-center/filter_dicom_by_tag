#!/bin/bash

# parse the directory tree for DICOM files in studies
# we will assume that we have folders in project_name that
# correspond to studies. Parsing them we get image series and
# one example DICOM per folder.
if [ $# -ne 2 ]; then
    echo "Usage: <uid> <project name>"
    exit
fi

uid="$1"
project="$2"

infofilename="/var/www/html/php/data/${uid}/info.json"
if [ ! -f "$infofilename" ]; then
    echo "Error: info.json not found"
    pwd
    exit
fi

# mark this as started by adding the date as startdate
stime=`date`
tmp="$(mktemp)"
/usr/bin/jq '. |= .+ { "startdate": "'"${stime}"'" }' "$infofilename" > "$tmp"
mv "$tmp" $infofilename
rm "$tmp"


# put results into this folder
#output="/var/www/html/php/data/$uid/"
# to speed up read time directly put results into the output folder
output="/var/www/html/php/project_cache/${project}/"
if [ ! -d "/var/www/html/php/project_cache/${project}/" ]; then
    mkdir -p "/var/www/html/php/project_cache/${project}/"
fi

DCMDICTPATH=/usr/share/libdcmtk14/dicom.dic:/usr/share/libdcmtk14/private.dic
#/usr/bin/findscu -v -aet FIONA -aec DICOM_QR_SCP --study -k "(0008,0052)=STUDY" -k "InstitutionName=$project" -k "PatientID" -k "StudyInstanceUID" -od "${od}/" -X +sr --repeat 2 vir-app5274.ihelse.net 7840

# Use the accellerator to make parsing the study faster. This will (usually) pick the best slice in a volume.
ACCELLERATOR="YES"
if [ ${ACCELLERATOR} = "YES" ]; then
    # could take 20min...
    /var/www/html/src_parse_folder_fast/ParseFast -i "/data/${project}" -o "${output}" -t 4 --infofile "${infofilename}"
    # now we still need to generate the image cache
    if [ -e "${output}/convertToPNG.txt" ]; then
        # might be better if we do this using gnu-parallel
        while IFS="" read -r p || [ -n "$p" ]
        do
            SeriesInstanceUID=$(basename $(dirname ${p}))
            StudyInstanceUID=$(basename $(dirname $(dirname ${p})))
            ./generateImageCache.sh ${output} ${StudyInstanceUID} ${SeriesInstanceUID} "${p}"
        done < "${output}/convertToPNG.txt"
    fi
else 
    # instead use manual parsing using dcmtk - slower
    # now ask for all these studies
    OLDIFS=$IFS
    IFS=$'\n'
    fileArray=($(find "/data/${project}" -mindepth 1 -maxdepth 1 -type d))
    IFS=$OLDIFS

    # instead of moving all, lets check first if there is something to do for this study - check for a sequence that has the pattern
    echo "Parse all ${#fileArray[@]} folders in /data/${project}..."
    od2=$(mktemp -d -t reviewTags-pp2-XXXXXXXX)
    tLen=${#fileArray[@]}

    tmp="$(mktemp)"
    /usr/bin/jq '. |= .+ { "total_num_participants": "'"${tLen}"'" }' "$infofilename" > "$tmp"
    mv "$tmp" $infofilename
    rm "$tmp"

    declare -A studiesWithSeries

    for (( i=0; i<${tLen}; i++ ));
    do
        tmp="$(mktemp)"
        /usr/bin/jq '. |= .+ { "num_participant": "'"${i}"'" }' "$infofilename" > "$tmp"
        mv "$tmp" $infofilename
        rm "$tmp"
        
        # get series for this study with sequence per series (download everything)
        folder="${fileArray[$i]}"
        # for each folder create a raw directory structure with folders by series instance uid and a single DICOM file each
        OLDIFS=$IFS
        IFS=$'\n'
        filesPerFolder=($(find "${folder}" -type f))
        IFS=$OLDIFS
        tLenPerFolder=${#filesPerFolder[@]}
        echo "start processing $tLenPerFolder files"
        for (( j=0; j < ${tLenPerFolder}; j++ )); do
            file="${filesPerFolder[$j]}"
            # to speed things up we should check if the filename is something we know can be ignored
            type=`file -b --mime-type "${file}"`
            if [[ $type != "application/dicom" ]]; then
                # ignore this file
                continue
            fi

            unset StudyInstanceUID
            unset SeriesInstanceUID
            unset SOPInstanceUID
            # use a single call of dcmdump to get the UIDs
            $(dcmdump +P SOPInstanceUID +P SeriesInstanceUID +P StudyInstanceUID "${file}" | awk '/[ ]*\([0-9a-z]+,[0-9a-z]+\) [A-Z][A-Z] \[.*/ { gsub(/[\[\]]/,""); print("declare " $7 "=" $3) }')

            # get StudyInstanceUID and SeriesInstanceUID
            #StudyInstanceUID=`dcmdump +P "StudyInstanceUID" "${file}" | cut -d'[' -f 2 | cut -d']' -f1`
            if [[ -z "${StudyInstanceUID}" ]]; then
                continue
            fi
            #SeriesInstanceUID=`dcmdump +P "SeriesInstanceUID" "${file}" | cut -d'[' -f 2 | cut -d']' -f1`
            if [[ -z "${SeriesInstanceUID}" ]]; then
                continue
            fi
            #SOPInstanceUID=`dcmdump +P "SOPInstanceUID" "${file}" | cut -d'[' -f 2 | cut -d']' -f1`
            if [[ ! -z "${SOPInstanceUID}" ]]; then
                # remember every slice using a symbolic link, makes it possible to export later and to debug now
                if [[ ! -d "${output}/${StudyInstanceUID}/${SeriesInstanceUID}" ]]; then
                    mkdir -p "${output}/${StudyInstanceUID}/${SeriesInstanceUID}"
                fi
                ln -s "${file}" "${output}/${StudyInstanceUID}/${SeriesInstanceUID}/${SOPInstanceUID}"
            fi
            if [[ ! -z "${studiesWithSeries[${StudyInstanceUID}${SeriesInstanceUID}]+abc}" ]]; then
                # we only need to keep counting, nothing else to do here
                studiesWithSeries[${StudyInstanceUID}${SeriesInstanceUID}]=$(( studiesWithSeries[${StudyInstanceUID}${SeriesInstanceUID}] + 1 ))
                sed -i "s/(0020,1209) IS \[[0-9]*/(0020,1209) IS \[${studiesWithSeries[${StudyInstanceUID}${SeriesInstanceUID}]}/g" "${output}/${StudyInstanceUID}/${SeriesInstanceUID}.cache"
            else
                studiesWithSeries[${StudyInstanceUID}${SeriesInstanceUID}]=1
                #echo "folder ${output}/${StudyInstanceUID} for this file"
                if [[ ! -d "${output}/${StudyInstanceUID}" ]]; then
                    echo "create folder: ${output}/${StudyInstanceUID}"
                    mkdir -p "${output}/${StudyInstanceUID}"
                fi
                # one file is sufficient
                DCMDICTPATH=/usr/share/libdcmtk14/dicom.dic:/usr/share/libdcmtk14/private.dic /usr/bin/dcmdump "${file}" | grep -v "PixelData" | egrep -v "^#" | grep -v ") FD " \
                    | grep -v ") DT " | grep -v ") DA " \
                    | grep -v ") OD " | grep -v ") UI " | grep -v ") US " \
                    | grep -v ") UL " | grep -v ") SL " | grep -v ") TM " | grep -v ") UN " \
                    | grep -v "1 WindowCenter" | grep -v "1 WindowWidth" | grep -v "1 SliceLocation" \
                    | grep -v "3 ImagePositionPatient" \
                    | sort -u  > ${output}/${StudyInstanceUID}/${SeriesInstanceUID}.cache
                # | egrep -v "[^\[]+\[[+0-9\\-\.]+\].*"
                # store the number of files as well
                echo "(0020,1209) IS [1] # Number of series related images" >> ${output}/${StudyInstanceUID}/${SeriesInstanceUID}.cache

                # we should also create an image cache for this series, it will be best if we create a mosaic
                # to limit the number of files that need to be downloaded by the client
                ./generateImageCache.sh ${uid} ${StudyInstanceUID} ${SeriesInstanceUID} "${file}" &
            fi
        done
    done
fi 

# if we are ready we can mark this in the info.json (start and stop time)
etime=`date`
tmp="$(mktemp)"
/usr/bin/jq '. |= .+ { "enddate": "'"${etime}"'" }' "$infofilename" > "$tmp"
mv "$tmp" $infofilename
rm "$tmp"

./generateImageCache.sh ${output} " " "force" " "

# we don't need a copy now because the data is created in the cache folder

# we can now make a copy of this projects data
#if [ ! -d "/var/www/html/php/project_cache/${project}/" ]; then
#    mkdir -p "/var/www/html/php/project_cache/${project}/"
#fi
# this will fail if we have many files - because the bash command buffer is too small
#cp -R "${output}"* "/var/www/html/php/project_cache/${project}/"
#cp -a "${output}/." "/var/www/html/php/project_cache/${project}/"
