 classdef ThorPipeServer < handle
     %ThorPipeServer   acts as a server for a WindowsNamedPipe
    %   Constructor is slightly unusual:
    %       ps = ThorPipeServer.named('name');
    %
    %   Methods
    %       ps.Connect;            % connects to pipe (1s timeout)
    %       ps.CloseAndReopen;     % reqd before reconnecting after break
    %       ps.SendToClient(msg);  % msg can be uint8, char, or double
    %   
    %   Directly setting the callback function
    %       ps.MsgRecvCallback = @cbfunc;
    %
    %   The callback function takes two arguments,
    %     the message (as a uint8 array) and the responsible PipeServer
    %     object, which can be used to send an acknowledgement or response
    
    %   Note that the server stream is generally dormant, but called into
    %   temporary existence by a SendToClient command

    % NOTE THAT EDITING THIS CLASS WHILE A PIPE IS ACTIVE 
    % CAN PRODUCE ERRORS
    
    
    properties
        Name
        Stream
        Buffer
        Message
        MessageOut
        MsgRecvCallback  = @ThorPipeServer.DefaultMsgRecv % callback(msgAsUInt32,pserver)
        TransmissionMode
        StreamEncoding
        BufferSize = 8192
        Verbose = false
    end
    
    
    methods (Access = protected)
        function pserver = ThorPipeServer(name,bufferSize)
            % initialize NET interface
            NET.addAssembly('System.Core');
            import System.IO.Pipes.*
            import System.Text.*
            pserver.TransmissionMode = System.IO.Pipes.PipeTransmissionMode.Byte;
            pserver.StreamEncoding = System.Text.UnicodeEncoding.GetEncoding('UTF-16');
            % on initialization
            pserver.Name = name;
            pserver.Stream = System.IO.Pipes.NamedPipeServerStream(...
                name,System.IO.Pipes.PipeDirection.InOut,...
                System.IO.Pipes.NamedPipeServerStream.MaxAllowedServerInstances,...
                pserver.TransmissionMode,...
                System.IO.Pipes.PipeOptions.Asynchronous);
            if nargin>1, pserver.BufferSize = bufferSize; end
        end
    end    
    
    methods (Static)
        function pserver = named(name,create)
            % store the PipeServers in a list, accessible by name
            global pServerList
            pserver = []; % default return value
            if nargin>1
                % specified argument of -1 (dispose) or 0 (return only existing)
                if create==-1
                    % dispose of an existing PipeServer
                    try
                        ps = pServerList.(name);
                        pServerList = rmfield(pServerList,name);
                        ps.Stream.Dispose;
                        ps.Stream = [];
                        ps.Name = [];
                    catch
                        error(['Error when Disposing of PipeServer[' name ']']);
                    end
                elseif create==0
                    % return an existing object only
                    if isfield(pServerList,name)
                        pserver = pServerList.(name);
                    end
                end
            else
                if isempty(pServerList) || ~isfield(pServerList,name)
                    % create a new PipeServer by that name
                    pServerList.(name) = ThorPipeServer(name,1);  % TRY BUFFER SIZE OF 1
                end
                pserver = pServerList.(name);
            end
        end
    end
    
    methods
        function MakeBuffer(pserver)
            pserver.Buffer = NET.createArray('System.Byte',pserver.BufferSize);            
        end
        
        function BeginRead(pserver)
            % use the Name to identify this object to the ReadCallback
            if isempty(pserver.Buffer)
                pserver.MakeBuffer;
            end
            pserver.Stream.BeginRead(pserver.Buffer,0,pserver.Buffer.Length,...
                @ThorPipeServer.ReadCallback,pserver.Name);
        end
        
        function Connect(pserver)
            %% monitor connection with client
            pserver.MakeBuffer;
            if pserver.Stream.IsConnected
                pserver.BeginRead; % (main function of the server is sending, not receiving) 
            else
                try
                    pserver.Stream.BeginWaitForConnection(@ThorPipeServer.ConnectCallback,['C' pserver.Name]);
                catch err
                    if strfind(err.message,'broken')
                        if pserver.Verbose 
                            disp("Server connect err... retrying Connect");
                            disp(err);
                        end
                        pserver.CloseAndReopen;
                        pserver.Stream.BeginWaitForConnection(@ThorPipeServer.ConnectCallback,['D' pserver.Name]);
                    else
                        if pserver.Verbose, disp(err); end
                    end 
                end
                return
            end            
        end
        
        function Dispose(pserver)
            % caller should also delete any handles to the pserver
            ThorPipeServer.named(pserver.Name,-1);
        end
        
        function CloseAndReopen(pserver)
            pserver.Stream.Close;
            pserver.Stream = System.IO.Pipes.NamedPipeServerStream(...
                pserver.Name,System.IO.Pipes.PipeDirection.InOut,...
                System.IO.Pipes.NamedPipeServerStream.MaxAllowedServerInstances,...
                pserver.TransmissionMode,...
                System.IO.Pipes.PipeOptions.Asynchronous);
        end
        
        function SendToClient(pserver,msg)
            switch class(msg)
                case 'uint8'
                    uMsg = msg;
                case 'char'
                    uMsg = uint8(pserver.StreamEncoding.GetBytes(msg));
                case 'double'
                    uMsg = typecast(msg,'uint8');
                otherwise
                    error(['ThorPipeServer.SendToClient: Unknown message class ' class(msg)]);
            end
            len = numel(uMsg);
            uMsg = [uint8(floor(len/256)) uint8(bitand(len,255)) uMsg]; 
            pserver.MessageOut = {msg; uMsg};
            if ~pserver.Stream.IsConnected
                pserver.Connect;
                % disp('Waiting for connection... try again when connected');
                return
            end
            %pserver.Stream.Flush;
            pserver.Stream.BeginWrite(uMsg,0,numel(uMsg),...
                @ThorPipeServer.SendCallback,['*' pserver.Name]);
        end
    end
    
    methods (Static)
        function ReadCallback(ar)
            % use the passed name to retrieve the PipeServer object
            psName = char(ar.AsyncState);
            ps = ThorPipeServer.named(psName,0);
            if isempty(ps), return; end
            lenB = ps.Stream.EndRead(ar);
            if lenB>0
                buf = ps.Buffer;
                if isempty(buf)
                    disp('... pipe buffer empty; repairing');
                    ps.MakeBuffer;
                else
                    len = 256*buf(1);
                    len = double(len) + double(ps.Stream.ReadByte);
                    if len<=0, ps.BeginRead; return; end
                    msgbuf = NET.createArray('System.Byte',len);
                    rdbytes = ps.Stream.Read(msgbuf,0,len);
                    if rdbytes ~= len && ps.Verbose
                        disp(['ServerReceive: mismatched read, expected ' num2str(len) ', got ' num2str(rdbytes)]);
                        disp(char(uint8(msgbuf)));
                    end
                    msg = ps.StreamEncoding.GetString(msgbuf);
                    ps.Message = msg;
                    ps.MsgRecvCallback(msg,ps);
                    
                    %                 if ps.Stream.IsMessageComplete
                    %                     ps.Message = [ps.Message; msg(:)];
                    %                     ps.MsgRecvCallback(msg,ps);
                    %                     ps.Message = [];
                    %                 else
                    % collect the message until it's complete
                    %                      ps.Message = [ps.Message; msg(:)];
                    %                 end
                end
            end
            ps.CloseAndReopen;
            ps.Connect;
            
