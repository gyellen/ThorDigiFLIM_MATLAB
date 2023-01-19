function monitorImageFiles(fspec)
% monitorImageFiles('D:\Folder\subfolder\name*.ext')
%   monitors for new files that match the spec, marking
%   them with their time of appearance and storing them in 
%   a global variable, imageFileMonitor.filesInWait
% USAGE EXAMPLE
%   monitorImageFiles('d:\Temp\testTile1\ChanA*.tif');
%   keepChecking = true;
%   while(keepChecking)
%       [fname,agedOut,filedate] = getNextImageFile(minAgeInSec);
%       if fname
%           % PROCESS NEW FILE HERE
%               ...
%           if (agedOut), keepChecking=false; end
%       else
%           pause(1);
%       end
%   end
global imageFileMonitor imageFileMonitorTimer

if ~isempty(imageFileMonitorTimer)
    stop(imageFileMonitorTimer);
end

% reset the monitor variables
imageFileMonitor.olddir=[];
imageFileMonitor.filespec=fspec;
imageFileMonitor.filesInWait=[];

if isnumeric(fspec), return; end

t = timer;
t.Period = 1;
t.ExecutionMode = 'fixedrate';
t.TimerFcn = @fileMonitorFcn;
start(t);
imageFileMonitorTimer = t;
return;

function fileMonitorFcn(varargin)
global imageFileMonitor

% get the current directory contents
newdir = dir(imageFileMonitor.filespec);

% mark with the time seen, and sort by age
[newdir(:).apparentAt] = deal(now);
[~,idx] = sort([newdir.datenum]);
newdir = newdir(idx);

if isempty(imageFileMonitor.olddir) || size(imageFileMonitor.olddir,1)==0
    imageFileMonitor.olddir = newdir;
    imageFileMonitor.filesInWait = newdir;
else
    % identify the new files that have appeared (if any)
    [~,newidx] = setdiff({newdir.name},{imageFileMonitor.olddir.name});
    
    % add them to the end of the list (with their apparentAt field)
    imageFileMonitor.filesInWait = [imageFileMonitor.filesInWait; newdir(newidx)];
    imageFileMonitor.olddir = newdir;
end
return
