function [betaCall,fail,r,J] = nlinfitGY2(X,y,model,beta0full,floats,transforms,varargin)
%Modified by Ryohei Yasuda; Gary Yellen [2010-2012; removed WEIGHT parameter].
% [BETA,fail,R,J] = NLINFIT(X,Y,FUN,BETA0,FLOATS,TRANSFORMS,varargin)
% (ry):  WEIGHT is weight for fitting. For fitting to photo-measurement,
%           you should use sqrt(y). 
% (gy):  FLOATS is a logical array indicating which parameters are actually
%           to be varied.  All other parameters are not included in the Gauss method,
%           and are passed unaltered (and constant) to the model function
%        TRANSFORMS (optional) is an array matching beta0 in size.  It specifies a
%           transform to apply to each parameter before the optimization search.  At
%           the moment, 
%		0 specifies no transformation 
%		1 specifies log transformation (search domain (0,Inf))
%		2 specifies arcsin transformation (search domain [0,1])
%		3 specifies arcsin transformation (search domain [0,100000])
%	    All parameter values are reverse-transformed before being passed to the 
%           model function, so these transforms are transparent to both the calling
%           function and the model function.
%
%  Model function is called as model(params,X,varargin)                 
%
%NLINFIT Nonlinear least-squares data fitting by the Gauss-Newton method.
%   NLINFIT(X,Y,FUN,BETA0) estimates the coefficients of a nonlinear
%   function.  Y is a vector.  X is a vector or matrix with the same
%   number of rows as Y.  FUN is a function that accepts two arguments,
%   a coefficient vector and an array of X values, and returns a vector
%   of fitted Y values.  BETA0 is a vector containing initial guesses for
%   the coefficients.
%
%   [BETA,R,J] = NLINFIT(X,Y,FUN,BETA0) returns the fitted coefficients
%   BETA, the residuals R, and the Jacobian J.  You can use these outputs
%   with NLPREDCI to produce error estimates on predictions, and with
%   NLPARCI to produce error estimates on the estimated coefficients.
%
%   Examples
%   --------
%   FUN can be specified using @:
%      nlintool(x, y, @myfun, b0)
%   where MYFUN is a MATLAB function such as:
%      function yhat = myfun(beta, x)
%      b1 = beta(1);
%      b2 = beta(2);
%      yhat = 1 ./ (1 + exp(b1 + b2*x));
%
%   FUN can also be an inline object:
%      fun = inline('1 ./ (1 + exp(b(1) + b(2)*x))', 'b', 'x')
%      nlintool(x, y, fun, b0)
%
%   See also NLPARCI, NLPREDCI, NLINTOOL.

%   B.A. Jones 12-06-94.
%   Copyright 1993-2000 The MathWorks, Inc. 
% $Revision: 2.20 $  $Date: 2000/05/26 18:53:20 $

%
%   G. Yellen revision to search on only certain of the parameters
%   2010-09-04
%   The full parameter set is passed from the calling program and to the
%     model function.  'floats' can be a logical array or a list indicating the
%     parameters that can vary.
%   In other words, the fixed/floating status is transparent both to the 
%     calling function and the model function

%if (nargin<4), error('NLINFIT requires four arguments.'); end
%if (nargin<5), error('NLINFIT requires five arguments.'); end % GY


gydebug=0;
warning off backtrace


