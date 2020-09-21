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

infofilename="data/${uid}/info.json"
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
output="data/$uid/"

DCMDICTPATH=/usr/share/dcmtk/dicom.dic
#/usr/bin/findscu -v -aet FIONA -aec DICOM_QR_SCP --study -k "(0008,0052)=STUDY" -k "InstitutionName=$project" -k "PatientID" -k "StudyInstanceUID" -od "${od}/" -X +sr --repeat 2 vir-app5274.ihelse.net 7840

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
    filesPerFolder=($(find "${folder}" -mindepth 1 -maxdepth 1 -type f))
    IFS=$OLDIFS
    tLenPerFolder=${#filesPerFolder[@]}
    echo "start processing $tLenPerFolder files"
    for (( i=0; i < ${tLenPerFolder}; i++ )); do
        file="${filesPerFolder[$i]}"
        # get StudyInstanceUID and SeriesInstanceUID
        StudyInstanceUID=`dcmdump +P "StudyInstanceUID" "${file}" | cut -d'[' -f 2 | cut -d']' -f1`
        SeriesInstanceUID=`dcmdump +P "SeriesInstanceUID" "${file}" | cut -d'[' -f 2 | cut -d']' -f1`
        if [[ -z "${StudyInstanceUID}${SeriesInstanceUID}" ]]; then
            continue
        fi
        if [[ -z "${studiesWithSeries[${StudyInstanceUID}${SeriesInstanceUID}]+abc}" ]]; then
             studiesWithSeries[${StudyInstanceUID}${SeriesInstanceUID}]="${folder}/${file}"
             if [ ! -d "${output}/${StudyInstanceUID}" ]; then
                 echo "create folder: ${output}/${StudyInstanceUID}"
                 mkdir -p "${output}/${StudyInstanceUID}"
             fi
             # one file is sufficient
             /usr/bin/dcmdump "${folder}/${file}" | grep -v "PixelData" | egrep -v "^#" | grep -v ") FD " \
                 | grep -v ") DT " | grep -v ") DA " \
                 | grep -v ") OD " | grep -v ") UI " | grep -v ") US " \
                 | grep -v ") UL " | grep -v ") SL " | grep -v ") TM " | grep -v ") UN " \
                 | grep -v "1 WindowCenter" | grep -v "1 WindowWidth" | grep -v "1 SliceLocation" \
                 | grep -v "3 ImagePositionPatient" \
                 | sort | uniq > ${output}/${StudyInstanceUID}/${SeriesInstanceUID}.cache
             # | egrep -v "[^\[]+\[[+0-9\\-\.]+\].*"
             # store the number of files as well - does not work anymore because we are triggered at the first file here
             # echo "(0020,1209) IS [$(ls "${path}"/* | wc -l)] # Number of series related images" >> ${output}/${StudyInstanceUID}/${SeriesInstanceUID}.cache

             # we should also create an image cache for this series, it will be best if we create a mosaic
             # to limit the number of files that need to be downloaded by the client
             ./generateImageCache.sh ${uid} ${StudyInstanceUID} ${SeriesInstanceUID} "${folder}/${file}" &
        fi
    done
done

# if we are ready we can mark this in the info.json (start and stop time)
etime=`date`
tmp="$(mktemp)"
/usr/bin/jq '. |= .+ { "enddate": "'"${etime}"'" }' "$infofilename" > "$tmp"
mv "$tmp" $infofilename
rm "$tmp"

./generateImageCache.sh ${uid} " " "force"

# we can now make a copy of this projects data
if [ ! -d "/var/www/html/php/project_cache/${project}/" ]; then
    mkdir -p "/var/www/html/php/project_cache/${project}/"
fi
cp -R "/var/www/html/php/${output}"* "/var/www/html/php/project_cache/${project}/"
