classdef (ConstructOnLoad) ThorIpcEventData < event.EventData
    properties
        PassedString
        PassedArray
    end
    
    methods 
        function data = ThorIpcEventData(str,arr)
            data.PassedString = str;
            if nargin>1
                data.PassedArray = arr;
            end
        end
    end
end