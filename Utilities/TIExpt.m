classdef TIExpt < handle
    %TIExpt Thorimage Experiment reading object for raw dFLIM files
    %   tie = TIExpt('exptpath');
    %   tie.info returns experiment info
    
    % may eventually keep this as a top level class but move dFLIM-specific
    %   functionality to a subclass, TIExpt_dFLIM
    
    % depends on:
    %   monitorImageFiles
    %   getNextImageFile
    %
    %   dFLIM-specific dependencies:
    %     readThorimageExperimentFile [and parseXML_Thorimage]
    %     loadRawThorimageDFLIM
    %     [the dFLIM classes, Histo, Image, XYTPL, Props ...]
    
    
    properties
        exptPath
        info
        abort
    end
    
    methods(Static)
        function fname = makeFilename(str,idx,ext)
            % constructs a raw dFLIM filename, from the path-prefix (str),
            %  the four numerics (idx), and the extension (ext)
            fname = str;
            for k=1:numel(idx)
                fname = [fname num2str(idx(k),'_%03g')];
            end
            if nargin>2, fname = [fname ext]; end
        end
        
        function [str,idx,ext] = parseFilename(filename)
            % isolate the path+prefix (as str) from the numerics and the extension
            [fpath,fname,ext] = fileparts(filename);
            under = strfind(fname,'_');
            if ~any(numel(under)==[2 4])
                error(['"' filename '" is not a legal Thorimage filename']);
            end
            for k=1:numel(under)
                idx(k)=str2double(fname(under(k)+(1:3)));
            end
            str = fullfile(fpath,fname(1:under(1)-1));
        end
    end % methods(Static)
    
    methods
        function tie = TIExpt(fpath)
            % constructor TIExpt(filepath), which also reads and parses the
            %    experiment.xml file
           tie.exptPath = fpath;
           try
               tie.info = readThorimageExperimentFile(fullfile(tie.exptPath,'experiment.xml'));
           catch ME
               disp(ME.message);
               error(['TIExpt(' fpath '): could not read experiment.xml file']);               
           end
        end
        
        function dfh = getDFH(tie,idx)
            % reads a single acquisition dFLIM histo (includes all channels)
            %   idx is 4-number vector defining filename
            if nargin<2 
                if tie.info.streaming
                    idx = [1 1];
                else
                    idx = [1 1 1 1]; 
                end
            end
            dfh = loadRawThorimageDFLIM(TIExpt.makeFilename(fullfile(tie.exptPath,'Image'),idx),tie.info);
        end
        
        function dfhAll = getAllDFH(tie)
            % reads dFLIM_Histos from all acquisitions 
            %   returns an array: dfh(chan,acqNumber)
            if tie.info.streaming, dfhAll=tie.getDFH; return; end
            dfhAll = dFLIM_Histo.empty;
            if isfield(tie.info,'tiles') % && tie.info.tiles.isEnabled
                if isfield(tie.info,'tilesXY')
                    % one big tile array
                    nn = tie.info.tiles.subColumns * tie.info.tiles.subRows;
                else
                    % multiple single tiles
                    nn = numel(tie.info.tiles);
                end
                for k=1:nn
                    idx = [1 k 1 1];
                    dfh = loadRawThorimageDFLIM(TIExpt.makeFilename(fullfile(tie.exptPath,'Image'),idx),tie.info);
                    dfhAll = [dfhAll dfh];
                end
            end
        end
        
        function varargout = getData(tie,idx)
            % [dfh,dfi,dfpl] = tie.getData(idx)
            %   returns dfh (and if requested, dfi and dfpl)
            %      for the single acq with the specified index
            % rows are by channel
            [varargout{1:nargout}] = loadRawThorimageDFLIM(TIExpt.makeFilename(fullfile(tie.exptPath,'Image'),idx),tie.info);
        end
        
        function varargout = getAllData(tie)
            % [dfh,dfi,dfpl] = tie.getAll
            %   returns dfh (and if requested, dfi and dfpl) for all
            %      acquisitions in a tiled experiment (in index order)
            % rows are by channel, columns are the tiles in index order
            if tie.info.streaming
                [varargout{1:nargout}] = tie.getData([1 1]); return; 
            end
            
            dfhAll = dFLIM_Histo.empty;
            if nargout>1, dfiAll = dFLIM_Image.empty; end
            if nargout>2, dfplAll = dFLIM_XYTPL.empty; end
            if isfield(tie.info,'tiles') % && tie.info.tiles.isEnabled
                if isfield(tie.info,'tilesXY')
                    % one big tile array
                    nn = tie.info.tiles.subColumns * tie.info.tiles.subRows;
                else
                    % multiple single tiles
                    nn = numel(tie.info.tiles);
                end
            else
                nn = 1;
            end
            for j=1:tie.info.timing.timepoints
                for k=1:nn
                    idx = [1 k 1 j];
                    fname = TIExpt.makeFilename(fullfile(tie.exptPath,'Image'),idx);                   
                    switch nargout
                        case 1
                            dfh = loadRawThorimageDFLIM(fname,tie.info);
                        case 2
                            [dfh,dfi] = loadRawThorimageDFLIM(fname,tie.info);
                        case 3
                            [dfh,dfi,dfpl] = loadRawThorimageDFLIM(fname,tie.info);
                    end
                    dfhAll = [dfhAll dfh];
                    if nargout>1, dfiAll  = [dfiAll dfi];   end
                    if nargout>2, dfplAll = [dfplAll dfpl]; end
                end
            end
            varargout{1} = dfhAll;
            if nargout>1, varargout{2} = dfiAll;  end
            if nargout>2, varargout{3} = dfplAll; end
        end
        
        function deliverTileData(tie, hServiceFunc, varargin)
            % tie.deliverTileData(@serviceFunc [,passthruInfo])
            %  monitors appearance of image files in a tiled acq
            %  @serviceFunc is a file handle to be called as follows
            %     serviceFunc(tie,idx,passthruInfo)
            %  where index is the numeric extract of the filename
            
            if isfield(tie.info,'tilesXY')
                % one big tile array
                N = prod(tie.info.tilesXY);
            else
                % individual single tiles
                N = numel(tie.info.tiles);
            end
            tie.deliverData(N, hServiceFunc, varargin{:})
        end
        
        function deliverData(tie, nFiles, hServiceFunc, varargin)
            % tie.deliver(nFiles, @serviceFunc [, passthruInfo])
            %  monitors appearance of image files until nFiles are acquired
            %  @serviceFunc is a file handle to be called as follows
            %     serviceFunc(tie,idx,passthruInfo)
            %  where index is the numeric extract of the filename
               
            filespec = fullfile(tie.exptPath,'Image_*.dFLIM');
            
            % initiate file monitoring
            monitorImageFiles(0);
            monitorImageFiles(filespec);
            timeout1 = 20;  % longer timeout for getting the first file
            timeoutN = 6;  % timeout after the first file is acquired
            timeout  = timeout1;

            %% process the correct number of tile images
            for tNum=1:nFiles
                % get the filename
                imfname = getNextImageFile(timeout);
                if tie.abort
                    disp('collection aborted');
                    tie.abort = false;
                    monitorImageFiles(0);
                    return;
                end
                while isempty(imfname)
                    disp(['getNextImageFile timed out on tile ' mat2str(fliplr(tie.tileIJ(tNum))) '; retrying...']);
                    % mat2str(fliplr(tileIJFromSerial(tNum,tileXY))) '; retrying...']);
                    drawnow;
                    if tie.abort
                        disp('collection aborted');
                        tie.abort = false;
                        monitorImageFiles(0);
                        return;
                    end
                    imfname = getNextImageFile(timeout);
                end
                timeout = timeoutN; % for all files after the first
                
                % call the servicing function
                [~,idx] = TIExpt.parseFilename(imfname);
                hServiceFunc(tie,idx,varargin{:});
            end
            monitorImageFiles(0); % terminate monitoring
        end
        
        function abortDeliver(tie)
           tie.abort = true;
        end
        
        function ij = tileIJ(tie,idx)
            % returns tile col & row based on serpentine sampling, given
            %    specified serial number (as idx, or [1 serNum 1 1])
            % note that I is column number and J is row number
            if numel(idx)==1, sernum=idx; else sernum=idx(2); end
            if isfield(tie.info,'tilesXY')
                % one big set of tiles with serpentine collection
                j = floor((sernum-1)/tie.info.tilesXY(1));  % row number (0-based)
                i = sernum - j*tie.info.tilesXY(1);  % column number if not serpentine (0-based)
                ij = [i j+1]; % convert to ones based
            else
                % multiple single tiles
                ij = tie.info.tiles(sernum).tileIJ;
            end
        end
        
        function [ser,idx] = serialFromTileIJ(tie,ij)
            % returns file serial number from tile IJ
            if isfield(tie.info,'tilesXY')
                % one big set of tiles
                ser = (ij(2)-1)*tie.info.tilesXY(1)+ij(1);
            else
                % multiple single tiles (find the one with correct ij)
                ser = find(arrayfun(@(x) all(x.tileIJ==ij), tie.info.tiles));
            end
            % also return as a full file index set
            idx = [1 ser 1 1];
        end
        
    end % methods
    
end  % class TIExpt


