classdef TI_Viewer_Class < handle
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        handles
        tiExpt
        dfi
        dfh
        dfxyt
        fitter
    end
    
    methods
        function obj = TI_Viewer_Class(hh)
            %TI_Viewer_Class  Construct an instance of this class
            %   Initialized with the gui handles
            obj.handles = hh;
        end
        
        function readImages(obj,getXYT)
            set(obj.handles.figure1, 'pointer', 'watch')
            drawnow;
            if nargin>1 && getXYT
                [obj.dfh,obj.dfi,obj.dfxyt] = obj.tiExpt.getAllData;
            else
                [obj.dfh,obj.dfi] = obj.tiExpt.getAllData;
                obj.dfxyt = [];
            end
            set(obj.handles.figure1, 'pointer', 'arrow')

        end
        
        function showImage(obj,imgNum,ch,hAxes)
            % CHOOSE THE CORRECT SUBFRAME(S)
            if any([ch,imgNum]>size(obj.dfh)) || isempty(obj.dfh(ch,imgNum).Data)
                obj.handles.tMessages.String = 'Data item is blank - might be non-existent channel';
                return;
            end
            dfiNow = obj.dfi(ch,imgNum);
            dfhNow = obj.dfh(ch,imgNum);
            
            % DISPLAY THE HISTOGRAM
            [y,t] = dfhNow.rangeData;
            obj.fitter = DecayFitter_exp2_gauss;
            [vals,fail,tau,redchisq] = obj.fitter.fitProgressive(t,y,0.07);
            p = obj.fitter.params';
            msg{1} = ['Fit with mean tau = ' num2str(tau,3) '  redChiSq = ' num2str(redchisq,3)];
            msg{2} = mat2str(p,3);
            if ~obj.handles.cbFixTPeak.Value
                % don't update if fixed already; otherwise fill in the box
                % the box
                obj.handles.eTPeak.String = num2str(p(5),3);
            end
            tPeak = str2double(obj.handles.eTPeak.String);
            dfiNow.setTPeak(tPeak);
            obj.handles.tMessages.String = msg;
            axh = hAxes(3); % obj.handles.axes4;
            cla(axh);
            plot(axh,t,y,'.',t,vals,'-');
            axh.YScale = 'log';
            
            % FIX THE HISTOGRAM AXES
            % minimum of 1.5 log extent
            axh.YLimMode = 'auto';
            ax = axis(axh);
            if log10(ax(4)/ax(3))<1 
                ax(3)=max(0,log10(ax(4))-1.5); 
            end
            % x-axis covers exact time range of histogram
            ax(2)=max(t); 
            axis(axh,ax);
            
            % DISPLAY THE IMAGE
            axI = hAxes(1); % obj.handles.axes1;
            cdat = dfiNow.CData(0,str2double(obj.handles.eLUT.String),1);
            image(axI, cdat, 'CDataMapping','direct');
            set(axI,'XTick',[],'YTick',[]);
            
            % DISPLAY THE LIFETIME IMAGE
            axLT = hAxes(2); % obj.handles.axes2;
            LUTArray = [ str2double(obj.handles.eLT_lo.String) str2double(obj.handles.eLT_hi.String) ; ...
                0 str2double(obj.handles.eLUT_LT.String)];
            binning = obj.handles.pmBinning.Value;
            % perform smoothing if requested
            if binning==1
                dfiTemp = dfiNow;
            elseif any(binning==2:4)
                binning = 2^(binning-1);  % 2 4 8
                dfiTemp = copy(dfiNow);
                dfiTemp.nmg = image_bin(dfiTemp.nmg,binning,1);
                dfiTemp.tmg = image_bin(dfiTemp.tmg,binning,1);
            elseif binning==5 % use a smoothing kernel (3)
                kernel = [1/1.4 1 1/1.4; 1 2 1; 1/1.4 1 1/1.4];
                kernel = kernel/sum(kernel(:));
                dfiTemp = copy(dfiNow);
                dfiTemp.nmg = conv2(dfiTemp.nmg,kernel,'same');
                dfiTemp.tmg = conv2(dfiTemp.tmg,kernel,'same');
            elseif any(binning==6:8) % use a gaussian kernel
                gchoices = [1 3; 1.3 5; 2 9];
                g = gchoices(binning-5,:);
                dfiTemp = copy(dfiNow);
                dfiTemp.nmg = imgaussfilt(dfiTemp.nmg,g(1),'FilterSize',g(2));
                dfiTemp.tmg = imgaussfilt(dfiTemp.tmg,g(1),'FilterSize',g(2));
            end
            % show the LT image
            cdat = dfiTemp.LifetimeRGBImage(LUTArray,1);
            image(axLT, cdat);
            set(axLT,'XTick',[],'YTick',[]);
            
            if obj.handles.cbSkipLTHistoUpdate.Value==0
                showLTDistribution(dfiTemp,10,LUTArray(1,:),obj.handles.axes5);
            end
        end
        
        % GUI-handling functions (to prevent duplication)
        
        function chooseTopDirectory(obj,eventdata)
            if ~isempty(obj.handles.tTopFolder.String)
                if isempty(eventdata) % call to refresh contents
                    folder_name = obj.handles.tTopFolder.String;
                else
                    folder_name = uigetdir(obj.handles.tTopFolder.String);
                end
            else
                folder_name = uigetdir('D:\');
            end
            obj.handles.tTopFolder.String = folder_name;
            % get what is inside the folder
            Infolder = dir(folder_name);
            % Initialize the cell of string that will be update in the list box
            MyListOfFiles = [];
            % Loop on every element in the folder and update the list
            for i = 1:length(Infolder)
                if Infolder(i).isdir && ~(Infolder(i).name(1)=='.')
                    MyListOfFiles{end+1,1} = Infolder(i).name;
                end
            end
            % update the listbox with the result
            set(obj.handles.lbFolders,'String',MyListOfFiles)
            obj.handles.lbFolders.Value = 1;
        end
        
        function newFolderSelection(obj)
            contents = cellstr(get(obj.handles.lbFolders,'String')); % returns lbFolders contents as cell array
            expt_folder_name = fullfile(obj.handles.tTopFolder.String,contents{get(obj.handles.lbFolders,'Value')}); % returns selected item from lbFolders
            % get what is inside the folder
            Infolder = dir(fullfile(expt_folder_name,'*.dFLIM'));
            % Initialize the cell of string that will be update in the list box
            MyListOfFiles = [];
            % Loop on every element in the folder and update the list
            for i = 1:length(Infolder)
                if ~Infolder(i).isdir
                    MyListOfFiles{end+1,1} = Infolder(i).name;
                end
            end
            % update the listbox with the result
            set(obj.handles.lbFiles,'String',MyListOfFiles)
            if(obj.handles.lbFiles.Value>numel(MyListOfFiles))
                obj.handles.lbFiles.Value = 1;
            end
            % read the experiment and display basic info
            tie = TIExpt(expt_folder_name);
            obj.tiExpt = tie;
            info = tie.info.fullinfo;
            etxt{1} = [info.Name.name '      ' info.Date.date];
            etxt{2} = ['Channels ' mat2str(tie.info.channels) ...
                '    Pixels ' mat2str(tie.info.pixelsXY)];
            obj.enableRadioButtons(tie.info.channels);
            nAvg = tie.info.averageNum;
            if nAvg>1, etxt{end+1} = ['Average of ' num2str(nAvg) ' frames']; end
            if isfield(tie.info,'tilesXY')
                etxt{end+1} = ['Tiled image: ' mat2str(fliplr(tie.info.tilesXY))];
            end
            nTimepts = info.Timelapse.timepoints;
            if nTimepts>1
                etxt{end+1} = ['Timeseries: ' num2str(nTimepts) ' timepoints, interval = ' ...
                    num2str(info.Timelapse.intervalSec) ' s'];
            end
            if info.Streaming.enable
                etxt{end+1} = ['Streaming: ' num2str(info.Streaming.frames) ' frames'];
            end
            etxt{end+1} = '';
            etxt{end+1} = 'Comments:';
            etxt{end+1} = info.Comments.text;
            obj.handles.tExptInfo.String = etxt;
            obj.handles.eImageNumber.String = num2str(obj.handles.lbFiles.Value);
        end
        
        function enableRadioButtons(obj,chans)
            % enables the channel radio buttons for the avail channels
            hh = obj.handles;
            rbs = {'rbA' 'rbB' 'rbC' 'rbD'};
            for ch = 1:4
                if any(chans==ch)
                    hh.(rbs{ch}).Enable = 'on';
                else
                    hh.(rbs{ch}).Enable = 'off';
                end
            end
        end
        
    end
end

function showLTDistribution(dfiNow,minCount,LTlims,hAxes)
% calculate the distribution
binwidth = 0.02;
binedges = 0.4:binwidth:4;
nbins    = numel(binedges)-1;
tPeak = dfiNow.tPeakIRF + dfiNow.tAdjust;
meanLT   = dfiNow.nsPerPoint*(dfiNow.tmg(:) ./ dfiNow.nmg(:)) - tPeak;
meanLT(dfiNow.nmg(:)<minCount) = -1; % eliminate pixels less than minCount
hst = zeros(nbins,1);
% each bin contains the number of photons in pixels with that meanLT
for k=1:nbins
    msk  = (meanLT >= binedges(k)) & (meanLT < binedges(k+1));
    hst(k) = sum(msk .* dfiNow.nmg(:));
end
if max(hst(:))<=0, cla(hAxes); return; end
% calculate the axis limits
axlims = [min(binedges)+binwidth max(binedges)-binwidth 0 1.1*max(hst)];

% create the background spectrum
% vertices = [axlims(1) 0; axlims([1 4]); LTlims(1) axlims(4); LTlims(1) 0; ...
%     LTlims(2) 0; LTlims(2) axlims(4); axlims([2 4]); axlims(2) 0 ];
% faces = [1 2 3 4; 5 6 7 8];
% colors = [0 0 0 0 0.9 0.9 0.9 0.9; ...
%           0 0 0 0 0 0 0 0; ...
%           0.9125 0.9125 0.9125 0.9125  0 0 0 0;]';
% p = patch(hAxes,'Faces',faces,'Vertices',vertices,'FaceVertexCData',colors,'FaceColor','interp');


cmap = dFLIM_Image.Colormap;
img = repmat(cmap,256,1);
img = reshape(img,256,256,3);
img = permute(img,[2 1 3]);
cla(hAxes);
set(hAxes,'XTickMode','auto');
hold on; 
imB = [0 0 1]; imB = repmat(imB,65536,1,1); imB=reshape(imB,256,256,3);
image(hAxes,'CData',imB,'XData',[axlims(1) LTlims(1)],'YData',axlims(3:4));
imR = [1 0 0]; imR = repmat(imR,65536,1,1); imR=reshape(imR,256,256,3);
image(hAxes,'CData',imR,'XData',[LTlims(2) axlims(2)],'YData',axlims(3:4));
image(hAxes,'CData',img,'XData',LTlims,'YData',axlims(3:4));
% now plot the histo

hst(:,2)=axlims(4)-hst(:,1);
h = area(hAxes,binedges(1:end-1)+binwidth,hst);
axis(hAxes,axlims);
hL1 = line(hAxes,LTlims(1)*[1 1],axlims(3:4)); 
hL2 = line(hAxes,LTlims(2)*[1 1],axlims(3:4));
hL1.Color = [0.5 0.5 1];
hL2.Color = [1 0.5 0.5];
set([hL1 hL2],'LineWidth',2);
h(1).FaceAlpha = 0;
h(2).FaceColor = 0.3*[1 1 1];
set(hAxes,'YTick',[],'YDir','normal');
end