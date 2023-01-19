function [dfh,varargout] = loadRawThorimageDFLIM(filename,eInfo,channums,tPeakIRFs)
%loadRawThorimageDFLIM 201908 bin images from Thorimage
% loads dFLIM_Histo, optionally dFLIM_Image and dFLIM_PhotonList
%     [dfh] = loadRawThorimageDFLIM(fname,channums);
%  or [dfh,dfi] = loadRawThorimageDFLIM(fname,channums);
%  or [dfh,dfi,dfpl] = loadRawThorimageDFLIM(fname,channums);
%
% channums = [1 2] or [1] or [2] or [1 2 3 4], for example
% 
% channums specify the populated rows of the dFLIM objects
% if there are multiple frames (for streaming), they are in columns

imgsz   = eInfo.pixelsXY;
nAveraged = eInfo.averageNum;
if nargin<3, channums = eInfo.channels; end
if nargin<4, tPeakIRFs = repmat(0.8,1,max(channums)); end
nChans  = numel(channums);
nLines  = imgsz(2);
nPixels = imgsz(1);

% raw files 201909: histo and image data are in .dFLIM file
[pname,fname,~] = fileparts(filename);
f = fopen(fullfile(pname,[fname '.dFLIM']),'r');  
if f<=0
    dispr(['File not found: ' fname '.dFLIM']); 
    dfh = [];
    for k=2:nargout
        varargout{k} = [];
    end
    return
end

%% read the histograms (and infer the number of data items in the file)
nData        = 0;
nRepeat      = 0;
s_nsPerPoint = 0;
valid        = true;
while(valid)
    hst = double(fread(f,256,'uint32'));
    h_nsPerPoint = 5*hst(256)/hst(255)/128;
    % gy fix 20210221 for erroneous (false positive) count of histos
    if nData==0
        valid = h_nsPerPoint >= 0.045 && h_nsPerPoint <= 0.06 && sum(hst(242:252))==0;  % check limits with real data
        h_nsPerPoint0 = h_nsPerPoint;  % for reference... should be very tight to this later
        h_dat0 = hst(255:256);         % use this too to be sure
    else
        h_ratio = h_nsPerPoint / h_nsPerPoint0;
        h_dat_r = hst(255:256) ./ h_dat0;
        % 0.01 tolerance should be plenty (?) 
        valid = h_ratio >= 0.99 && h_ratio <= 1.01 && sum(hst(242:252))==0;
        valid = valid && all(h_dat_r >= 0.99) && all(h_dat_r <= 1.01);
    end
    if valid
        % nLines  = 2^round(log2(hst(256)/60000));     % get number of lines
        nData   = nData + 1;                         % total num histos
        nRepeat = ceil(nData/nChans);                % current repeat num
        idxchan = 1+mod(nData-1,nChans);
        chan    = channums(idxchan);                 % current channel
        s_nsPerPoint = s_nsPerPoint + h_nsPerPoint;  % accumulate the sum
        dfh(chan,nRepeat) = ...
            dFLIM_Histo(hst,[1 241],tPeakIRFs(chan),chan,nAveraged);
    else
        fseek(f,-1024,0);  % set the file pointer back to end of histos
    end
end
if nRepeat>0 && nData/nRepeat==numel(channums)
    nsPerPoint = s_nsPerPoint / nData;               % use the grand avg
    for k=1:numel(dfh)
        dfh(k).nsPerPoint = nsPerPoint;
    end
else
    error(sprintf('Incorrect data format for %1i channels: %3i valid histograms', ...
        nChans, nData));
    return
end

if nargout==1, return; end  % only dfh was requested, so we're done

%% read in the image data
%    we can use the nLines from the histogram clock values
%    and assume square images

% nPixels  = nLines;
img{nChans,nRepeat} = [];
nmg{nChans,nRepeat} = [];
tmg{nChans,nRepeat} = [];

% img
for k = 1:nRepeat
    for j = 1:nChans
        imgdata = fread(f,[nPixels nLines],'uint16')';
% 20200623 abandon use of legacy scaled img data
%         if all(imgdata(:)~=1) && any(imgdata(:)==128)
%             imgdata = imgdata / 128;  % legacy file with multiplied data for Thorimage display scaling
%         end
        img{j,k} = double(imgdata);
    end
end
% nmg
for k = 1:nRepeat
    for j = 1:nChans
        nmg{j,k} = double(fread(f,[nPixels nLines],'uint16')');
    end
end
% tmg
for k = 1:nRepeat
    for j = 1:nChans
        tmg{j,k} = double(fread(f,[nPixels nLines],'uint32')');
    end
end

fclose(f);

% create the dFLIM_Image objects
for k = 1:nRepeat
    for j = 1:nChans
        ch = channums(j);
        dfi(ch,k) = dFLIM_Image(img{j,k},nmg{j,k},tmg{j,k},tPeakIRFs(ch),ch,nAveraged);
        dfi(ch,k).nsPerPoint = nsPerPoint;
    end
end

varargout{1} = dfi;

%% read in the photonLists, if requested
if nargout>2  % also read photonList
        f = fopen(fullfile(pname,[fname '.photons']),'r');
        plist        = fread(f,'uint8');
        fclose(f);
        line_marks   = find(plist==254);
        nFrames      = numel(line_marks)/nLines;
%         frame_marks  = plist==253;
%         nFrames      = sum(frame_marks);  % number of EOF markers
%         frame_marks  = find(plist);       % positions of EOF markers
        nFramesPerCh = nFrames/nChans;
        firstPosOfFrame = 1;
        nextEOFIdx      = 1;
        EOFMark = 253;
        % photon list has interleaved frames
        %   for channels A,B, frames 1-3: 1A/1B/2A/2B/3A/3B
        % sort these first into channel-wise photon lists
        for k=1:nFramesPerCh
            for j=1:nChans
                if k==1, photons{j} = uint8([]); end
                % append the next frame to the end of the channel's list
                lastEOLOfFrame = line_marks(nLines*nextEOFIdx);
                photons{j} = [photons{j}; plist(firstPosOfFrame:lastEOLOfFrame); EOFMark];
                firstPosOfFrame = lastEOLOfFrame+1;
                nextEOFIdx      = nextEOFIdx + 1;
            end
        end
        % now put the photon lists into dFLIM_XYTPL objects
        dfpl = dFLIM_XYTPL.empty;
        for j=1:nChans
            ch = channums(j);
            dfpl(ch) = dFLIM_XYTPL(photons{j}, ...
                nPixels,nLines,nFramesPerCh,tPeakIRFs(ch),ch,nsPerPoint);
        end
        varargout{2} = dfpl'; % return a column vector
end




