function [newFname,agedOut,filetime] = getNextImageFile(minimumAgeInSec)
% gets the most recent new image file being monitored
%   files are only returned once there is a later file,
%   or if the file has the specified minimumAgeInSec
global imageFileMonitor

% default return values
newFname = [];  agedOut = false; filetime = '';

for k=0:minimumAgeInSec*2  % keep trying for the age limit
    if size(imageFileMonitor.filesInWait,1)>0, break; end
    pause(0.5);
end

if size(imageFileMonitor.filesInWait,1)==0, return; end

% deliver the first file that has a lower apparentAt than the others
for k=0:minimumAgeInSec*2  % keep trying for the age limit
    aat1 = imageFileMonitor.filesInWait(1).apparentAt;
    age1 = 24*60*60*(now-imageFileMonitor.filesInWait(1).datenum);  % age of file in sec
    if any([imageFileMonitor.filesInWait.apparentAt]>aat1) || age1>minimumAgeInSec
        % then it's ok to return file 1
        newFname = imageFileMonitor.filesInWait(1).name;
        if age1>minimumAgeInSec, agedOut=true; end
        filetime = imageFileMonitor.filesInWait(1).date;
        if size(imageFileMonitor.filesInWait,1)>1
            imageFileMonitor.filesInWait = imageFileMonitor.filesInWait(2:end);
        else
            imageFileMonitor.filesInWait = [];
        end
        break;
    else
        pause(0.5);
    end
end