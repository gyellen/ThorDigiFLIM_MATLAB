classdef dFLIM_PhotonList < matlab.mixin.Copyable
    %dFLIM_PhotonList object 
    %   contains validity and offset information
    % CONSTRUCTOR 
    %   dFLIM_XYT(punctuatedListData,tPeakIRF,validRange,channel[,nFrames[,nsPerPoint]])
    % METHODS
    %   hstc = combine(hst1,hst2)
    
    
    properties
        photonListData % should be passed as a 1D uint8 array
        nsPerPoint
        tPeakIRF
        validRange  % two elements, low and high
        dfProps     % a dFLIM_Props object describing channel content
        nPixels
        nLines
        nFrames
        frameLineIndex  % rows are frame starts, cols are line starts (after the first line)
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
        function phList = dFLIM_PhotonList(photonListData, nPixels, nLines, nFrames, tPeakIRF, channel, nsPerPoint)
            
            % full constructor:
            % dfPL = dFLIM_PhotonList(photonListData, nPixels, nLines, nFrames, tPeakIRF, channel, nsPerPoint);
            phList.nPixels = nPixels;
            phList.nLines = nLines;
            phList.nFrames = nFrames;
            phList.tPeakIRF = tPeakIRF;
            phList.nsPerPoint = nsPerPoint;
            phList.dfProps=dFLIM_Props(channel,phList.tPeakIRF,nFrames);
            phList.photonListData = uint8(photonListData(:));  % always a col byte vector
            
            % parse the photonListData to construct a frame and line index
            % find the frame ends
            framemarks = find(phList.photonListData==dFLIM_PhotonList.frMark);
            frames = [1; framemarks(1:end-1)+1]; 
            if phList.nFrames ~= numel(frames)
                disp(['dFLIM_PhotonList constructor: declared nFrames (' num2str(phList.nFrames) ...
                    ' doesn''t match number of EOF marks (' num2str(numel(frames))]);
                disp('Setting nFrames to match actual');
                phList.nFrames = numel(frames);
            end
            phList.frameLineIndex = zeros(phList.nFrames,phList.nLines+1);
            for k=1:phList.nFrames
                linemarks = find(phList.photonListData(frames(k):framemarks(k)-1)==dFLIM_PhotonList.lnMark);
                % first column is the beginning of each frame; include the last line mark as the 'end+1' value
                % the line contents (exclusive of line and frame
                % punctuation) are FLI(frame,line) : FLI(frame,line+1)-2
                phList.frameLineIndex(k,:) = [frames(k) linemarks(1:end)'+frames(k)];  
            end
                
            
            
            return
            
            % valid constructor forms:
            % 0: dFLIM_XYT() returns empty/zero object
            % 3: dFLIM_XYT(data,validRange,dFLIM_Props_obj) 
            %    uses properties from dFLIM_Props_object
            %    tPeakIRF is derived from the first dFLIM_Props value
            %    nsPerPoint is set to 0.05
            % 4: dFLIM_XYT(data,validRange,tPeakIRF,channel)
            % 5: dFLIM_XYT(data,validRange,tPeakIRF,channel,nFrames)
            % 6: dFLIM_XYT(data,validRange,tPeakIRF,channel,nFrames, nsPerPoint)
            
%             hst.nsPerPoint=0.05;
%             switch nargin
%                 case 0
%                     hst.dfProps=dFLIM_Props([],[],[]);
%                     return
%                 case 3
%                     hst.Data=varargin{1};
%                     hst.validRange=varargin{2};
%                     hst.dfProps=varargin{3};
%                     hst.tPeakIRF=hst.dfProps.tPeakIRF; 
%                 case 4
%                     hst.Data=varargin{1};
%                     hst.validRange=varargin{2};
%                     hst.dfProps=varargin{3};
%                     hst.tPeakIRF=hst.dfProps.tPeakIRF;
%                 case {4,5,6}
%                     hst.Data=varargin{1};
%                     hst.validRange=varargin{2};
%                     hst.tPeakIRF=varargin{3};
%                     if nargin>4, nFrames=varargin{5}; else nFrames=1; end
%                     hst.dfProps=dFLIM_Props(varargin{4},hst.tPeakIRF,nFrames);
%                     if nargin>5, hst.nsPerPoint=varargin{6}; end                        
%             end
        end

        
        % PUBLIC METHODS
        
        function dfxyt=sumxyt(dfpl)
            % array function - accumulates df_XYT from multiple dfpl's
            xyt = [241 dfpl(1).nLines dfpl(1).nPixels];  % starting value for first call
            for k=1:numel(dfpl)
                xyt = fastParsePhotonList(dfpl(k).photonListData,xyt);
            end
            dfp = copy(dfpl(1).dfProps);
            dfp.nFrames = dfp.nFrames * numel(dfpl);  % assumes each component has the same number, probably 1
            dfxyt = dFLIM_XYT(xyt,[1 241],dfp);
            dfxyt.nsPerPoint = dfpl(1).nsPerPoint;
        end
        
        
        function dfxyt=xyt(dfpl,frameList)
           if nargin<2, frameList = 1:dfpl.nFrames; end
           
%            xyt = single(zeros(241,dfpl.nLines,dfpl.nPixels)); % standard empty
%            % logic is right but this is very slow - need to code in C
%            for fr=frameList(:)'  % over all the requested frames
%                for ln=1:dfpl.nLines
%                    px=1;
%                    for ii=dfpl.frameLineIndex(fr,ln):dfpl.frameLineIndex(fr,ln+1)-2
%                        item=dfpl.photonListData(ii);
%                        if item==dFLIM_PhotonList.pxMark
%                            px=px+1;
%                        else
%                            xyt(item+1,ln,px)=xyt(item+1,ln,px)+1;
%                        end
%                    end
%                end
%            end
           ix1 = dfpl.frameLineIndex(frameList(1),1);
           ix2 = dfpl.frameLineIndex(frameList(end),end)-2;
           xyt = fastParsePhotonList(dfpl.photonListData(ix1:ix2),...
               [241 dfpl.nLines dfpl.nPixels]);
           dfp = (dfpl.dfProps); % was copy()
           dfp.nFrames = numel(frameList);
           dfxyt = dFLIM_XYT(xyt,[1 241],dfp);
           dfxyt.nsPerPoint = dfpl.nsPerPoint;
        end
        
    end
    
end

