classdef ThorPipeClient < PipeClient
    % subclass of PipeClient to implement Thorimage-MATLAB IPC via
    % NamedPipes.  
    
    properties
        % inherited properties from PipeClient
        %   Name
        %   Stream
        %   Buffer
        %   Message
        %   MsgRecvCallback  = @PipeClient.DefaultMsgRecv % callback(msgAsUInt32,pclient)
        %   BufferSize = 8192
        %   ConnectTimer
        pserver  % PipeServerByte in opposite direction
    end
        
    events
        ThorNewFile
        ThorNewRoiData
    end
    
    methods (Access = private)
        function obj = ThorPipeClient()
            % creates the (singleton) PipeClient object
            obj@PipeClient('ThorimageMATLABPipe',8192);
            PipeClient.named(obj.Name,obj); % register the object
            obj.MsgRecvCallback = @ThorPipeClient.msgRecv;
            obj.pserver = ThorPipeServer.named('MATLABThorimagePipe');
            obj.pserver.Connect;
        end
    end
    
    methods (Static, Access=private)
        function obj = IPCobj(newval)
            persistent tpcObject
            if nargin
                tpcObject = newval; % sets the object
            end
            obj = tpcObject;        % return the object
        end
    end
            
    methods (Static)
        function obj = IPC(test)
            % get the persistent singleton object
            obj = ThorPipeClient.IPCobj;
            if nargin>0, return; end  % just asking for the existing
            % if it is empty, create a ThorPipeClient
            if isempty(obj)
                obj = ThorPipeClient.IPCobj(ThorPipeClient);
            end
        end
        
        function msg = encodeMessage(str,array)
            % puts together a string and an array into a coded message
            % MATLAB is column-major, C is row-major!
            msg = uint8(unicode2native(str));
            if nargin>1
                sz   = size(array);
                ndim = numel(sz);
                flat = [ndim; sz(:); array(:)];
                msg  = [msg(:); uint8(11); ...
                    typecast(single(flat),'uint8')];
            end
        end
        
        function [str,array] = decodeMessage(msg)
            % extracts string(s) and coded array from uint8 message
            % multiple strings are |-separated
            % MATLAB is column-major, C is row-major!
            
            % look for an array structure at the end
            % marked by a char(11) value
            idx   = find(char(msg)==11,1);  % 11 is the array marker; may need something fancier
            array = [];
            if ~isempty(idx)
                try
                    arr   = typecast(msg(idx+1:end),'single');
                    ndim  = arr(1);
                    sz    = arr(2:(1+ndim));
                    array = reshape(arr(2+ndim:end),sz(:)');
                    msg   = msg(1:idx-1);
                catch
                    disp('ThorIPC: error decoding passed array');
                end
            end
            str = strsplit(char(msg(:)'),'~');
        end
        
        function msgRecv(msg,pclient)
            % this receives the raw message from the server
            if ~strcmp(char(msg),'ACK')
                % disp(['<' pclient.Name '> received message: ' char(msg)]);
                % pclient.SendToServer('ACK');
            end
            [str,array] = ThorPipeClient.decodeMessage(char(msg));
            if pclient.Verbose, disp(strjoin([{'Client received: '} str],' ')); end
            % send an acknowledgement on the other pipe
            if strcmpi(str(4),'1')
                return  % was just their acknowledgement
            else
                % ACK pclient.pserver.SendToClient([strjoin(str(1:3),'~') '~1']);
            end
            % and dispatch the command
            switch str{3}
                case 'NotifySavedFile'
                    notify(pclient,'ThorNewFile',ThorIpcEventData(str(4:end),array));
                case 'RoiDataArray'
                    notify(pclient,'ThorNewRoiData',ThorIpcEventData(str(4:end),array));
            end
            pclient.CloseAndReopen
            pclient.Connect;
        end
        
    end
    
    methods
        function con = Connect(obj,timeout)
            if nargin<2, timeout=1000; end
            Connect@PipeClient(obj,timeout);
            con = obj.Stream.IsConnected;
            if con
                obj.pserver.Connect;
%                 obj.pserver.SendToClient('Remote~Local~Establish~YELLEN-LSM3');
            end
        end
        
        function Dispose(obj)
            if obj.pserver.Stream.IsConnected
                obj.pserver.SendToClient('Remote~Local~TearDown~0');
            end
            obj.pserver.Dispose;
            try stop(obj.ConnectTimer); end
            Dispose@PipeClient(obj);
            ThorPipeClient.IPCobj([]);
        end
        
    end
    
end