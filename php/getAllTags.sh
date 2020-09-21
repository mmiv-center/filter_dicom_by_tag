#!/bin/bash

# pull all data from IDS for this project and produce file lists for unique tags over time
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

od=$(mktemp -d -t reviewTags-XXXXXXXX)

DCMDICTPATH=/usr/share/dcmtk/dicom.dic
/usr/bin/findscu -v -aet FIONA -aec DICOM_QR_SCP --study -k "(0008,0052)=STUDY" -k "InstitutionName=$project" -k "PatientID" -k "StudyInstanceUID" -od "${od}/" -X +sr --repeat 2 vir-app5274.ihelse.net 7840

# now ask for all these studies
OLDIFS=$IFS
IFS=$'\n'
fileArray=($(find $od -type f))
IFS=$OLDIFS


# instead of moving all, lets check first if there is something to do for this study - check for a sequence that has the pattern
echo "Download all DICOM files..."
od2=$(mktemp -d -t reviewTags-pp2-XXXXXXXX)
tLen=${#fileArray[@]}

tmp="$(mktemp)"
/usr/bin/jq '. |= .+ { "total_num_participants": "'"${tLen}"'" }' "$infofilename" > "$tmp"
mv "$tmp" $infofilename
rm "$tmp"

for (( i=0; i<${tLen}; i++ ));
do
    tmp="$(mktemp)"
    /usr/bin/jq '. |= .+ { "num_participant": "'"${i}"'" }' "$infofilename" > "$tmp"
    mv "$tmp" $infofilename
    rm "$tmp"
    
    # get series for this study with sequence per series (download everything)
    file="${fileArray[$i]}"
    StudyInstanceUID=`dcmdump +P "StudyInstanceUID" "${file}" | cut -d'[' -f 2 | cut -d']' -f1`
    PatientID=`dcmdump +P "PatientID" "${file}" | cut -d'[' -f 2 | cut -d']' -f1`
    \rm -f "${od2}/${StudyInstanceUID}/*"
    if [ ! -d "${od2}/${StudyInstanceUID}" ]; then
	mkdir -p "${od2}/${StudyInstanceUID}"
    fi

    # we need the list of series, so movescu each one individually
    /usr/bin/findscu -v -S -aet FIONA -aec DICOM_QR_SCP -k "(0008,0052)=SERIES" -k "StudyInstanceUID=$StudyInstanceUID" -k "SeriesInstanceUID" -od "${od2}/${StudyInstanceUID}/" -X +sr --repeat 2 vir-app5274.ihelse.net 7840

    echo "Start loop to get all images for this study: $StudyInstanceUID folder: ${od2}/$StudyInstanceUID"
    # now check in each of these if we get a value (they are structured reports here, so move them to our disk)
    series=($(find "${od2}/${StudyInstanceUID}/" -type f))
    seriesLen=${#series[@]}
    for (( j=0; j<${seriesLen}; j++ ));
    do
	ser="${series[$j]}"
	echo "${ser} `dcmdump ${ser}`"
        #label=`dcmdump -q  +P "0070,0006" "${ser}" | cut -d'[' -f2 | cut -d']' -f1`
        SeriesInstanceUID=`dcmdump -q +P "SeriesInstanceUID" "${ser}" | cut -d'[' -f2 | cut -d']' -f1`
	# get all unique tags for this series
	path="/data/site/raw/${StudyInstanceUID}/${SeriesInstanceUID}"
	if [ ! -d "${path}" ]; then
            /usr/bin/movescu -v -aet FIONA -aec DICOM_QR_SCP --study -k "0008,0052=SERIES" -k "StudyInstanceUID=$StudyInstanceUID" -k "SeriesInstanceUID=$SeriesInstanceUID" -aem "FIONA_AI" vir-app5274.ihelse.net 7840
	fi
	echo "Get dcmdump from all files in ${path}/*"
	mkdir -p "${output}/${StudyInstanceUID}"
	/usr/bin/dcmdump "${path}"/* | grep -v "PixelData" | egrep -v "^#" | grep -v ") FD " \
	    | grep -v ") DT " | grep -v ") DA " \
	    | grep -v ") OD " | grep -v ") UI " | grep -v ") US " \
	    | grep -v ") UL " | grep -v ") SL " | grep -v ") TM " | grep -v ") UN " \
	    | grep -v "1 WindowCenter" | grep -v "1 WindowWidth" | grep -v "1 SliceLocation" \
	    | grep -v "3 ImagePositionPatient" \
	    | sort | uniq > ${output}/${StudyInstanceUID}/${SeriesInstanceUID}.cache
	# | egrep -v "[^\[]+\[[+0-9\\-\.]+\].*"
	# store the number of files as well
	echo "(0020,1209) IS [$(ls "${path}"/* | wc -l)] # Number of series related images" >> ${output}/${StudyInstanceUID}/${SeriesInstanceUID}.cache

	# we should also create an image cache for this series, it will be best if we create a mosaic
	# to limit the number of files that need to be downloaded by the client
	./generateImageCache.sh ${uid} ${StudyInstanceUID} ${SeriesInstanceUID} &	
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
if [ ! -d "/var/www/html/applications/Filter/php/project_cache/${project}/" ]; then
    mkdir -p "/var/www/html/applications/Filter/php/project_cache/${project}/"
fi
cp -R "/var/www/html/applications/Filter/php/${output}"* "/var/www/html/applications/Filter/php/project_cache/${project}/"
