classdef dFLIM_Props 
%gy added this for dFLIM_PhotonList, but reversed due to problems with setups 
% < matlab.mixin.Copyable
    %dFLIM_Props contains information about the data provenance
    %   constructor: dFLIMProps(channel,tPeakIRF,nFrames)
    %   methods: dfp = combine(dfp1,dfp2)
    %       if identical channel content, nFrames is summed
    %       if different channel content, combine info and keep dfp1.nFrames
    
    % in v2.1, primaryChannels is not stored explicitly.  Instead,
    % tPeakIRFs is a fixed size array (1:8) for all possible digital
    % channels.  A zero-value indicates that the channel is not used.
    
    properties
        tPeakIRFs % always 8-valued
        nFrames
    end
    
    methods
        function dfp = dFLIM_Props(varargin)  % channel,tPeakIRF,nFrames; OR tPeakIRFs,nFrames
            % from outside the class, the constructor is only ever called 
            % with a single channel and its tPeakIRF
            if nargin==3  % channel,tPeakIRF,nFrames
                dfp.tPeakIRFs = zeros(1,8);
                dfp.tPeakIRFs(varargin{1}) = varargin{2};
                dfp.nFrames = varargin{3};
            elseif nargin==2
                dfp.tPeakIRFs = varargin{1};
                dfp.nFrames = varargin{2};
            else
                error('Unknown constructor call');
            end
        end
        
        function dfp = combine(dfp1,dfp2)
            idxSame = (dfp1.tPeakIRFs==dfp2.tPeakIRFs);
            if all(idxSame) 
                % identical channel content; consider as sum of frames
                dfp=dFLIM_Props(dfp1.tPeakIRFs, dfp1.nFrames+dfp2.nFrames);
            else
                % must combine different channels (keep nFrames as dfp1)
                nmax = numel(dfp1.tPeakIRFs);
                tpiCombined = dfp1.tPeakIRFs;  % first copy one
                for k=1:nmax
                    val2 = dfp2.tPeakIRFs(k); % value from the second
                    if tpiCombined(k)==0
                        % ok to copy the second one
                        tpiCombined(k) = val2; 
                    else
                        if val2~=0 && tpiCombined(k)~=val2
                            error('dFLIM_Props: can''t combine same channel with different tPeakIRF');
                        end
                    end
                end
                dfp = dFLIM_Props(tpiCombined,dfp1.nFrames);
            end
        end
        
        function [channel,tPeakIRF] = firstChannel(dfp)
            channel=find(dfp.tPeakIRFs~=0,1,'first');
            tPeakIRF=dfp.tPeakIRFs(channel);
        end
        
        function val = tPeakIRF(dfp,nowarn)
            % returns a single value for tPeakIRF
            % this should really be used ONLY for single
            if sum(dfp.tPeakIRFs~=0)>1 && (nargin<2 || ~nowarn)
                dispr('Warning: dFLIM_Props:tPeakIRF requested for multi-channel object');
            end
            val = dfp.tPeakIRFs(find(dfp.tPeakIRFs~=0,1,'first'));
        end
            
    end % METHODS
end % CLASSDEF



