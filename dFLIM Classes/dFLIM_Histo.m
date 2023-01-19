classdef dFLIM_Histo < matlab.mixin.Copyable
    %dFLIM_Histo 1D Histogram object 
    %   contains validity and offset information
    % CONSTRUCTOR 
    %   dFLIM_Histo(data,tPeakIRF,validRange,channel[,nFrames[,nsPerPoint]])
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
        function hst = dFLIM_Histo(varargin)
            % valid constructor forms:
            % 0: dFLIM_Histo() returns empty/zero object
            % 1: dFLIM_Histo(n) returns a default object with data=ones(n,1);
            % 3: dFLIM_Histo(data,validRange,dFLIM_Props_obj) 
            %    uses properties from dFLIM_Props_object
            %    tPeakIRF is derived from the first dFLIM_Props value
            %    nsPerPoint is set to 0.05
            % 4: dFLIM_Histo(data,validRange,tPeakIRF,channel) OR 
            %    dFLIM_Histo(data,validRange,tPeakIRF,dFLIM_Props_obj)
            % 5: dFLIM_Histo(data,validRange,tPeakIRF,channel,nFrames)
            % 6: dFLIM_Histo(data,validRange,tPeakIRF,channel,nFrames, nsPerPoint)
            
            hst.nsPerPoint=0.05;
            switch nargin
                case 0
                    hst.dfProps=dFLIM_Props([],[],[]);
                    return
                case 1  % return a dummy but usable object
                    hst.Data=ones(varargin{1},1);
                    hst.validRange = [28 235];
                    hst.tPeakIRF   = 2.0;
                    hst.dfProps=dFLIM_Props(1,hst.tPeakIRF,1);
                case 3
                    hst.Data=double(varargin{1}(:));
                    hst.validRange=varargin{2};
                    hst.dfProps=varargin{3};
                    hst.tPeakIRF=hst.dfProps.tPeakIRF; 
                case {4,5,6}
                    hst.Data=double(varargin{1}(:));
                    hst.validRange=varargin{2};
                    hst.tPeakIRF=varargin{3};
                    if nargin==4 && isa(varargin{4},'dFLIM_Props')
                        hst.dfProps = varargin{4};
                    else
                        if nargin>4, nFrames=varargin{5}; else nFrames=1; end
                        hst.dfProps=dFLIM_Props(varargin{4},hst.tPeakIRF,nFrames);
                        if nargin>5, hst.nsPerPoint=varargin{6}; end
                    end
            end
        end
        
        %% UTILITY METHODS
        function chAvail = channelsAvailable(dfh)
            chAvail= find(arrayfun(@(x) ~isempty(x.Data), dfh(:,1,1))');
        end
        
        function dfh=setTPeakIRF(dfh, val)
            % ARRAY FORM OF CALL (doesn't re-use handles)
            for k=1:numel(dfh)
                dfh(k).tPeakIRF=val;
            end
        end
        
        %% PUBLIC METHODS
        function n = nBins(hst)
            n = numel(hst.Data);
        end
        
        function [y,t] = rangeData(hst)
            % returns hist values and timebase for the valid range
            rng = hst.validRange(1):hst.validRange(2);
            t = (rng-1) * hst.nsPerPoint; % makes the t data start at zero
            y = hst.Data(rng);
        end
        
        function etau = empiricalTau(hst,tPeak)
            [y,t] = hst.rangeData;
            etau = ((t(:)' - tPeak) * y(:)) / sum(y); % mean tau
        end
        
        function etau = empiricalTauWindowed(hst,tPeak,loHiTimes)
           % similar to empirical tau, but restricted to the window
           %  [tPeak+loHiTimes(1),tPeak+loHiTimes(2)]
           %  default values are -0.3 ns, +8.0 ns
           if nargin<3, loHiTimes=[-0.3, 8]; end
           [y,t] = hst.rangeData;
           tLoHi = tPeak+loHiTimes;
           
           % get the first and last FULLY-INCLUDED bins
           idx1 = find(t >= tLoHi(1),1,'first');
           idx2 = find(t <  tLoHi(2),1,'last');
           numerFullbins = (t(idx1:idx2)-tPeak) * y(idx1:idx2);
           denomFullbins = sum(y(idx1:idx2));
           % for the 'pre-firstFullBin' partial bin
           frLeft  = 1 - (tLoHi(1) - t(idx1-1))/hst.nsPerPoint;
           frRight = 1 - (t(idx2+1)- tLoHi(2))/hst.nsPerPoint;
           numerAll = frLeft*t(idx1-1)*y(idx1-1) + numerFullbins + ...
               frRight*t(idx2+1)*y(idx2+1);
           denomAll = frLeft*y(idx1-1) + denomFullbins + frRight*y(idx2+1);
           etau = numerAll/denomAll;          
        end
        
        function hstc = combine(hst1,hst2)
            % some checking first
            if isempty(hst2.Data), hstc=copy(hst1); return; end
            if isempty(hst1.Data), hstc=copy(hst2); return; end
            if numel(hst1.Data)~=numel(hst2.Data)|| ...
                    round(hst1.nsPerPoint,4)~=round(hst2.nsPerPoint,4)
                error('dFLIMHisto_combine: incompatible histos');
            end
            if hst1.tPeakIRF==hst2.tPeakIRF
                % trivial case of aligned histograms
                cdata=hst1.Data+hst2.Data;
                vRange=[max([hst1.validRange(1) hst2.validRange(1)]) ...
                    min([hst1.validRange(2) hst2.validRange(2)])];
            else % need to do an interpolating shift
                [cdata,dPts]=shiftHistogram(hst2.Data, ...
                    hst1.tPeakIRF-hst2.tPeakIRF,hst1.nsPerPoint);
                cdata=cdata+hst1.Data;
                vRange=[ceil(max([hst1.validRange(1) hst2.validRange(1)+dPts])) ...
                    floor(min([hst1.validRange(2) hst2.validRange(2)+dPts]))];
            end
            % specify the combined tPeakIRF as the first, and combine the
            % dFLIM_Props objects
            hstc=dFLIM_Histo(cdata,vRange,hst1.tPeakIRF,combine(hst1.dfProps,hst2.dfProps));
%             % following line needed in case channels are added out of numerical order
%             hstc.tPeakIRF=hst1.tPeakIRF;
            hstc.nsPerPoint=hst1.nsPerPoint;
        end
        
        function x = sum(hsta,varargin)
            % applied to an array of dFLIM_Histo objects
            % FORM1: sum(hsta) - sums over rows
            % FORM2: sum(hsta,idx) - sums over dimension idx
            if ~isempty(varargin)
                idx=varargin{1};
            else
                idx=1;
            end
            sz=size(hsta);
            nd=ndims(hsta);
            x=hsta;
            if nd<idx || sz(idx)==1  % summing over singleton dimension
                return
            else
                shuffle=1:nd;
                shuffle(idx)=[];
                shuffle=[idx shuffle];
                rhst=permute(hsta,shuffle);
                rhst=reshape(rhst,sz(idx),[]);
                % here sum over dim 1
                rhstsum=rhst(1,:);
                for j=2:size(rhst,1)
                    for k=1:size(rhst,2)
                        rhstsum(1,k)=combine(rhstsum(1,k),rhst(j,k));
                    end
                end
                szshufl=sz(shuffle);
                szshufl(1)=1;
                rhst=reshape(rhstsum,szshufl);
                x=ipermute(rhst,shuffle);
            end
        end

        function dfh = retrieve(dfh,dfs,frame)
            chan = dfh.dfProps.firstChannel;
            dfh.Data=dfs.retrieveHisto(chan,frame);
        end
        
                
        function dfh = retrieveAccum(dfh,dfsource) % retrieves full accumulator frame
            frAccum=double(dfsource.accumulatorFrame)+1;
            dfh.retrieve(dfsource,frAccum);
            dfh.dfProps.nFrames=dfsource.framesDone; 
        end

        
    end % METHODS
    
end % CLASSDEF


function [result,dPts] = shiftHistogram(hist1, deltaTPk, nsPerPoint)
% input parameters: hist1 is 1D histogram
% tPk1, tPk2 are the precisely calculated IRF peak times at 1010 nm
%    the laser shift may vary with laser frequency and power, but 
%    this should affect both channels equally
% the histos are shifted and interpolated so their nominal peak is at state.dFLIM.tPeakNorm
%    and then summed to give the output histogram

npts = numel(hist1);

% calculate the shift in number of points
dPts = deltaTPk/nsPerPoint;

% first do the whole point shift
%   use the floor, so the fractional interpolation is always rightward
dPtsWhole = floor(dPts);
dPtsFract = dPts-dPtsWhole;
if (dPtsWhole)>40
    warning('dFLIM_Histo::shiftHistogram: adjustment > 2 ns');
end

% shift and pad the histogram
if dPtsWhole>=0
    hShift = [zeros(1,dPtsWhole) hist1(1:(npts-dPtsWhole))'];
else
    hShift = [hist1((1-dPtsWhole):npts)' zeros(1,-dPtsWhole)];
end

% now use a convolution for the interpolation
% (result will be one point too long)
hOut = conv(double(hShift),[(1-dPtsFract) dPtsFract]);

result = hOut(1:npts)';
end