classdef (Abstract) DecayFitter < handle
    %DecayFitter  Abstract superclass for the lifetime decay fitters
    %   Describes a set of parameters, initialization rules, etc.
    
    properties (Abstract)
        params
        floats
        cycleLength  % typically 12.5
        bkg          % inferred background
    end
    
    methods
        function p = paramTable(obj,maxdig)
            if nargin<2, maxdig=4; end
            p = [obj.paramNames'  obj.formattedParams];
        end
        
        function p = formattedParams(obj,paramVals,maxdig)
            if nargin<2, paramVals = obj.params; end
            if nargin<3, maxdig=3; end
            p = arrayfun(@(x) num2str(x, ...
                ['%6.' num2str(max(0,floor(maxdig-max(0,log10(max(x,0.01)))))) 'f']...
                ), paramVals,'UniformOutput',false);
            p(paramVals==0) = {'0'};  % special case
        end
            
        function n = nParams(obj)
            n = numel(obj.paramNames);
        end
        
    end
    
    methods (Abstract)
        % e.g. tau1, tau2...
        cstr = paramNames(obj)
        
        % text of equation
        str = equation(obj)
        
        % parameters that can be transferred from one fitter to another
        % e.g. 1 = A1, 2 = T1, 3 = TPeak, 4 = GaussW  
        ids = paramIDs(obj)  
        
        % decay fit integrated over t range (using tPeak)
        % should match the empirical tau
        val = tauEffectiveTruncated(obj,t)
     
        vals = fitProgressive(obj,t,data,gaussW)
        
        vals = fit(obj,t,data,varargin) % optional args: floats, params
        
        val = model(obj,t)
        
    end
    
end

