ThorDigiFLIM_MATLAB
Gary Yellen 2022

ThorDigiFLIM_MATLAB provides MATLAB utilities for handling image data from Thorimage, with a focus on digiFLIM data.  Interprocess communication is also enabled for Thorimage 5.0.

*Sample dFLIM Viewer* contains a runnable GUIDE-based GUI, *TI_Viewer_Lg*, to view images in a Thorimage-stored experiment. The global variable TI_Viewer_app contains a TIExpt object and data objects; viewing the object contents and reading the TI_Viewer code can help a user who is interested in developing their own applications.

*Utilities* contains the *TIExpt* object for reading a Thorimage-stored experiment.

*dFLIM Classes* contains data objects to contain lifetime images (*dFLIM_Image*), decay histograms (*dFLIM_Histo*), and full pixel-wise decay data (*dFLIM_XYTPL*).  Each class has methods for data extraction (e.g. values within ROIs).

*IPC* contains a MATLAB app (*ThorIPC*) that can establish communication with Thorimage 5.0 and receive file-written notifications.  It maintains a queue of available new files.

*Fitting classes* contains specialized decay fitting objects and code used by the sample viewer.



Minimum requirements:
MATLAB R2021b
Thorimage 5.0 (for IPC)
