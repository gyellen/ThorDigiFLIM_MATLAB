classdef dFLIM_Image < matlab.mixin.Copyable
    %dFLIM_Image - a single dFLIM frame or sum of frames
    %   contains .img, .nmg., .tmg arrays
    % CONSTRUCTOR (always from a single channel?)
    %   dFLIM_Image(img,nmg,tmg,tPeakIRF,channel[,nFrames]);
    % METHODS
    %   dfiSum = plus(dfi1,dfi2); % OR: dfiSum = dfi1+dfi2;
    %   addin(dfiAccum,dfi2);
    %   dfiNew = copy(dfiOld);  % needed because handle class!
    %
    
    properties
        img         % intensity image (total photon counts)
        nmg         % single photon counts
        tmg         % summed lifetime image (in units of nsPerPoint)
        tPeakIRF    % a single value that applies to the current data
                    %   (though history/provenance is in dfProps)
		tAdjust     % programmatically adjusted to give accurate tau(empirical)
        nsPerPoint
        dfProps     % a dFLIM_Props object describing channel content
    end
    
    properties (Constant)
        % a modified version of the jet colormap, with the faded ends eliminated
        Colormap = feval(@(x) x(32+(1:256),:), jet(256+64));
    end
    
    methods
        % CONSTRUCTOR
        function dfi = dFLIM_Image(varargin)
            % valid calls to the constructor
            % 0: dFLIM_Image() creates an empty object
            % 2: dFLIM_Image(imgStructure,dFLIM_Props_object) uses data from
            %        structure and properties from dFLIM_Props_object
            %    tPeakIRF is derived from the first dFLIM_Props value
            %    tAdjust is zero
            %    nsPerPoint is set to 0.05
            % 3: dFLIM_Image(nLines,nPixels,dFLIM_Props_object)  [zero arrays]
            % 4: dFLIM_Image(img,nmg,tmg,dFLIM_Props_object)
            % 5: dFLIM_Image(img,nmg,tmg,tPeakIRF,channel)
            % 6: dFLIM_Image(img,nmg,tmg,tPeakIRF,channel,nFrames)
            % 7: dFLIM_Image(img,nmg,tmg,tPeakIRF,channel,nFrames,nsPerPoint)
            
            dfi.tAdjust=0;
            dfi.nsPerPoint=0.05;
            switch nargin
                case 0
                    dfi.dfProps=dFLIM_Props([],[],[]);
                    return
                case 2
                    data=varargin{1};
                    if ~isempty(data)
                        dfi.img=data.img;
                        dfi.nmg=data.nmg;
                        dfi.tmg=data.tmg;
                    end
                    dfi.dfProps=varargin{2};
                    dfi.tPeakIRF=dfi.dfProps.tPeakIRF;
                case 3
                    nLines=varargin{1};
                    nPixels=varargin{2};
                    dfi.dfProps=varargin{3};
                    dfi.img=zeros(nLines,nPixels,'single'); % single precision?                    
                    dfi.nmg=zeros(nLines,nPixels,'single'); % single precision?                    
                    dfi.tmg=zeros(nLines,nPixels,'single'); % single precision?                    
                    dfi.tPeakIRF=dfi.dfProps.tPeakIRF;
                case 4
                    dfi.img=varargin{1};
                    dfi.nmg=varargin{2};
                    dfi.tmg=varargin{3};
                    dfi.dfProps=varargin{4};
                    dfi.tPeakIRF=dfi.dfProps.tPeakIRF;
                case {5,6,7}
                    dfi.img=varargin{1};
                    dfi.nmg=varargin{2};
                    dfi.tmg=varargin{3};
                    dfi.tPeakIRF=varargin{4};
                    if nargin>5, nFrames=varargin{6}; else nFrames=1; end
                    dfi.dfProps=dFLIM_Props(varargin{5},dfi.tPeakIRF,nFrames);
                    if nargin>6, dfi.nsPerPoint=varargin{7}; end                        
            end
            if any(size(dfi.img)~=size(dfi.nmg)) || any(size(dfi.img)~=size(dfi.tmg)) 
                error('dFLIM_Image constructor: images size mismatch')
            end 
        end
        
        
        % PUBLIC METHODS
        
        %% PROPERTY ACCESS METHODS **********
        function x = nPixels(dfi) % pixelsPerLine
            x = size(dfi.img,2);
        end
        
        function x = nLines(dfi)
            x = size(dfi.img,1);
        end
        
        function dfi=setTAdjust(dfi, val)
            % ARRAY FORM OF CALL (doesn't re-use handles)
                for k=1:numel(dfi)
                    dfi(k).tAdjust=val;
                end
        end
 
        function dfi=setTPeakIRF(dfi, val)
            % ARRAY FORM OF CALL (doesn't re-use handles)
                for k=1:numel(dfi)
                    dfi(k).tPeakIRF=val;
                end
        end
        
        function dfi=setTPeak(dfi, val)
            % sets tAdjust to give the specified net tPeak, without
            % changing tPeakIRF
            % ARRAY FORM OF CALL (doesn't re-use handles)
                for k=1:numel(dfi)
                    dfi(k).tAdjust = val - dfi(k).tPeakIRF;
                end
        end
        
        
        function img=averageImage(dfi)
            nFrames=dfi.dfProps.nFrames;
            if nFrames==1
                img=dfi.img;
            else
                img=dfi.img/nFrames;
            end
        end
        
        function setNFrames(dfi,nFrames)
            if numel(dfi)>1
                arrayfun(@(x) x.setNFrames(nFrames), ...
                    dfi, 'UniformOutput', false);
                return
            end
            dfi.dfProps.nFrames=nFrames;
        end
        
        function nF=nFrames(dfi)
            if numel(dfi)>1
                nF= arrayfun(@(x) x.nFrames, ...
                    dfi, 'UniformOutput', false);
                return
            end
            nF=dfi.dfProps.nFrames;
        end
        
        %% UTILITY METHODS
        function chAvail = channelsAvailable(dfi)
            chAvail= find(arrayfun(@(x) ~isempty(x.img), dfi(:,1,1))');
        end
       
        %% ROI VALUE EXTRACTION METHOD ******
        function [meanIntensity, meanTau, nPhotons, nSingles] = roiValues(dfi,mask)
            % returns [meanIntensity meanTau] for ROI
            
            % ARRAY FORM OF CALL (doesn't re-use handles)
            if numel(dfi)>1
                [meanIntensity, meanTau, nPhotons, nSingles] = arrayfun(@(x) x.roiValues(mask), ...
                    dfi); % gy Deleted 201504 , 'UniformOutput', false);
                return
            end
            
            if any(size(dfi.img)~=size(mask))
                meanIntensity=0; meanTau=0; nPhotons=0;
                disp('**** ROIs defined on an image of different dimensions ****');
                return
            end
            
            nPhotons = sum(sum(dfi.img .* mask,1),2);
            nSingles = sum(sum(dfi.nmg .* mask,1),2);
            sumLifet = sum(sum(dfi.tmg .* mask,1),2) * dfi.nsPerPoint;
            nPixels  = sum(sum(mask,1),2);
            
            % return [meanIntensity meanTau nPhotons]
            meanIntensity=nPhotons/nPixels/dfi.dfProps.nFrames;
            meanTau = sumLifet/nSingles - (dfi.tPeakIRF+dfi.tAdjust);
           
        end
         
       
        %% SUMMING/COMBINING METHODS ********
        function addIn(dfi1,dfi2,varargin)
            % accumulates dfi2 into dfi1
            % TODO?  add in possibility that one operand will be an empty
            if any(size(dfi1.img)~=size(dfi2.img)) || ...
                    round(dfi1.nsPerPoint,4)~=round(dfi2.nsPerPoint,4)
                error('dFLIM_Image::addin: image  mismatch');
            end
            if isempty(varargin)
                dfi1.img=dfi1.img+dfi2.img;
                dfi1.nmg=dfi1.nmg+dfi2.nmg;
                dfi1.tmg=dfi1.tmg+dfi2.tmg+ ...
                    ((dfi1.tPeakIRF-dfi2.tPeakIRF)/dfi1.nsPerPoint)*dfi2.nmg;
                dfi1.dfProps=combine(dfi1.dfProps,dfi2.dfProps);
            else  % optional argument: ,lines
                lines=varargin{1}; % specified as line1:line2
                dfi1.img(lines,:)=dfi1.img(lines,:)+dfi2.img(lines,:);
                dfi1.nmg(lines,:)=dfi1.nmg(lines,:)+dfi2.nmg(lines,:);
                dfi1.tmg(lines,:)=dfi1.tmg(lines,:)+dfi2.tmg(lines,:)+ ...
                    ((dfi1.tPeakIRF-dfi2.tPeakIRF)/dfi1.nsPerPoint)*dfi2.nmg(lines,:);
                if lines(1)==1 % update the frame count as soon as we add in a new stripe - but only once
                    dfi1.dfProps=combine(dfi1.dfProps,dfi2.dfProps);
                end
            end
        end
        
        function dfi3 = plus(dfi1,dfi2)
            % adds dfi1 and dfi2 (overloads the '+' operator)
            % TODO?  add in possibility that one operand will be an empty
            if any(size(dfi1.img)~=size(dfi2.img)) || dfi1.nsPerPoint~=dfi2.nsPerPoint
                error('dFLIM_Image::plus: image size mismatch');
            end
            img=dfi1.img + dfi2.img;
            nmg=dfi1.nmg + dfi2.nmg;
            tmg=dfi1.tmg + dfi2.tmg + ... % need correction for tPeakIRF diffs
                ((dfi1.tPeakIRF-dfi2.tPeakIRF)/dfi1.nsPerPoint)*dfi2.nmg;
            dfi3=dFLIM_Image(img,nmg,tmg,dfi1.tPeakIRF, ...
                combine(dfi1.dfProps,dfi2.dfProps));
            dfi3.tAdjust = dfi1.tAdjust;
        end

        function x = sum(dfi,varargin)
            % applied to an array of dFLIM_Image objects
            % FORM1: sum(dfi) - sums over rows
            % FORM2: sum(dfi,idx) - sums over dimension idx
            if ~isempty(varargin)
                idx=varargin{1};
            else
                idx=1;
            end
            sz=size(dfi);
            nd=ndims(dfi);
            x=dfi;
            if nd<idx || sz(idx)==1 % summing over a singleton dimension
                return
            else
                shuffle=1:nd;
                shuffle(idx)=[];
                shuffle=[idx shuffle];
                rdfi=permute(dfi,shuffle);
                rdfi=reshape(rdfi,sz(idx),[]);
                % here sum over dim 1
                rdfisum=copy(rdfi(1,:));
                for j=2:size(rdfi,1)
                    for k=1:size(rdfi,2)
                        rdfisum(1,k).addIn(rdfi(j,k));
                    end
                end
                szshufl=sz(shuffle);
                szshufl(1)=1;
                rdfi=reshape(rdfisum,szshufl);
                x=ipermute(rdfi,shuffle);
            end
        end
    
            
        %% FUNDAMENTAL DISPLAY METHODS ******
        function cdata = CData(dfi,LUTLo,LUTHi,varargin)
            % returns LUT-scaled intensity image
            % first optional parameter is non-zero for scaling average down by nFrames
            % second optional parameter is line numbers (as line1:line2)
            if ~isempty(varargin) && varargin{1}
                scale=single(dfi.dfProps.nFrames);
            else
                scale=0;
            end
            if length(varargin)>1 % lines are specified: CData(dfi,LUTLo,LUTHi,scale,1:32)
                lines=varargin{2};
                if scale
                    cdata = uint8((256/(LUTHi-LUTLo)) * (dfi.img(lines,:)/scale-LUTLo));
                else
                    cdata = uint8((256/(LUTHi-LUTLo)) * (dfi.img(lines,:)-LUTLo));
                end
            else % full frame
                if scale
                    cdata = uint8((256/(LUTHi-LUTLo)) * (dfi.img/scale-LUTLo));
                else
                    cdata = uint8((256/(LUTHi-LUTLo)) * (dfi.img-LUTLo));
                end
            end
        end
        
        function cdata = CDataS(dfi,LUTLo,LUTHi,varargin)
            % like CData, but with NMG
            % returns LUT-scaled intensity image
            % first optional parameter is non-zero for scaling average down by nFrames
            % second optional parameter is line numbers (as line1:line2)
            if ~isempty(varargin) && varargin{1}
                scale=single(dfi.dfProps.nFrames);
            else
                scale=0;
            end
            if length(varargin)>1 % lines are specified: CDataS(dfi,LUTLo,LUTHi,scale,1:32)
                lines=varargin{2};
                if scale
                    cdata = uint8((256/(LUTHi-LUTLo)) * (dfi.nmg(lines,:)/scale-LUTLo));
                else
                    cdata = uint8((256/(LUTHi-LUTLo)) * (dfi.nmg(lines,:)-LUTLo));
                end
            else % full frame
                if scale
                    cdata = uint8((256/(LUTHi-LUTLo)) * (dfi.nmg/scale-LUTLo));
                else
                    cdata = uint8((256/(LUTHi-LUTLo)) * (dfi.nmg-LUTLo));
                end
            end
        end

        
        function [rgb,cmap] = LifetimeRGBImage(dfi,LUTArray,varargin)
            % combines the alpha and colormap information
            % LUTArray row 1 is tau's, row 2 is LUT lo and hi for brightness
            % varargin{1}=scale; non-zero scales brightness tmg by number of frames
            
            % ARRAY FORM OF CALL (doesn't re-use handles)
            if numel(dfi)>1
                rgb = arrayfun(@(x) x.LifetimeRGBImage(LUTArray,varargin), ...
                    dfi, 'UniformOutput', false);
                return
            end
            
            % calculate brightness from LUT-scaled number of single photons
            if ~isempty(varargin) && varargin{1} % scale down by number of frames
                nFrameScaling = double(dfi.dfProps.nFrames);
            else
                nFrameScaling = 1.0;
            end
            
            % calculate RGB color from colormap
            cmap = dFLIM_Image.Colormap;
            if nargin<5    
                nmg = dfi.nmg;
                rgb = ind2rgb(dfi.LifetimeCData(LUTArray(1,1),LUTArray(1,2)),cmap);
            else
                % arguments 4-5 are the Gaussian smoothing parameters
                g1 = varargin{2};
                g2 = varargin{3};
                [cdat,nmg] = dfi.LifetimeCData(LUTArray(1,1),LUTArray(1,2),g1,g2);
                rgb = ind2rgb(cdat,cmap);       
            end
            
            % calculate the scaled brightness
            brtness = (double(nmg)/nFrameScaling - LUTArray(2,1)) / ...
                (LUTArray(2,2)-LUTArray(2,1));
            brtness(brtness<0)=0;
            brtness(brtness>1)=1;
            
            % apply the brightness to the pseudocolor image
            for k=1:3
                rgb(:,:,k) = rgb(:,:,k) .* brtness;
            end
            rgb = uint8(255*rgb);
        
        end
        

        function [cdata,nmg] = LifetimeCData(dfi,tauLo,tauHi,varargin)
            % returns LUT-scaled CData
            
            % ARRAY FORM OF CALL (doesn't re-use handles)
            if numel(dfi)>1
                hArray2 = arrayfun(@(x) x.LifetimeCData(tauLo,tauHi,varargin), ...
                    dfi, 'UniformOutput', false);
                return
            end
            if nargin<5
                cdata = uint8( ((255/(tauHi-tauLo))*dfi.nsPerPoint) * ...
                    (dfi.tmg./dfi.nmg-(dfi.tPeakIRF+dfi.tAdjust+tauLo)/dfi.nsPerPoint) );
                nmg = dfi.nmg;
            else
                % gaussian smoothing (e.g. 1,3  or 1.3,5  or 2,9)
                g1 = varargin{1};
                g2 = varargin{2};
                nmg = imgaussfilt(dfi.nmg,g1,'FilterSize',g2);
                tmg = imgaussfilt(dfi.tmg,g1,'FilterSize',g2);
                cdata = uint8( ((255/(tauHi-tauLo))*dfi.nsPerPoint) * ...
                    (tmg./nmg-(dfi.tPeakIRF+dfi.tAdjust+tauLo)/dfi.nsPerPoint) );
            end
        end

        function [rgb,cmap] = RatioRGBImageOver(dfi,dfiDenom,LUTArray,varargin)
            % combines the alpha and colormap information
            % LUTArray row 1 is ratio values, row 2 is LUT lo and hi for brightness
            
            % optional parameter is pixel shift of the denominator image
            if ~isempty(varargin) && ~isempty(varargin{1})
                % need to shift the denominator
                denomImg = applyPixelShift(double(dfiDenom.img),varargin{1});
            else
                denomImg = double(dfiDenom.img);
            end
            
            % calculate brightness from LUT-scaled number of photons in the
            % denominator image
            % always scale down by number of frames
            brtness = (denomImg - dfi.dfProps.nFrames*LUTArray(2,1)) / ... 
                    (dfi.dfProps.nFrames*(LUTArray(2,2)-LUTArray(2,1)));
            brtness(brtness<0)=0;
            brtness(brtness>1)=1;
            
            % calculate RGB color from colormap
            cmap = dFLIM_Image.Colormap;
            ratioCData = uint8( 255*((double(dfi.img) ./ denomImg)-LUTArray(1,1)) / ...
                (LUTArray(1,2)-LUTArray(1,1)) );
            rgb = ind2rgb(ratioCData,cmap);
            for k=1:3
                rgb(:,:,k) = rgb(:,:,k) .* brtness;
            end
            rgb = uint8(255*rgb);
        end

        
        %% ACQUISITION RETRIEVAL FUNCTION
        function this = retrieve(dfi,dfsource,varargin)
            %   this.retrieve(mmf,frame) or
            %   this.retrieve(mmf,frame,lines)
            this = dfi;
            chan = dfi.dfProps.firstChannel;
            switch length(varargin)
                case 1  % full frame: this.retrieve(mmf,frame)
                    imgstruct = dfsource.retrieveImage(chan,varargin{1}); % full frame
                    dfi.img=single(imgstruct.img);
                    dfi.nmg=single(imgstruct.nmg);
                    dfi.tmg=single(imgstruct.tmg);
                case 2 % partial frame: this.retrieve(mmf,frame,lines)
                    if isempty(dfi.img)
                        % get the ultimate full frame size from the source
                        szImage=[dfsource.nLines dfsource.nPixels];
                        dfi.img=zeros(szImage,'single');
                        dfi.nmg=zeros(szImage,'single');
                        dfi.tmg=zeros(szImage,'single');
                    end
                    lines = varargin{2};
                    imgstruct = dfsource.retrieveImage(chan,varargin{1:2}); % full frame
                    lines = [lines(1):lines(2)]; % needed for assignment
                    dfi.img(lines,:)=imgstruct.img;
                    dfi.nmg(lines,:)=imgstruct.nmg;
                    dfi.tmg(lines,:)=imgstruct.tmg;
                case 3  % partial frame into newly allocated array
                    szImage=fliplr(varargin{1});
                    dfi.img=zeros(szImage,'single');
                    dfi.nmg=zeros(szImage,'single');
                    dfi.tmg=zeros(szImage,'single');
                    lines = varargin{3};
                    imgstruct = dfsource.retrieveImage(chan,varargin{2:3}); % partial frame
                    lines = [lines(1):lines(2)]; % needed for assignment
                    dfi.img(lines,:)=imgstruct.img;
                    dfi.nmg(lines,:)=imgstruct.nmg;
                    dfi.tmg(lines,:)=imgstruct.tmg;
            end
        end
        
        function dfi = retrieveAccum(dfi,dfsource) % retrieves full accumulator frame
            frAccum=double(dfsource.accumulatorFrame)+1;
            dfi.retrieve(dfsource,frAccum);
            dfi.dfProps.nFrames=dfsource.framesDone; 
        end
     end % methods
    
    methods(Static)
        function amap = AlphaMap(LUTLo,LUTHi)
            % LUTLo is the first non-zero intensity (unless it's zero)
            % LUTHi is the first full intensity point
            lolim=ceil(max(LUTLo-1,0));
            hilim=floor(min(LUTHi,255));
            amap = [zeros(1,lolim) linspace(0,1,1+hilim-lolim) ones(1,255-hilim)];
        end
    end % methods(Static)
 
end % classdef
