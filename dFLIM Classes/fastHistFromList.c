/* 
 *  This is a MEX file for MATLAB
 *  hst = fastHistFromList(photonList,frames,mask[,frIdx]);
 *     photonList is a pixel-punctuated 1D array, with the possibility of multiple frames
 *     frames is a 1-D array of frame numbers (as doubles)
 *     mask is a 1-D array of logicals (pixels vary faster than lines)
 *     hst is a 256-element 1-D UINT32 array with the histogram values
 *     frIdx is a (nFrames+1 x 1) UINT32 array with the byte offsets of the frames
 */
 
#include "mex.h"
#include "matrix.h"
#include <Windows.h>
 
/* The gateway function */
void mexFunction(int nlhs, mxArray *plhs[],
                 int nrhs, const mxArray *prhs[])
{
/* variable declarations here */
/*	const byte EOP = 255;
	const byte EOL = 254;
	const byte EOF = 253; */
    byte *photonList; // the photonList
	double *frames;     // list of frame numbers (1 based)
	mxLogical *mask;  // the mask

    // mxChar *outBytes; 
    byte b;
    /* int position, length;
    int *pos,*len;
    int dim_t, dim_x, dim_y;
    int ix; */
    size_t nBytes, nFrames, nMask;
    UINT32_T *hst;                       /* pointer to output data */
    mwSize dims[2] = {256,1};
	mwSize nFramesInIdx;
	UINT32_T *frIdx;
    mxClassID arg4class;
    /* mwSize ndim = 3;
    mwSize ndim_in;
    mwSize elements;
    mwSize *xytdims;
    mxClassID arg2class; */
    int k, kInitial, iLine, iPixel, iFrame;
	int iFrameIn, iFrameNow, iPixInFrame;
    
if(nrhs < 3) {
    mexErrMsgIdAndTxt("MyToolbox:fastHistFromList:nrhs",
                      "Three inputs required (photonList,frames,mask).");
} 

/* get the input stream */
    photonList = (byte *)mxGetChars(prhs[0]);
    if(photonList == 0) {
        mexErrMsgIdAndTxt("MyToolbox:fastHistFromList:arg1_photonList",
                "Byte array required.");
    }
	nBytes = mxGetNumberOfElements(prhs[0]);
	
/* get the frame list */
	frames = mxGetPr(prhs[1]);
    if(frames == 0) {
        mexErrMsgIdAndTxt("MyToolbox:fastHistFromList:arg2_frames",
                "Double array required.");
    }
	nFrames = mxGetNumberOfElements(prhs[1]);
	
/* get the mask */
	mask   = mxGetLogicals(prhs[2]);
    if(mask == 0) {
        mexErrMsgIdAndTxt("MyToolbox:fastHistFromList:arg3_mask",
                "Logical array required.");
    }
	nMask = mxGetNumberOfElements(prhs[0]);

/* use the frame index if it's there */
	kInitial  = 0;  // default start of search
	iFrame    = 0;  // frame number at start of search 
	iFrameIn  = 0;  // position in frame list
	iFrameNow = (int) frames[iFrameIn]-1;  // first frame wanted

	if(nrhs == 4) {
		arg4class = mxGetClassID(prhs[3]);   
		if (arg4class == mxUINT32_CLASS) {			
			frIdx = (UINT32_T *) mxGetData(prhs[3]);
			nFramesInIdx = mxGetNumberOfElements(prhs[3])-1;
			if (iFrameNow >= 0  && iFrameNow < nFramesInIdx) {
				kInitial = frIdx[iFrameNow];
				if (kInitial < nBytes) {
					iFrame = iFrameNow;  // we're starting at the correct frame
				}		
				else {
					kInitial = 0;
				}
			}
		}
	}

// create the output array    
    /* Create a 256-by-1 mxArray */
    plhs[0] = mxCreateNumericArray(2, dims, mxUINT32_CLASS, mxREAL);
	hst     = (UINT32_T *) mxGetData(plhs[0]);
	    
    iLine = 0;
    iPixel = 0;
	iPixInFrame = 0;
	
   
    for (k=kInitial; k<nBytes; k++) {
        b = photonList[k];
        switch(b) {
            case 255 :
                iPixel = iPixel + 1;
				iPixInFrame = iPixInFrame + 1;
                break;
            case 254 :
                iLine = iLine + 1;
                iPixel = 0;
				iPixInFrame = iPixInFrame + 1;
                break;
            case 253 : 
                iFrame = iFrame + 1;
                iPixel = 0;
                iLine = 0;
				iPixInFrame = 0;
				if (iFrame>iFrameNow) {
					iFrameIn = iFrameIn+1;
					// are we out of frames to do?
					if (iFrameIn >= nFrames) {
						k = nBytes;  // force the loop to terminate; we're done
					}
					// get the next frame number to use
					iFrameNow = (int) frames[iFrameIn] - 1;
				}
                break;
            default :
				// decide whether to count this 
				if ((iFrame == iFrameNow) && (iPixInFrame < nMask) && mask[iPixInFrame]) {
					hst[b] = hst[b] + 1;  // counted!
				}
        }
    }
    return;

}