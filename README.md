# Tool to Improve Calibration Accuracy by Characterizing Sphere Sound Speeds

This application is used to estimate the longitudinal and transversal sound speeds of a standard sphere used in calibrations of fisheries echosounders, which will lead to improved calibration results and more accurate sensor measurements. The tool interfaces with the Kongsberg EK80 software to subscribe to wideband (FM) data, using either live or replay data. Wideband spectra from the sphere echo are then compared to theoretical results for the given sphere, and a minimization technique used to estimate the sphere sound speeds that best align the measurements.

## Installation

The software is a Matlab application, and as such is provided in one of two format:
1. A Matlab application file (.mlapp) that can be run using a licensed version of Matlab
2. A standalone executable that can be run on any computer, with or without Matlab

### Standalone Executable (.exe)

To use the standalone executable, download and run the file "[/release/package/MyAppInstaller.exe](/release/package/MyAppInstaller.exe)" from the Github repository. Follow the instructions which should download and install all the required elements needed to run the application (requires an Internet connection for initial installation).

### Matlab Application

Use of the Matlab Application file (.mlapp) required having a licensed version of Matlab installed on the machine. If available, download and run the file "[SphereSoundSpeeds.mlapp](SphereSoundSpeeds.mlapp)" from the Github repository.

## How to Use

TBD

## Disclaimer

This repository is a scientific product and is not official communication of the National Oceanic and Atmospheric Administration, or the United States Department of Commerce. All NOAA GitHub project code is provided on an ‘as is’ basis and the user assumes responsibility for its use. Any claims against the Department of Commerce or Department of Commerce bureaus stemming from the use of this GitHub project will be governed by all applicable Federal law. Any reference to specific commercial products, processes, or services by service mark, trademark, manufacturer, or otherwise, does not constitute or imply their endorsement, recommendation or favoring by the Department of Commerce. The Department of Commerce seal and logo, or the seal and logo of a DOC bureau, shall not be used in any manner to imply endorsement of any commercial product or activity by DOC or the United States Government.