%             if ps.Stream.IsConnected
%                 ps.BeginRead;
%             else
%                 ps.Connect;
%             end
        end
        
        function DefaultMsgRecv(msg,pserver)
            % this is a sample callback function (and the default, for testing)
            %if ~strcmp(char(msg),'ACK')
                if pserver.Verbose
                    disp(['<' pserver.Name '> received message: ' char(msg)]);
                end
%                 pserver.SendToClient('ACK');
%             end
        end
        
        function SendCallback(ar)
            % use the passed name to retrieve the PipeServer object
            psName = char(ar.AsyncState);
            ps = ThorPipeServer.named(psName(2:end),0);
            if isempty(ps), return; end
            ps.Stream.EndWrite(ar);
            if ps.Verbose
                disp(['we sent msg: ' ps.MessageOut{1}]);
            end
            ps.MessageOut = [];
        end
        
        function ConnectCallback(ar)
            psName = char(ar.AsyncState);
            ps = ThorPipeServer.named(psName(2:end),0);
            if isempty(ps), return; end
            if ps.Verbose, 
                disp(['CONNECTed pipe (' psName(1) '): ' psName(2:end)]); 
                disp('tps connect callback start');
            end
            %pause(0.2);
            ps.Stream.EndWaitForConnection(ar);
            if ps.Stream.IsConnected
                if ~isempty(ps.MessageOut)
                    uMsg = ps.MessageOut{2};
                    len = numel(uMsg);
                    uMsg = [uint8(floor(len/256)) uint8(bitand(len,255)) uMsg];
                    %ps.Stream.Flush;
                    ps.Stream.BeginWrite(uMsg,0,numel(uMsg),...
                        @ThorPipeServer.SendCallback,['*' ps.Name]);
                    if ps.Verbose, disp(['Server connected and sent msg: ' ps.MessageOut{1}]); end
                    ps.MessageOut = [];
                end
                ps.MakeBuffer;
                % disp('... read enabled pipe');
                ps.BeginRead;
            end
            if ps.Verbose, disp('tps connect callback end'); end
            
        end
        
    end
    
    
 end
 