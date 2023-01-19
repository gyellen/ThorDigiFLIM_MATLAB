classdef PipeClient < handle
    %PipeClient   acts as a client for a WindowsNamedPipe
    %   Constructor is slightly unusual:
    %       pc = PipeClient.named('name');
    %
    %   Methods
    %       pc.Connect;            % connects to pipe (1s timeout)
    %       pc.CloseAndReopen;     % reqd before reconnecting after break
    %       pc.SendToServer(msg);  % msg can be uint8, char, or double
    %   
    %   Directly setting the callback function
    %       pc.MsgRecvCallback = @cbfunc;
    %
    %   The callback function takes two arguments,
    %     the message (as a uint8 array) and the responsible PipeClient
    %     object, which can be used to send an acknowledgement or response

    % NOTE THAT EDITING THIS CLASS WHILE A PIPE IS ACTIVE 
    % CAN PRODUCE ERRORS
    
    
    properties
        Name
        Stream
        Buffer
        Message
        MsgRecvCallback  = @PipeClient.DefaultMsgRecv % callback(msgAsUInt32,pclient)
        BufferSize = 8192
        ConnectTimer
        StreamEncoding
        Verbose = false
    end
    
    
    methods (Access = protected)
        function pclient = PipeClient(name,bufferSize)
            % initialize NET interface
            NET.addAssembly('System.Core');
            %asm = NET.addAssembly('System.IO.Pipes');
            import System.IO.Pipes.*
            import System.Text.*
            pclient.StreamEncoding = System.Text.UnicodeEncoding.GetEncoding('UTF-16');
            
            % on initialization
            pclient.Name = name;
            pclient.Stream = System.IO.Pipes.NamedPipeClientStream(...
                '.',name,System.IO.Pipes.PipeDirection.InOut,...
                System.IO.Pipes.PipeOptions.Asynchronous);
            if nargin>1, pclient.BufferSize = bufferSize; end
        end
    end    
    
    methods (Static)
        function pclient = named(name,create)
            % store the PipeClients in a list, accessible by name
            global pClientList
            pclient = []; % default return value
            if nargin>1
                if isa(create,'PipeClient')
                    pClientList.(name) = create;  % just store it in our list
                elseif create==-1
                    % specified argument of -1 (dispose) or 0 (return only existing)
                    
                    % dispose of an existing PipeClient
                    try
                        pc = pClientList.(name);
                        pclient = [];
                        pClientList = rmfield(pClientList,name);
                        strm = pc.Stream;
                        strm.Dispose;
                        pc.Stream = [];
                        pc.Name   = [];
                    catch err
                        if pc.Verbose, disp(err); end
                    end
                elseif create==0
                    % return an existing object only
                    if isfield(pClientList,name)
                        pclient = pClientList.(name);
                    end
                end
            elseif isempty(pClientList) || ~isfield(pClientList,name)
                pClientList.(name) = PipeClient(name);
                pclient = pClientList.(name);
            end
        end
    end
    
    methods
        function Connect(pclient,timeout)
            if isempty(pclient.Name)
                % deleted object
                pclient.ConnectTimer = [];
                return
            end
            if isempty(pclient.Stream)
                pclient.OpenStream;
            end
            %% Connect Named Pipe to a server
            if nargin<2, timeout = 1000; end
            try 
                pclient.Stream.Connect(timeout); 
            catch err
                if pclient.Verbose, disp('waiting to connect...'); end
                if isempty(pclient.ConnectTimer)
                    % create timer
                    pclient.ConnectTimer = timer('Period',0.1,...
                        'ExecutionMode','fixedSpacing',...
                        'TimerFcn',@(~,~)pclient.Connect);
                    start(pclient.ConnectTimer);
                end
                return
            end
            if ~isempty(pclient.ConnectTimer), stop(pclient.ConnectTimer); end
            pclient.ConnectTimer = [];
            pclient.Stream.ReadMode = System.IO.Pipes.PipeTransmissionMode.Byte;  % was .Message but adapting to Thorimage protocol
            % create the client state object
            pclient.Buffer = NET.createArray('System.Byte',pclient.BufferSize);
            if pclient.Stream.IsConnected
                if pclient.Verbose, disp(['pipe ' pclient.Name ' is connected to server']); end
                
                % use the Name to identify this object to the ReadCallback
                pclient.Stream.BeginRead(pclient.Buffer,0,pclient.Buffer.Length,...
                    @PipeClient.ReadCallback,pclient.Name);
            end
            
        end
        
        function MakeBuffer(pclient)
            pclient.Buffer = NET.createArray('System.Byte',pclient.BufferSize);            
        end
        
        function BeginRead(pclient)
            % use the Name to identify this object to the ReadCallback
            if isempty(pclient.Buffer)
                pclient.MakeBuffer;
            end
            pclient.Stream.BeginRead(pclient.Buffer,0,pclient.Buffer.Length,...
                @PipeClient.ReadCallback,pclient.Name);
        end
        
        function RestoreBufAndRead(pclient)
            % create the client state object
            pclient.Buffer = NET.createArray('System.Byte',pclient.BufferSize);
            if pclient.Stream.IsConnected
                if pclient.Verbose, disp(['pipe ' pclient.Name ' is connected to server']); end
                
                % use the Name to identify this object to the ReadCallback
                pclient.Stream.BeginRead(pclient.Buffer,0,pclient.Buffer.Length,...
                    @PipeClient.ReadCallback,pclient.Name);
            end
        end
        
        function Dispose(pclient)
            % caller should also delete any handles to the pclient
            PipeClient.named(pclient.Name,-1);
        end
        
        function CloseAndReopen(pclient)
            pclient.Stream.Close;
            pclient.OpenStream;
        end
        
        function OpenStream(pclient)
            if pclient.Verbose, disp(['OpenStream ' pclient.Name]); end
            pclient.Stream = System.IO.Pipes.NamedPipeClientStream(...
                    '.',pclient.Name,System.IO.Pipes.PipeDirection.InOut,...
                    System.IO.Pipes.PipeOptions.Asynchronous); 
        end
        
        function SendToServer(pclient,msg)
            switch class(msg)
                case 'uint8'
                    uMsg = msg;
                case 'char'
                    uMsg = uint8(msg);
                case 'double'
                    uMsg = typecast(msg,'uint8');
                otherwise
                    error(['PipeClient.SendToServer: Unknown message class ' class(msg)]);
            end
            pclient.Stream.BeginWrite(uMsg,0,numel(uMsg),...
                @PipeClient.SendCallback,['*' pclient.Name]);
        end
        
        function setVerbose(obj,val)
            obj.Verbose = val;
        end
        
    end
    
    methods (Static)
        function ReadCallback(ar)
            % use the passed name to retrieve the PipeClient object
            pcName = char(ar.AsyncState);
            pc = PipeClient.named(pcName,0);
            try 
                len = pc.Stream.EndRead(ar);
            catch
                return
            end
            if len<=0
                if pc.Verbose, disp('Server seems to have left the room'); end
                pc.CloseAndReopen;
                return % seems to do this when server quits
            end
            buf = pc.Buffer;
            len = 256*buf(1);
            % pause(0.1);
            len = double(len) + double(pc.Stream.ReadByte);
            if len>0
                msgbuf = NET.createArray('System.Byte',len);
                pc.Stream.Read(msgbuf,0,len);
                msg = pc.StreamEncoding.GetString(msgbuf);
                pc.Message = msg;
                complete = true;
            else
                complete = false;
            end
