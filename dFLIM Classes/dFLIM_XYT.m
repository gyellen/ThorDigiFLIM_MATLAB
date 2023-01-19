classdef dFLIM_XYT < matlab.mixin.Copyable
    %dFLIM_XYT 1D Histogram object 
    %   contains validity and offset information
    % CONSTRUCTOR 
    %   dFLIM_XYT(xytData,tPeakIRF,validRange,channel[,nFrames[,nsPerPoint]])
    % METHODS
    %   hstc = combine(hst1,hst2)
    
    
    properties
        Data
        nsPerPoint
        tPeakIRF
        validRange  % two elements, low and high
        dfProps     % a dFLIM_Props object describing channel content
    end
    
    methods
        % CONSTRUCTOR
        function hst = dFLIM_XYT(varargin)
            % valid constructor forms:
            % 0: dFLIM_XYT() returns empty/zero object
            % 3: dFLIM_XYT(data,validRange,dFLIM_Props_obj) 
            %    uses properties from dFLIM_Props_object
            %    tPeakIRF is derived from the first dFLIM_Props value
            %    nsPerPoint is set to 0.05
            % 4: dFLIM_XYT(data,validRange,tPeakIRF,channel)
            % 5: dFLIM_XYT(data,validRange,tPeakIRF,channel,nFrames)
            % 6: dFLIM_XYT(data,validRange,tPeakIRF,channel,nFrames, nsPerPoint)
            
            hst.nsPerPoint=0.05;
            switch nargin
                case 0
                    hst.dfProps=dFLIM_Props([],[],[]);
                    return
                case 3
                    hst.Data=varargin{1};
                    hst.validRange=varargin{2};
                    hst.dfProps=varargin{3};
                    hst.tPeakIRF=hst.dfProps.tPeakIRF; 
                case 4
                    hst.Data=varargin{1};
                    hst.validRange=varargin{2};
                    hst.dfProps=varargin{3};
                    hst.tPeakIRF=hst.dfProps.tPeakIRF;
                case {4,5,6}
                    hst.Data=varargin{1};
                    hst.validRange=varargin{2};
                    hst.tPeakIRF=varargin{3};
                    if nargin>4, nFrames=varargin{5}; else nFrames=1; end
                    hst.dfProps=dFLIM_Props(varargin{4},hst.tPeakIRF,nFrames);
                    if nargin>5, hst.nsPerPoint=varargin{6}; end                        
            end
        end

        
        % PUBLIC METHODS
        
        function dfxyt=setTPeakIRF(dfxyt, val)
            % ARRAY FORM OF CALL (doesn't re-use handles)
            for k=1:numel(dfxyt)
                dfxyt(k).tPeakIRF=val;
            end
        end

        function hst = roiHisto(dxyt,mask)
            
            % ARRAY FORM OF CALL (doesn't re-use handles)
            if numel(dxyt)>1
                hstc = arrayfun(@(x) x.roiHisto(mask), dxyt, 'UniformOutput', false);
                % arrayfun returns cell array for non-scalars
                % convert it to an array of dFLIM_Histos
                %hst=dFLIM_Histo;                % initialize
                %hst(numel(hstc))=dFLIM_Histo;   % allocate
                hst=[hstc{:}];                 % copy
                hst=reshape(hst,size(hstc));    % reshape
                return
            end

            if isempty(dxyt.Data)
                hst = dFLIM_Histo;
                return
            end
            
            szXYT=size(dxyt.Data);
            % sum all of the masked pixels, using a linear version
            %   of the mask as indices into the reshaped XYT array
            xytShaped=reshape(dxyt.Data,szXYT(1),[]);
            lifetime=sum(xytShaped(:,logical(mask(:))),2);
            % dFLIM_Histo(data,validRange,tPeakIRF,channel,nFrames, nsPerPoint)
            hst=dFLIM_Histo(lifetime,dxyt.validRange,dxyt.dfProps);
            hst.tPeakIRF = dxyt.tPeakIRF;
            hst.nsPerPoint = dxyt.nsPerPoint;
        end
        
        function dfxyt = retrieve(dfxyt,dfs)
            chan = dfxyt.dfProps.firstChannel;
            dfxyt.Data=dfs.retrieveXYT(chan);
        end

        
    end
    
end

