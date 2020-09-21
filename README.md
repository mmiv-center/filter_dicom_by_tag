# Filter DICOM data by DICOM tags

Create a docker container by running
```
docker build -t filter_dicom_by_tag -f Dockerfile .
```
in the directory of this project.

Start the container like this:
```
docker run --rm -d -p 80:80 -v /my/folder/with/projects:/data filter_dicom_by_tag 
```