%             if pc.Stream.IsConnected
%                 pc.Stream.BeginRead(buf,0,buf.Length,...
%                     @PipeClient.ReadCallback,pcName);
%             end
            if complete
                % do this last to avoid problems
                try
                    pc.MsgRecvCallback(msg,pc);
                catch err
                    if pc.Verbose, disp(err); end
                end
            end
%             pc.CloseAndReopen;
%             pc.Connect;
        end
        
        function DefaultMsgRecv(msg,pclient)
            % this is a sample callback function (and the default, for testing)
            %if ~strcmp(char(msg),'ACK')
                disp(['<' pclient.Name '> received message: ' char(msg)]);
                % pclient.SendToServer('ACK');
            %end
        end
        
        function SendCallback(ar)
            % use the passed name to retrieve the PipeClient object
            pcName = char(ar.AsyncState);
            pc = PipeClient.named(pcName(2:end),0);
            pc.Stream.EndWrite(ar);
        end
        
        function ConnectCallback(ar)
            pcName = char(ar.AsyncState);
            pc = PipeClient.named(pcName(2:end),0);
            if isempty(pc), return; end
            if pc.Verbose
                disp(['CONNECTed pipe: ' pcName(2:end)]); 
                disp('start Client ConnectCallback');
            end
            % pause(0.2);
            pc.Stream.EndWaitForConnection(ar);
            if pc.Stream.IsConnected
                pc.MakeBuffer;
                if pc.Verbose, disp('... read enabled pipe'); end
                pc.BeginRead;
            end
            if pc.Verbose, disp('end Client ConnectCallback'); end
        end


    end
    
    
end


