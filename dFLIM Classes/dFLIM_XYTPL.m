classdef dFLIM_XYTPL < dFLIM_XYT
    %dFLIM_XYTPL object 
    % Contains a PhotonList (like dFLIM_PhotonList) as the primary data object
    %   calculates an XYT as needed, for specific subframes or all frames
    %   contains validity and offset information
    % CONSTRUCTOR of an empty object (always filled with retrieve or by reading from file) 
    %   dFLIM_XYTPL([],validRange,dfprops);     % USES PARENT CONSTRUCTOR(3)
    % METHODS
    %   dfxytpl.retrieve(hDFS);                 % OVERLOADED
    %   dfh = dfxytpl.roiHisto(mask[,frames])   % OVERLOADED and EXTENDED -
    %      needs code to isolate the relevant frames and lines, then
    %      extract mask-directed data
    
    
    
    properties
% INHERITED
%       Data
%       nsPerPoint
%       tPeakIRF
%       validRange  % two elements, low and high
%       dfProps     % a dFLIM_Props object describing channel content
        photonListData % should be passed as a 1D uint8 array
        nPixels
        nLines
        nFrames
        frameIndex  % rows are frame starts
    end
    
    properties (Constant)
        % values of pixel, line, and frame punctuators
        % extra pixel marks in lines are ignored.
        pxMark = 255; %EOP
        lnMark = 254; %EOL
        frMark = 253; %EOF
    end
    
    methods
        % CONSTRUCTOR
        function xytpl = dFLIM_XYTPL(varargin)  % (dat,validRange,dfprops)
            switch nargin
                case 0
                    validRange = [];
                    tPeakIRF   = [];
                    channel    = [];
                    data       = [];
                    nsPerPoint = [];
                    nFrames    = [];
                case 2  % (validRange,dfprops)
                    validRange = varargin{1};
                    nPixels    = [];
                    nLines     = [];
                    nFrames    = varargin{2}.nFrames;
                    tPeakIRFs  = varargin{2}.tPeakIRFs;
                    channel    = find(tPeakIRFs,1,'first');
                    tPeakIRF   = tPeakIRFs(channel);
                    plist      = [];
                    data       = [];
                    nsPerPoint = .05;
                case 3  % (dat,validRange,dfprops) [legacy]
                    validRange = varargin{2};
                    nPixels    = [];
                    nLines     = [];
                    nFrames    = varargin{3}.nFrames;
                    tPeakIRFs  = varargin{3}.tPeakIRFs;
                    channel    = find(tPeakIRFs,1,'first');
                    tPeakIRF   = tPeakIRFs(channel);
                    plist      = [];
                    data       = varargin{1};
                    nsPerPoint = .05;
                case 7  % (dFLIM_XYTPL(photons{as uint8},nPixels,nLines,nFramesPerCh,tPeakIRF,ch,nsPerPoint);
                    % uses dFLIM_XYT(data,validRange,tPeakIRF,channel,nFrames, nsPerPoint)
                    plist      = varargin{1};
                    validRange = [1 241];
                    nPixels    = varargin{2};
                    nLines     = varargin{3};
                    nFrames    = varargin{4};
                    tPeakIRF   = varargin{5};
                    channel    = varargin{6};
                    data       = [];
                    nsPerPoint = varargin{7};
                otherwise
                    error('dFLIM_XYTPL: no constructor with these arguments');
            end
            xytpl = xytpl@dFLIM_XYT(data,validRange,tPeakIRF,channel,nFrames,nsPerPoint);
            if nargin==0, return; end
            xytpl.photonListData = plist;
            xytpl.nPixels        = nPixels;
            xytpl.nLines         = nLines;
            xytpl.nFrames        = nFrames;
        end
        
        % PUBLIC METHODS
        
        function dfxytpl = retrieve(dfxytpl,dfs)
            chan = dfxytpl.dfProps.firstChannel;
            dfxytpl.photonListData=dfs.retrieveXYTPL(chan);
            dfxytpl.nLines  = dfs.nLines;
            dfxytpl.nPixels = dfs.nPixels;
            dfxytpl.nFrames = dfs.nFrames;
        end
        
        function dfh = roiHisto(dfxytpl,mask,frames)
            % ARRAY FORM OF CALL (doesn't re-use handles)
            if numel(dfxytpl)>1
                if nargin<3, frames=1:dfxytpl(1).nFrames; end
                hstc = arrayfun(@(x) x.roiHisto(mask,frames), dfxytpl, 'UniformOutput', false);
                % arrayfun returns cell array for non-scalars
                % convert it to an array of dFLIM_Histos
                dfh=[hstc{:}];                 % copy
                dfh=reshape(dfh,size(hstc));   % reshape
                return
            end
            % IF WE HAVE A SINGLE dfxytpl, DO THE WORK
            % if this is our first time, calculate the all-frames XYT and
            % the frameIndex
            if isempty(dfxytpl.Data)
                [dfxytpl.Data,dfxytpl.frameIndex] = ...
                    fastXYTFromList(dfxytpl.photonListData,...
                    [256 dfxytpl.nLines dfxytpl.nPixels],dfxytpl.nFrames);
            end
            % compile a histogram
            % default is all frames; if we are doing all frames, use the precompiled XYT
            if nargin<3 || numel(frames)==dfxytpl.nFrames
                dfh = dfxytpl.roiHisto@dFLIM_XYT(mask);
                return
            end
            % need a transposed mask with pixels varying most rapidly
            mskTrans = logical(mask)';
            hst = fastHistFromList(dfxytpl.photonListData,frames,mskTrans(:),dfxytpl.frameIndex);
            dfh = dFLIM_Histo(hst,dfxytpl.validRange,dfxytpl.dfProps);
            dfh.nsPerPoint = dfxytpl.nsPerPoint;
            return
        end
            
        function [dfi,dfh] = dfiFromXYT(dfxytpl,multi)
            % returns a dFLIM_Image and full frame dFLIM_Histo, calculated from
            %   the XYT.  The img is simply set to the nmg, since we don't
            %   have independent info
            % multi==true has us make a dfi/dfh for each subframe
            if nargin<2, multi=false; end
            
            % ARRAY FORM OF CALL - one row of dfi/dfh for each channel
            if numel(dfxytpl)>1
                for k=1:numel(dfxytpl)
                    if nargout==2
                        [dfii,dfhh] = dfxytpl(k).dfiFromXYT(multi);
                        dfi(k,:) = dfii;
                        dfh(k,:) = dfhh;
                    else
                        dfii = dfxytpl(k).dfiFromXYT(multi);
                        dfi(k,:) = dfii;
                    end
                end
                return
            end
            
            % make a provision for an empty dFLIM_XYTPL
            if isempty(dfxytpl.photonListData)
                dfi = dFLIM_Image;
                dfh = dFLIM_Histo;
                return
            end
                 
            % if this is our first time, calculate the all-frames XYT and
            % the frameIndex
            if isempty(dfxytpl.Data)
                [dfxytpl.Data,dfxytpl.frameIndex] = ...
                    fastXYTFromList(dfxytpl.photonListData,...
                    [256 dfxytpl.nLines dfxytpl.nPixels],dfxytpl.nFrames);
            end
            
            rng = dfxytpl.validRange(1):dfxytpl.validRange(2);
            
            if multi
                frm=1:dfxytpl.nFrames;
            else
                frm=1;
            end
            
            for idx=frm  % frm=1 for non-multi and =1:nFrames for multi
                if multi
                    % create an XYT for each single frame, from the photonListData
                    plist = dfxytpl.photonListData(...
                        double(dfxytpl.frameIndex(idx)+1):...
                        double(dfxytpl.frameIndex(idx+1)));
                    [data,~] = fastXYTFromList(plist,[256 dfxytpl.nLines dfxytpl.nPixels],1);
                else
                    % use the all-frames XYT calculated in advance
                    data = dfxytpl.Data;
                end
                
                % calculate the number of single photons/pixel from the XYT
                nmg = squeeze(sum(data(rng,:,:),1));
                
                % calculate the tmg
                %   this is the fastest way in MATLAB, but better to write
                %   a C-program to calculate directly from the photon list 
                rr  = repmat(uint32(rng(:)-1),1,dfxytpl.nLines,dfxytpl.nPixels);
                tmg = squeeze(sum(rr .* data(rng,:,:),1));
                
                % create the dFLIM_Image object
                %   (setting the img to equal the nmg)
                dfi(idx) = dFLIM_Image(nmg,nmg,tmg,dfxytpl.dfProps);
                dfi(idx).nsPerPoint = dfxytpl.nsPerPoint;
                
                % create the dFLIM_Histo object if requested
                if nargout>1
                    dfh(idx) = dFLIM_Histo(sum(sum(dfxytpl.Data,2),3),...
                        dfxytpl.validRange,dfxytpl.tPeakIRF,dfxytpl.dfProps);
                    dfh(idx).nsPerPoint = dfxytpl.nsPerPoint;
                end
            end
        end
        
    end
    
end

