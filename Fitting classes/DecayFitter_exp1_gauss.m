classdef DecayFitter_exp1_gauss < DecayFitter
    %DecayFitter_exp1_gauss   a lifetime decay fitters
    %   performs nonlinear fit
    
    properties 
        params
        floats = logical([1 1 1 1 1])
        
        cycleLength = 12.5;  % typically 12.5 ns
        bkg = 0;             % inferred background

        transforms = [0 0 0 0 3]; % bounded positive for scatter 
        
        tauType = 1;  % tauType=1 is tau8, tauType=2 is tauEffectiveWindowed[-0.3,8]
        tauParam = [-0.3,8];  % window limits for tauEffectiveWindowed 
                              % if tauType = 1, the SECOND value is the
                              % limit
        nsPerPoint = 0.05;  % default

    end    
    
    
    methods 
        function obj = DecayFitter_exp1_gauss
        end
        
        function set.floats(obj,val)
            obj.floats = logical(val);
        end
        
        % e.g. tau1, tau2...
        function cstr = paramNames(~)
            cstr = {'amp1' 'tau1' 'tPeak' 'gaussW' 'scatter'};
        end
        
        function cstr = excelFormats(~)
            cstr = {'0', '0.00', '0.00', '0.000', '0'};
        end
        
        % text of equation
        function str = equation(~)
            % it is implicit that the exp function is zero-valued for t<0
            str = {'[amp1 exp(-t/tau1) + scatter*?(t)] (*) gauss(tPeak,gaussW)'};
        end
        
        % parameters that are matched from one fitter to the next
        % e.g. 1 = A1, 2 = T1, 3 = TPeak, 4 = GaussW  
        function ids = paramIDs(obj) 
            ids = [1 2 3 4 0];
        end

        function [vals,fail,tau,redchisq] = fitProgressive(obj,t,data,gaussW)
            if nargin<4, gaussW=0.06; end
            tau = []; redchisq = [];
            [mx,idx] = max(data); % estimator for A0
            tPk0 = t(idx) - gaussW; % estimator for tPeak
            % new estimator of mean tau that uses wraparound
            tbase = t(:)' - tPk0;  % the timebase offset for tPk0
            tbase(1:(idx-5)) = tbase(1:(idx-5)) + obj.cycleLength;
            tau = (tbase * data(:)) / sum(data); % mean tau
            p = [mx tau tPk0 gaussW 0];
            % respect the fixed parameters, preset only the floats
            obj.params(obj.floats) = p(obj.floats);
            
            [vals,fail] = obj.fit(t,data,[1 1 0 0 0]);
            if fail, fail=-1; return; end
            
            % progressively relax the fit
            [vals,fail] = obj.fit(t,data,[1 1 1 0 1]);
            if fail, fail=-2; return; end
            [vals,fail,tau,redchisq] = obj.fit(t,data,[1 1 1 1 1]);
            if fail, fail=-3; return; end
        end
                
        % decay fit integrated over t range (using tPeak)
        % should match the empirical tau
        function tau = tauEffectiveTruncated(obj,t,data,tPeak)
            if nargin<3, data = obj.model(t); end
            if nargin<4, tPeak = obj.params(obj.paramIDs==3); end
            tau = ((t(:)' - tPeak) * data(:)) / sum(data); % mean tau
        end
        
        function tau = tauFitTruncated(obj,tIntegration,params)
            if nargin<2, tIntegration = 8; end
            if nargin<3, params = obj.params; end
            tau1 = params(2);  
            xp1 = exp(-tIntegration/tau1);
            tau = (tau1 - xp1*(tIntegration+tau1))/(1-xp1);
        end
             
        function etau = tauEffectiveWindowed(obj,t,y,tPeak,loHiTimes)
            % similar to empirical tau, but restricted to the window
            %  [tPeak+loHiTimes(1),tPeak+loHiTimes(2)]
            %  default values are -0.3 ns, +8.0 ns
            % nsPerPoint=.05;  % TODO fix sometime to make more general
            if nargin<4, tPeak = obj.params(obj.paramIDs==3); end
            if nargin<5, loHiTimes=obj.tauParam; end
            tLoHi = tPeak+loHiTimes;
            
            % get the first and last FULLY-INCLUDED bins
            idx1 = find(t >= tLoHi(1),1,'first');
            idx2 = find(t <  tLoHi(2),1,'last');
            tt = t(:);
            numerFullbins = (tt(idx1:idx2)'-tPeak) * y(idx1:idx2);
            denomFullbins = sum(y(idx1:idx2));
            % for the 'pre-firstFullBin' partial bin
            frLeft  = 1 - (tLoHi(1) - t(idx1-1))/obj.nsPerPoint;
            frRight = 1 - (t(idx2+1)- tLoHi(2))/obj.nsPerPoint;
            numerAll = frLeft*t(idx1-1)*y(idx1-1) + numerFullbins + ...
                frRight*t(idx2+1)*y(idx2+1);
            denomAll = frLeft*y(idx1-1) + denomFullbins + frRight*y(idx2+1);
            etau = numerAll/denomAll;
        end
                
        function varargout = fit(obj,t,data,varargin) % optional args: floats, params
            if numel(varargin)>=1
                ufloats = logical(varargin{1}) & logical(obj.floats);
            else
                ufloats = logical(obj.floats);
            end
            if numel(varargin)>=2, obj.params = varargin{2}; end
            [paramsNew,fail] = nlinfitGY2(t, data, @obj.modelFcn, ...
                obj.params, ufloats, obj.transforms);
            if ~fail, obj.params = paramsNew; end
            vals = obj.modelFcn(obj.params, t, data);
            if nargout<3, varargout = {vals,fail}; return; end
            
            % if requested, compute tauTrunc, chisqreduced
            tau = obj.tauEffectiveTruncated(t,vals);
            residual = data(:) - vals(:);
            chisq = sum(residual .* residual ./ max(vals(:),1));
            redchisq = chisq/(numel(data)-sum(obj.floats));
            varargout = {vals,fail,tau,redchisq};
        end
        
        function val = model(obj,t,data)
            if nargin >2
                val = obj.modelFcn(obj.params, t, data);
            else
                % need to preserve the background value, which will
                % otherwise be destroyed by the model function
                bkg_saved = obj.bkg;
                % by passing the data as zero, the background will be zero
                data = modelFcn(obj, obj.params, t, 0*t);
                val  = data + bkg_saved; % return the fit including the background
                obj.bkg = bkg_saved;
            end
        end
        
        function [fit,bkg] = modelFcn(obj, p, t, data)
            %beta0(1): peak
            %beta0(2): exp tau
            %beta0(5): center
            %beta0(6): gaussian width
            % 1/2*erfc[(s^2-tau*x)/{sqrt(2)*s*tau}] * exp[s^2/2/tau^2 - x/tau]
            
            % get params as plain variables
            pulseI = obj.cycleLength;
            amp1   = p(1);
            tau1   = p(2);
            tPeak  = p(3);
            gaussW = p(4);
            scattr = p(5);
            
            
            y1 = amp1 * exp(gaussW^2/2/tau1^2 - (t-tPeak)/tau1);
            y2 = erfc((gaussW^2-tau1*(t-tPeak))/(sqrt(2)*tau1*gaussW));
            y=y1.*y2;
            
            %"Pre" pulse from the wraparound
            y1 = amp1 * exp(gaussW^2/2/tau1^2 - (t-tPeak+pulseI)/tau1);
            y2 = erfc((gaussW^2-tau1*(t-tPeak+pulseI))/(sqrt(2)*tau1*gaussW));
            
            y = y1.*y2+y ;
            y = y/2;
            
            % scatter times shifted gaussian
            ys = scattr/(gaussW*2.5066283)*exp(-((t-tPeak).*(t-tPeak))/(2*gaussW*gaussW));
            
            fit = y+ys;
            
            % correct for BACKGROUND
            % the minimum point in the fit defines the end of the prepulse
            [~,locmin]=min(fit);
            
            % calculate the offset needed to bring this region up to the observed
            % value in the data (which are stored in spc.fit.lifetime)
            backCorr = mean(data(1:locmin)) - mean(fit(1:locmin)); %  (sum(data(1:locmin)) - sum(fit(1:locmin))) / locmin;
            fit = fit + max(backCorr,0);
            
            bkg = max(backCorr,0);
        end
        
    end % methods
    
end