% GY
betaCall = beta0full(:);  % this structure will be used to call the model FN
% pull out the varying parameters
beta0 = beta0full(floats(:));  % GY: initial value of variable parameters
% now transform them (e.g. log domain) if necessary
if nargin>=6 && length(transforms)>0
    shortTransform=transforms(floats(:));
    if sum(shortTransform)>0
        for k=1:length(shortTransform)
            % do the transformation
            switch shortTransform(k)
                case 0
                    % do nothing
                case 1
                    beta0(k)=log(beta0(k));
                case 2
                    jjj=min(max(0,beta0(k)),1);  % constrain to range 0-1
                    beta0(k)=100*asin(2*jjj-1);  % varies 0-1; reverse with (1+sin(betaCall(k))/2
                case 3
                    jjj=min(max(0,beta0(k)/100000),1);  % varies from 0 to 100000
                    beta0(k)=100*asin(2*jjj-1);  % varies 0-1; reverse with (1+sin(betaCall(k))/2
            end
        end
    else
        shortTransform=[];
    end
else
    shortTransform=[];
end
% now back to regular NLINFIT
if min(size(y)) ~= 1
   error('Requires a vector second input argument.');
end
y = y(:);
% gy 20121218 (reinstated code below using yfit to weight) 
% weight = weight(:); %Added by RYohei
if size(X,1) == 1 % turn a row vector into a column vector.
   X = X(:);
end

wasnan = (isnan(y) | any(isnan(X),2));
if (any(wasnan))
   y(wasnan) = [];
   X(wasnan,:) = [];
end
n = length(y);

p = length(beta0);
beta0 = beta0(:);

J = zeros(n,p);
beta = beta0;
% GY: the increment following provides a scale - may lead to issues for the log data
% GY: changed from 1 to 0.3
betanew = beta + 0.3;  
maxiter = 100; %default = 100
iter = 0;
betatol = 0.5E-6;  %default = 1e-4
rtol = 0.5E-6; %default = 1e-4
sse = 1;
sseold = sse;
seps = sqrt(eps);
zbeta = zeros(size(beta));
s10 = sqrt(10);
eyep = eye(p);
zerosp = zeros(p,1);
while (norm((betanew-beta)./(beta+seps)) > betatol | abs(sseold-sse)/(sse+seps) > rtol) & iter < maxiter
   if iter > 0, 
      beta = betanew;
   end

   iter = iter + 1;
   % first model call
   yfit = feval(model,fullParams(beta, beta0full, floats, shortTransform),X,y);  % GY
   % SSE calculation - gy changed 20120718 to weight using the square root
   % of the FIT value
   % (this 20120718 version reinstated by gy 20121218)
    r = y - yfit;
%    r = r./weight;  %added by Ryohei
%    r = r ./ sqrt(yfit);  % gy 20120718
%    sseold = r'*r;
   sseold = sum( (y-yfit).^2 ./ max(yfit,1) );  % gy 20120718 modified 201305 to eliminate negative value problem
   if gydebug
       disp(['   dF_nlinfitGY [A] ' num2str(sseold)]);
   end


   for k = 1:p,
      delta = zbeta;
      if (beta(k) == 0)
         nb = sqrt(norm(beta));
         delta(k) = seps * (nb + (nb==0));
      else
         delta(k) = seps*beta(k);
      end
      yplus = feval(model,fullParams(beta+delta, beta0full, floats, shortTransform),X,y);  % GY
      J(:,k) = (yplus - yfit)/delta(k);
   end

   Jplus = [J;(1.0E-2)*eyep];
   rplus = [r;zerosp];

   % gy 201111 handle rank-deficiencies as fit error
   lastwarn('',''); % reset the warning history
   
   % Levenberg-Marquardt type adjustment 
   % Gauss-Newton step -> J\r
   % LM step -> inv(J'*J+constant*eye(p))*J'*r
   step = Jplus\rplus;
   
   if ~isempty(lastwarn) % if the last statement threw a warning
       [~,msgid]=lastwarn;
       if strfind(msgid,'rankDeficientMatrix')
           disp(' > Fitting failure: adjust starting parameters');
       end
       iter=maxiter+1; % forces non-convergence condition and failedFit
   end
      
   
   betanew = beta + step;
   yfitnew = feval(model,fullParams(betanew, beta0full, floats, shortTransform),X,y);  % GY
   % SSE calculation - gy changed 20120718 to weight using the square root
   % of the FIT value
%   rnew = y - yfitnew;
%    rnew = rnew./weight; %Added by RYohei
%    sse = rnew'*rnew;
   sse = sum( (y-yfitnew).^2 ./ max(yfitnew,1) );  % gy 20120718 modified 201305 to eliminate negative value problem
   if gydebug
       disp(['   dF_nlinfitGY [B] ' num2str(sse)]);
   end
   iter1 = 0;
   while sse > sseold && iter1 < 12
      step = step/s10;
      betanew = beta + step;
      yfitnew = feval(model,fullParams(betanew, beta0full, floats, shortTransform),X,y);  % GY
%       rnew = y - yfitnew;
%        rnew = rnew./weight; %Added by Ryohei
%        sse = rnew'*rnew; 
      sse = sum( (y-yfitnew).^2 ./ max(yfitnew,1) );  % gy 20120718 modified 201305 to eliminate negative value problem
      if gydebug
        disp(['   dF_nlinfitGY [C] ' num2str(sse)]);
      end
      iter1 = iter1 + 1;
   end
end
% detransform everything for returning to caller
betaCall=fullParams(beta, beta0full, floats, shortTransform);
% debug GY 201112
iter=iter-1;
% end
    if iter==maxiter
        fail=1;
    else
        fail=0;
    end
if iter == maxiter
    disp('NLINFIT did NOT converge. Returning results from last iteration.');
end
%disp('Iteration number =');
%disp(iter);
warning on backtrace

function betaCall = fullParams(beta, betaFull, floats, shortTransform)
% beta's are in the transformed (e.g. logarithmic) context
% this function takes the floating betas, de-transforms them and puts them
% into a full length parameter vector
betaDetrans=beta;
for k=1:length(shortTransform)
    % do the transformation
    switch shortTransform(k)
        case 0
            % do nothing
        case 1
            betaDetrans(k)=exp(beta(k));
        case 2
            betaDetrans(k)=(1+sin(beta(k)/100))/2;
        case 3  % varies from 0 to 100000
            betaDetrans(k)=100000*(1+sin(beta(k)/100))/2;
    end
end
betaCall=betaFull(:);
betaCall(floats(:))=betaDetrans;
    