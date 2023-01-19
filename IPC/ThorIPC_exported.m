classdef ThorIPC_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        ThorIPCControlUIFigure        matlab.ui.Figure
        ClearqueueButton              matlab.ui.control.Button
        ResetButton                   matlab.ui.control.Button
        FiledispatchfnEditField       matlab.ui.control.EditField
        FiledispatchfnEditFieldLabel  matlab.ui.control.Label
        SuspendqueueingCheckBox       matlab.ui.control.CheckBox
        FiletypefilterEditField       matlab.ui.control.EditField
        FiletypefilterEditFieldLabel  matlab.ui.control.Label
        FilesinQueueListBox           matlab.ui.control.ListBox
        FilesinQueueListBoxLabel      matlab.ui.control.Label
        MessagesTextArea              matlab.ui.control.TextArea
        MessagesTextAreaLabel         matlab.ui.control.Label
        DisposeButton                 matlab.ui.control.Button
        LaunchIPCButton               matlab.ui.control.Button
    end

    
    properties (Access = private)
        computerName  % this computer name
        clientPipe    % the ThorClientPipe object
        serverPipe    % the ThorServerPipe object
    end
    
    methods (Access = public)
        
        function listenFunc(app,caller,evnt)
            global app_ThorIPC ipcFileQueue
            app = app_ThorIPC;
            app.showMessage([evnt.EventName ': ' evnt.PassedString{1}]);
            if ~isempty(evnt.PassedArray)
                app.showMessage(evnt.PassedArray);
            end
            switch evnt.EventName
                case 'ThorNewFile'
                    fname = evnt.PassedString{1};
                    if ~app.SuspendqueueingCheckBox.Value && contains(fname,app.FiletypefilterEditField.Value)
                        if ipcFileQueue.nextIn==ipcFileQueue.nextAvail-1
                            % problem with the size of the file queue 
                            % we're about to write over the tail
                            % expand the queue at the breakpoint by sizeup
                            sizeup = 50;
                            big = cell(numel(ipcFileQueue.files)+sizeup,1);
                            big(1:ipcFileQueue.nextIn-1) = ipcFileQueue.files(1:ipcFileQueue.nextIn-1);
                            big(sizeup+(ipcFileQueue.nextAvail:numel(ipcFileQueue.files))) = ...
                                ipcFileQueue.files(ipcFileQueue.nextAvail:end);
                            ipcFileQueue.files = big;
                            ipcFileQueue.nextAvail = ipcFileQueue.nextAvail+sizeup;
                        end
                        % add filename to queue
                        ipcFileQueue.files{ipcFileQueue.nextIn} = fname;
                        ipcFileQueue.nextIn = 1+mod(ipcFileQueue.nextIn,numel(ipcFileQueue.files));
                        app.updateFileQueue;
                    end
            end
        end

        function displayMsg(app,obj)
            msg = char(formattedDisplayText(obj));
            app.showMessage(msg(1:end-1));
        end

        function updateFileQueue(app)
           global ipcFileQueue
            if ipcFileQueue.nextIn >= ipcFileQueue.nextAvail
                % no wraparound
                currentQueue = ipcFileQueue.files(ipcFileQueue.nextAvail:ipcFileQueue.nextIn-1);
            else
                currentQueue = [ipcFileQueue.files(ipcFileQueue.nextAvail:end) ; ...
                    ipcFileQueue.files(1:ipcFileQueue.nextIn-1)];
            end
            app.FilesinQueueListBox.Items = currentQueue;
            if ~isempty(currentQueue), app.FilesinQueueListBox.scroll('bottom'); end
        end

        function fname = nextAvailableFile(app,keepInQueue)
            % retrieves the name of the next available file
            % pops it from queue unless keepInQueue is provided and true
            global ipcFileQueue
            if ipcFileQueue.nextAvail ~= ipcFileQueue.nextIn
                fname = ipcFileQueue.files{ipcFileQueue.nextAvail};
                if nargin<2 || ~keepInQueue
                    ipcFileQueue.nextAvail = 1+mod(ipcFileQueue.nextAvail,numel(ipcFileQueue.files));
                end
                app.updateFileQueue
            else
                fname = [];
            end
        end

    end
    
    methods (Access = private)
        
        function showMessage(app,msg)
            app.MessagesTextArea.Value{end+1} = msg;
            app.MessagesTextArea.scroll('bottom');
        end

    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            global app_ThorIPC ipcFileQueue
            evalin('base','global app_ThorIPC ipcFileQueue');
            app_ThorIPC = app;
            if isempty(ipcFileQueue)
                ipcFileQueue.nextIn = 1;
                ipcFileQueue.nextAvail = 1;
                ipcFileQueue.files = cell(100,1);
            else
                app.updateFileQueue
            end
            app.computerName = getenv('COMPUTERNAME');
            app.LaunchIPCButtonPushed
            
        end

        % Button pushed function: LaunchIPCButton
        function LaunchIPCButtonPushed(app, event)
            if ~isempty(ThorPipeClient.IPC(0))
                ThorPipeClient.IPC.Dispose; % probably safer this way
            end
            ThorPipeClient.IPC.addlistener('ThorNewFile',@app.listenFunc);
            pause(1);
            ThorPipeClient.IPC.pserver.SendToClient( ...
                ['Remote~Local~Establish~' app.computerName]);
            pause(0.2);
            ThorPipeClient.IPC.Connect;
        end

        % Button pushed function: DisposeButton
        function DisposeButtonPushed(app, event)
            ThorPipeClient.IPC.Dispose
        end

        % Close request function: ThorIPCControlUIFigure
        function ThorIPCControlUIFigureCloseRequest(app, event)
            delete(app)
            ThorPipeClient.IPC.Dispose
        end

        % Button pushed function: ClearqueueButton
        function ClearqueueButtonPushed(app, event)
            % TODO are you sure?
            global ipcFileQueue
            ipcFileQueue.nextAvail = 1;
            ipcFileQueue.nextIn    = 1;
        end

        % Value changed function: SuspendqueueingCheckBox
        function SuspendqueueingCheckBoxValueChanged(app, event)
            value = app.SuspendqueueingCheckBox.Value;
            if value
                app.SuspendqueueingCheckBox.FontWeight = 'bold';
                app.SuspendqueueingCheckBox.FontColor  = [1 0 0];
            else
                app.SuspendqueueingCheckBox.FontWeight = 'normal';
                app.SuspendqueueingCheckBox.FontColor  = [0 0 0];
            end
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create ThorIPCControlUIFigure and hide until all components are created
            app.ThorIPCControlUIFigure = uifigure('Visible', 'off');
            app.ThorIPCControlUIFigure.Position = [100 100 625 357];
            app.ThorIPCControlUIFigure.Name = 'ThorIPC Control';
            app.ThorIPCControlUIFigure.CloseRequestFcn = createCallbackFcn(app, @ThorIPCControlUIFigureCloseRequest, true);

            % Create LaunchIPCButton
            app.LaunchIPCButton = uibutton(app.ThorIPCControlUIFigure, 'push');
            app.LaunchIPCButton.ButtonPushedFcn = createCallbackFcn(app, @LaunchIPCButtonPushed, true);
            app.LaunchIPCButton.Position = [16 320 100 22];
            app.LaunchIPCButton.Text = 'Launch IPC';

            % Create DisposeButton
            app.DisposeButton = uibutton(app.ThorIPCControlUIFigure, 'push');
            app.DisposeButton.ButtonPushedFcn = createCallbackFcn(app, @DisposeButtonPushed, true);
            app.DisposeButton.Position = [16 289 100 22];
            app.DisposeButton.Text = 'Dispose';

            % Create MessagesTextAreaLabel
            app.MessagesTextAreaLabel = uilabel(app.ThorIPCControlUIFigure);
            app.MessagesTextAreaLabel.HorizontalAlignment = 'right';
            app.MessagesTextAreaLabel.Position = [48 103 60 22];
            app.MessagesTextAreaLabel.Text = 'Messages';

            % Create MessagesTextArea
            app.MessagesTextArea = uitextarea(app.ThorIPCControlUIFigure);
            app.MessagesTextArea.Position = [123 23 432 104];

            % Create FilesinQueueListBoxLabel
            app.FilesinQueueListBoxLabel = uilabel(app.ThorIPCControlUIFigure);
            app.FilesinQueueListBoxLabel.HorizontalAlignment = 'right';
            app.FilesinQueueListBoxLabel.FontWeight = 'bold';
            app.FilesinQueueListBoxLabel.Position = [21 246 88 22];
            app.FilesinQueueListBoxLabel.Text = 'Files in Queue';

            % Create FilesinQueueListBox
            app.FilesinQueueListBox = uilistbox(app.ThorIPCControlUIFigure);
            app.FilesinQueueListBox.Items = {};
            app.FilesinQueueListBox.Position = [124 150 431 120];
            app.FilesinQueueListBox.Value = {};

            % Create FiletypefilterEditFieldLabel
            app.FiletypefilterEditFieldLabel = uilabel(app.ThorIPCControlUIFigure);
            app.FiletypefilterEditFieldLabel.HorizontalAlignment = 'right';
            app.FiletypefilterEditFieldLabel.Position = [329 320 77 22];
            app.FiletypefilterEditFieldLabel.Text = 'File type filter';

            % Create FiletypefilterEditField
            app.FiletypefilterEditField = uieditfield(app.ThorIPCControlUIFigure, 'text');
            app.FiletypefilterEditField.HorizontalAlignment = 'center';
            app.FiletypefilterEditField.Position = [421 320 133 22];
            app.FiletypefilterEditField.Value = '.dFLIM';

            % Create SuspendqueueingCheckBox
            app.SuspendqueueingCheckBox = uicheckbox(app.ThorIPCControlUIFigure);
            app.SuspendqueueingCheckBox.ValueChangedFcn = createCallbackFcn(app, @SuspendqueueingCheckBoxValueChanged, true);
            app.SuspendqueueingCheckBox.Text = 'Suspend queueing';
            app.SuspendqueueingCheckBox.WordWrap = 'on';
            app.SuspendqueueingCheckBox.Position = [41 204 73 34];

            % Create FiledispatchfnEditFieldLabel
            app.FiledispatchfnEditFieldLabel = uilabel(app.ThorIPCControlUIFigure);
            app.FiledispatchfnEditFieldLabel.HorizontalAlignment = 'right';
            app.FiledispatchfnEditFieldLabel.Position = [320 289 86 22];
            app.FiledispatchfnEditFieldLabel.Text = 'File dispatch fn';

            % Create FiledispatchfnEditField
            app.FiledispatchfnEditField = uieditfield(app.ThorIPCControlUIFigure, 'text');
            app.FiledispatchfnEditField.HorizontalAlignment = 'center';
            app.FiledispatchfnEditField.Position = [421 289 133 22];

            % Create ResetButton
            app.ResetButton = uibutton(app.ThorIPCControlUIFigure, 'push');
            app.ResetButton.Position = [566 289 47 22];
            app.ResetButton.Text = 'Reset';

            % Create ClearqueueButton
            app.ClearqueueButton = uibutton(app.ThorIPCControlUIFigure, 'push');
            app.ClearqueueButton.ButtonPushedFcn = createCallbackFcn(app, @ClearqueueButtonPushed, true);
            app.ClearqueueButton.FontAngle = 'italic';
            app.ClearqueueButton.Position = [36 168 81 22];
            app.ClearqueueButton.Text = 'Clear queue';

            % Show the figure after all components are created
            app.ThorIPCControlUIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = ThorIPC_exported

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.ThorIPCControlUIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.ThorIPCControlUIFigure)
        end
    end
end