#!/bin/bash
#
# Automate the startup of the docker container. We assume here we can do sudo to interface with docker.
# This might ask the user to authenticate if sudo is required. We assume also that we can use the
# directory of this script to store the cache and exports folders.
#
if [ "$#" -ne "1" ]; then
   echo "Usage: <folder with data>"
   echo "   This script will create two additional folders for cached results and for exported data"
   echo "   in the current directory (cached, exports)."
   echo ""
   echo "   If you want to use another folder for the cached and export results you may copy"
   echo "   this script to that location. Created folders are relative to the location of the"
   echo "   script."
   exit
fi

# check if the docker container exists
echo "Do we have the docker container? The next step might ask for your sudo permission to run docker."
if [[ ! "$(sudo docker image inspect filter_dicom_by_tag)" ]]; then
   echo "Error: the filter_dicom_by_tag docker container could not be found locally. Create the docker container first before calling this script."
   exit
fi
echo "Yes, the filter_dicom_by_tag container could be found locally."

# Expose the program on this port (use http://localhost:80 to see the interface).
# The default port used by the Dockerfile inside the container is port 8888.
PORT=80

if [ ! -r "$1" ]; then
   echo "Error: data folder does not exist or is not readable (${1})"
   exit
fi
dir_resolve() {
  cd "$*" 2>/dev/null || return $?  # cd to desired directory; if fail, quell any error messages but return exit status
  echo "`pwd -P`" # output full, link-resolved path
}

DATA=$(dir_resolve "${1}")
echo "  Info: use \"${DATA}\" as the data folder. Any folder found inside will be treated as a project."

# The directory that this script is in.
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

if [ -d "${DIR}/cache" ]; then
   echo "  Info: Re-use an existing cache folder to store models (${DIR}/cache)."
else
   echo "  Create cache folder in the script directory \"${DIR}/cache\" (store parsed models across runs)."
   mkdir -p "${DIR}/cache"
fi

if [ -d "${DIR}/exports" ]; then
   echo "  Info: Re-use an existing exports folder to store exported results (${DIR}/exports)"
else
   echo "  Create exports folder in the script directory \"${DIR}/exports\" (store exported selections)."
   mkdir -p "${DIR}/exports"
fi

# Finally run docker. Running this next line in the background with '-d' is not working as expected.
sudo docker run --rm -d -p ${PORT}:8888 -v "${DATA}":/data -v "${DIR}/cache":/var/www/html/php/project_cache -v "${DIR}/exports":/var/www/html/php/exports filter_dicom_by_tag &

echo "It might take a while for the container to response. Connect at http://localhost:${PORT}"
echo ""
