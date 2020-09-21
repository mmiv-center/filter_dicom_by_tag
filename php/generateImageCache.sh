#!/bin/bash

if [ ! "$#" -eq "4" ]; then
    echo "Usage: <uid> <StudyInstanceUID> <SeriesInstanceUID> <dcm_file>"
    exit
fi

uid=$1
StudyInstanceUID=$2
SeriesInstanceUID=$3
dcmfile="$4"

if [ "${SeriesInstanceUID}" == "force" ]; then
    /usr/bin/montage -geometry 32x32+0+0 -background black -tile 6x @/var/www/html/php/data/${uid}/imageIndex.txt "/var/www/html/php/data/${uid}/imageMontage.jpg"
    exit
fi


# store results in output
output="/var/www/html/php/data/${uid}/images"
if [ ! -d "${output}" ]; then
    mkdir -p "${output}"
fi

# we have a single file here, use that instead of shuffle
# file=$( find "${dcmfile}" -type f -print0 | shuf -z -n 1 )
file="${dcmfile}"
if [ -e "${file}" ]; then
    echo "Create one new image from ${file}"
    # using dcmj2pnm to create one image for each Series
    /usr/bin/dcmj2pnm +Sxv 64 +Wh 5 -O "${file}" "${output}/${SeriesInstanceUID}.png"
    
    # using montage to create a single sheet for the project
    # we create an index of the different images first
    find "/var/www/html/php/data/${uid}/images" -type f -print > "/var/www/html/php/data/${uid}/imageIndex.txt"
    if [ -z "$(pidof /usr/bin/montage)" ]; then
	# This might fail for large projects (many series in many studies). The default limit for the height pixel number in ImageMagick
	# is 16K. Adjust this setting to 32k to allow larger projects image cache to build (emacs -nw /etc/ImageMagick-6/policy.xml).
	/usr/bin/montage -geometry 32x32+0+0 -background black -tile 6x @/var/www/html/php/data/${uid}/imageIndex.txt "/var/www/html/php/data/${uid}/imageMontage.jpg"	
    fi
fi
