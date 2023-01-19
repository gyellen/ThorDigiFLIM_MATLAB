function expt = readThorimageExperimentFile(xmlFilename)
s = parseXML_Thorimage(xmlFilename);
s = s.ThorImageExperiment; % lose the top level
expt.fieldsize  = [s.LSM.widthUM s.LSM.heightUM];
if s.LSM.averageMode>0
    expt.averageNum = s.LSM.averageNum;
else
    expt.averageNum = 1;
end
expt.channels   = find(bitand([1 2 4 8],s.LSM.channel));
expt.homeOffset = [s.Sample.homeOffsetX s.Sample.homeOffsetY];
if isfield(s.Sample,'Wells')
    tiles = s.Sample.Wells.SubImages;
    % 20210203 fix for Dorothy having multiple tile definitions, but only
    %    one active one
    ix = find(arrayfun(@(x) strcmpi(x.isEnabled,'true'),tiles));
    expt.tilesIndex = ix;
    if ~isempty(ix)
        if numel(ix)==1
            expt.tiles     = tiles(ix);
            expt.tilesXY   = [expt.tiles.subColumns expt.tiles.subRows];
            % expt.tile0xy   = 1000*[s.Sample.initialStageLocationX s.Sample.initialStageLocationY];
            expt.tileOvr   = [expt.tiles.overlapX expt.tiles.overlapY];
            % not sure about the rounding here... gives almost the right
            % starting pos...
            expt.tileDxy   = round([1 -1].*(1-0.01*expt.tileOvr).*expt.fieldsize,1);
            expt.tile0xy   = 1000 * ( ...  % was tile0xyNew
                    [expt.tiles.transOffsetXMM expt.tiles.transOffsetYMM] + ...
                    expt.homeOffset) + ...
                    0.5 * ([1 1] - expt.tilesXY) .* expt.tileDxy;
        else
            % we have a list of single tiles to read (only good for sets>1)
            for k=1:numel(ix)
                expt.tiles(k) = tiles(ix(k));
            end
            for k=1:numel(ix)
                tileInfo = expt.tiles(k);
                if tileInfo.subColumns~=1 || tileInfo.subRows~=1
                    % multiple tile sets are enabled but they are not
                    % single tiles
                    error('Multiple tile sets are enabled but they are not all single tiles');
                end
                expt.tiles(k).tileXY = 1000 * ( ...
                    [tileInfo.transOffsetXMM tileInfo.transOffsetYMM] + ...
                    expt.homeOffset);
                name = tileInfo.name;
                ix1  = strfind(name,'r');
                ix2  = strfind(name,'c');
                if ix1<ix2
                    row = str2double(name(ix1+1:ix2-1));
                    col = str2double(name(ix2+1:end));
                else
                    col = str2double(name(ix2+1:ix1-1));
                    row = str2double(name(ix1+1:end));
                end
                expt.tiles(k).tileIJ = [col row];
            end
        end
    end
end
expt.wavelen   = s.MultiPhotonLaser.pos;
expt.pixelsXY  = [s.LSM.pixelX s.LSM.pixelY];
expt.power     = s.Pockels(1).start;
expt.dateinfo  = s.Date;
expt.timing    = s.Timelapse;
expt.comments  = s.Comments;
if s.Streaming.enable 
    expt.streaming = s.Streaming.frames;
else
    expt.streaming = 0;
end
expt.fullinfo  = s;
