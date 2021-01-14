# Accellerator for parsing projects

In order to speed up the parsing of folders with DICOM files this directory contains source code to create a multi-threaded reader written in C/gdcm. Using this accellerator the speed of data parsing is usually limited by disc access instead of CPU (without accellerator).

See the Dockerfile to find out about requirements and how to build using cmake.
