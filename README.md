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

### Step 1: Connect to EK80

1. Enter the IP address of the EK80 server in the "EK80 IP" box (this can be found in the Diagnostics window of the Setup menu in the EK80 software).
2. Click the "Connect" button. If successful, the radio button should turn green and a list of transceivers operating in FM mode should populate in the "Transceivers" box

### Step 2: Capture TS/Sv Spectra

1. In the "Transceivers" box, select the channel for which to obtain sphere TS/Sv
2. In the "Sv(f) Settings" panel, define the layer properties for which to obtain Sv(f) data (i.e., identify where the sphere echo is)
3. Press the "Detect" button. The figure window should then begin to populate with Sv(f) data for the selected transceiver channel. It will continue averaging data until the "Detect" button is depressed.
4. Press the "Detect" button again (to depress is) after the desired spectra is obtained.
5. Repeat Steps 2-4 for any additional transceiver channels for which Sv(f) is desired.

### Step 3: Estimate Sphere Sound Speeds

1. Once the desired Sv(f) is obtained, press the "Connect" button to disconnect from the EK80 server. The radio button should then turn red and the "Estimate" button should become enabled
2. In the "Sound Speed Estimation" panel, enter the applicable sphere and water properties (i.e., sphere diameter and density, and water density and sound speed)
3. (Optional) In the bottom-left corner of the app, enter any frequency stopbands for which you desire to remove parts of the Sv(f) spectra (e.g., areas where noise dominates the signal).
4. Press the "Estimate" button to begin the estimation process. The "Status" text box will indicate when the estimation procedure is complete.
5. Note the estimated longitudinal and transversal sound speeds

## Disclaimer

This repository is a scientific product and is not official communication of the National Oceanic and Atmospheric Administration, or the United States Department of Commerce. All NOAA GitHub project code is provided on an ‘as is’ basis and the user assumes responsibility for its use. Any claims against the Department of Commerce or Department of Commerce bureaus stemming from the use of this GitHub project will be governed by all applicable Federal law. Any reference to specific commercial products, processes, or services by service mark, trademark, manufacturer, or otherwise, does not constitute or imply their endorsement, recommendation or favoring by the Department of Commerce. The Department of Commerce seal and logo, or the seal and logo of a DOC bureau, shall not be used in any manner to imply endorsement of any commercial product or activity by DOC or the United States Government.
