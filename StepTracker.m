function [Ypk,Xpk,Wpk,Ppk] = findpeaks(Yin,varargin)
%FINDPEAKS Find local peaks in data
%   PKS = FINDPEAKS(Y) finds local peaks in the data vector Y. A local peak
%   is defined as a data sample which is either larger than the two
%   neighboring samples or is equal to Inf.
%
%   [PKS,LOCS] = FINDPEAKS(Y) also returns the indices LOCS at which the
%   peaks occur.
%
%   [PKS,LOCS] = FINDPEAKS(Y,X) specifies X as the location vector of data
%   vector Y. X must be a strictly increasing vector of the same length as
%   Y. LOCS returns the corresponding value of X for each peak detected.
%   If X is omitted, then X will correspond to the indices of Y.
%
%   [PKS,LOCS] = FINDPEAKS(Y,Fs) specifies the sample rate, Fs, as a
%   positive scalar, where the first sample instant of Y corresponds to a
%   time of zero.
%
%   [...] = FINDPEAKS(...,'MinPeakHeight',MPH) finds only those peaks that
%   are greater than the minimum peak height, MPH. MPH is a real-valued
%   scalar. The default value of MPH is -Inf.
%
%   [...] = FINDPEAKS(...,'MinPeakProminence',MPP) finds peaks guaranteed
%   to have a vertical drop of more than MPP from the peak on both sides
%   without encountering either the end of the signal or a larger
%   intervening peak. The default value of MPP is zero.
%
%   [...] = FINDPEAKS(...,'Threshold',TH) finds peaks that are at least
%   greater than both adjacent samples by the threshold, TH. TH is a
%   real-valued scalar greater than or equal to zero. The default value of
%   TH is zero.
%
%   FINDPEAKS(...,'WidthReference',WR) estimates the width of the peak as
%   the distance between the points where the signal intercepts a
%   horizontal reference line. The points are found by linear
%   interpolation. The height of the line is selected using the criterion
%   specified in WR:
% 
%    'halfprom' - the reference line is positioned beneath the peak at a
%       vertical distance equal to half the peak prominence.
% 
%    'halfheight' - the reference line is positioned at one-half the peak 
%       height. The line is truncated if any of its intercept points lie
%       beyond the borders of the peaks selected by the 'MinPeakHeight',
%       'MinPeakProminence' and 'Threshold' parameters. The border between
%       peaks is defined by the horizontal position of the lowest valley
%       between them. Peaks with heights less than zero are discarded.
% 
%    The default value of WR is 'halfprom'.
%
%   [...] = FINDPEAKS(...,'MinPeakWidth',MINW) finds peaks whose width is
%   at least MINW. The default value of MINW is zero.
%
%   [...] = FINDPEAKS(...,'MaxPeakWidth',MAXW) finds peaks whose width is
%   at most MAXW. The default value of MAXW is Inf.
%
%   [...] = FINDPEAKS(...,'MinPeakDistance',MPD) finds peaks separated by
%   more than the minimum peak distance, MPD. This parameter may be
%   specified to ignore smaller peaks that may occur in close proximity to
%   a large local peak. For example, if a large local peak occurs at LOC,
%   then all smaller peaks in the range [N-MPD, N+MPD] are ignored. If not
%   specified, MPD is assigned a value of zero.  
%
%   [...] = FINDPEAKS(...,'SortStr',DIR) specifies the direction of sorting
%   of peaks. DIR can take values of 'ascend', 'descend' or 'none'. If not
%   specified, DIR takes the value of 'none' and the peaks are returned in
%   the order of their occurrence.
%
%   [...] = FINDPEAKS(...,'NPeaks',NP) specifies the maximum number of peaks
%   to be found. NP is an integer greater than zero. If not specified, all
%   peaks are returned. Use this parameter in conjunction with setting the
%   sort direction to 'descend' to return the NP largest peaks. (see
%   'SortStr')
%
%   [PKS,LOCS,W] = FINDPEAKS(...) returns the width, W, of each peak by
%   linear interpolation of the left- and right- intercept points to the
%   reference defined by 'WidthReference'.
%
%   [PKS,LOCS,W,P] = FINDPEAKS(...) returns the prominence, P, of each
%   peak.
%
%   FINDPEAKS(...) without output arguments plots the signal and the peak
%   values it finds
%
%   FINDPEAKS(...,'Annotate',PLOTSTYLE) will annotate a plot of the
%   signal with PLOTSTYLE. If PLOTSTYLE is 'peaks' the peaks will be
%   plotted. If PLOTSTYLE is 'extents' the signal, peak values, widths,
%   prominences of each peak will be annotated. 'Annotate' will be ignored
%   if called with output arguments. The default value of PLOTSTYLE is
%   'peaks'.
%
%   % Example 1:
%   %   Plot the Zurich numbers of sunspot activity from years 1700-1987
%   %   and identify all local maxima at least six years apart
%   load sunspot.dat
%   findpeaks(sunspot(:,2),sunspot(:,1),'MinPeakDistance',6)
%   xlabel('Year');
%   ylabel('Zurich number');
%
%   % Example 2: 
%   %   Plot peak values of an audio signal that drop at least 1V on either
%   %   side without encountering values larger than the peak.
%   load mtlb
%   findpeaks(mtlb,Fs,'MinPeakProminence',1)
%
%   % Example 3:
%   %   Plot all peaks of a chirp signal whose widths are between .5 and 1 
%   %   milliseconds.
%   Fs = 44.1e3; N = 1000;
%   x = sin(2*pi*(1:N)/N + (10*(1:N)/N).^2);
%   findpeaks(x,Fs,'MinPeakWidth',.5e-3,'MaxPeakWidth',1e-3, ...
%             'Annotate','extents')
%
%   See also MAX, FINDSIGNAL, FINDCHANGEPTS.

%   Copyright 2007-2024 The MathWorks, Inc.
%#ok<*EMCLS>
%#ok<*EMCA>
%#codegen

narginchk(1,22);
isInMATLAB = coder.target('MATLAB');

if nargout == 0 && ~isInMATLAB
    % Plotting is not supported for code generation. If this is running in
    % MATLAB, just call MATLAB's FINDPEAKS, else error.
    coder.internal.assert(coder.target('MEX') || coder.target('Sfun'), ...
        'signal:codegeneration:PlottingNotSupported');
    feval('findpeaks',Yin,varargin{:});
    return
end

% extract the parameters from the input argument list
[y,yIsRow,x,xIsRow,minH,minP,minW,maxW,minD,minT,maxN,sortDir,annotate,refW,outputPrototype] ...
  = parse_inputs(isInMATLAB,Yin,varargin{:});

if coder.gpu.internal.isGpuEnabled

    if nargout == 1
        % in only peaks are needed
        Ypk = signal.internal.findpeaks.findpeaksGPU( ...
            y,yIsRow,x,xIsRow,minH,minP,minW,maxW,minD,minT,maxN,sortDir,refW);
    elseif nargout == 2
         % if only peaks and locations are needed
         [Ypk,Xpk] = signal.internal.findpeaks.findpeaksGPU( ...
             y,yIsRow,x,xIsRow,minH,minP,minW,maxW,minD,minT,maxN,sortDir,refW);
    else
        [Ypk,Xpk,Wpk,Ppk] = signal.internal.findpeaks.findpeaksGPU( ...
             y,yIsRow,x,xIsRow,minH,minP,minW,maxW,minD,minT,maxN,sortDir,refW);
    end

else
    % indicate if we need to compute the extent of a peak
    needWidth = minW>0 || maxW<inf || minP>0 || nargout>2 || strcmp(annotate,'extents');

    if isInMATLAB
        % find indices of all finite and infinite peaks and the inflection points
        [iFinite,iInfinite,iInflect] = getAllPeaks(y);
        
        % keep only the indices of finite peaks that meet the required
        % minimum height and threshold
        iPk = removePeaksBelowMinPeakHeight(y,iFinite,minH,refW);
        iPk = removePeaksBelowThreshold(y,iPk,minT);
    else
        % Use equivalent one-pass code generation algorithms
        [iFinite,iInfinite,iInflect] = getAllPeaksCodegen(y);
        iPk = removeSmallPeaks(y,iFinite,minH,minT);
    end
    
    if needWidth
      % obtain the indices of each peak (iPk), the prominence base (bPk), and
      % the x- and y- coordinates of the peak base (bxPk, byPk) and the width
      % (wxPk)
      [iPk,bPk,bxPk,byPk,wxPk] = signal.internal.findpeaks.findExtents(...
          y,x,iPk,iFinite,iInfinite,iInflect,minP,minW,maxW,refW);
    else
      % combine finite and infinite peaks into one list
      [iPk,bPk,bxPk,byPk,wxPk] = combinePeaks(iPk,iInfinite,outputPrototype);
    end
    
    % find the indices of the largest peaks within the specified distance
    idx = findPeaksSeparatedByMoreThanMinPeakDistance(y,x,iPk,minD,sortDir);
    
    % use the index vector to fetch the correct peaks.
    % explicit creation of peaks to prevent resizing of iPk
    if(length(idx)>maxN)
        fPk = coder.nullcopy(zeros(maxN, 1, class(iPk)));
        % Keep at most maxN peaks
        idx = idx(1:maxN);
    else
        fPk = coder.nullcopy(zeros(size(idx), class(iPk)));
        maxN = cast(length(idx), class(maxN));
    end
    
    fPk = iPk(idx(1:length(fPk)));
    
    
    if nargout > 0
      % assign output variables
      if needWidth
        [Ypk,Xpk,Wpk,Ppk] = assignFullOutputs(y,x,fPk,wxPk,bPk,yIsRow,xIsRow,idx,maxN);
      else
        [Ypk,Xpk] = assignOutputs(y,x,fPk,yIsRow,xIsRow);
      end    
    else
      % no output arguments specified. plot and optionally annotate
      if needWidth
        [bPk, bxPk, byPk, wxPk] = fetchPeakExtents(idx,bPk,bxPk,byPk,wxPk);
      end
      signal.internal.findpeaks.plot(x,y,fPk,bPk,bxPk,byPk,wxPk,refW,annotate)
    end
end

%--------------------------------------------------------------------------
function [y,yIsRow,x,xIsRow,Ph,Pp,Wmin,Wmax,Pd,Th,NpOut,Str,Ann,Ref,outputPrototype] = parse_inputs(isInMATLAB,Yin,varargin)

% Validate input signal
validateattributes(Yin,{'double','single'},{'nonempty','real','vector'},...
    'findpeaks','Y');
y1 = reshape(Yin,[],1);
M = length(y1);

if isInMATLAB
    if M < 3
        error(message('signal:findpeaks:emptyDataSet'));
    end
    yIsRow = isrow(Yin);
else
    coder.internal.assert(M >= 3,'signal:findpeaks:emptyDataSet');
    % To return row vectors we require Yin to be a row vector type, i.e.
    % length(size(y)) == 2, size(y,1) is constant 1, and size(y,2) ==
    % length(y). Otherwise, the output allocation might be O(n^2) instead
    % of O(n).
    yIsRow = coder.internal.isConst(isrow(Yin)) && isrow(Yin);
end
isOutSingle = isUnderlyingType(Yin,"single");

% indicate if the user specified an Fs or X
hasTimeInfo = ~(isempty(varargin) || coder.internal.isCharOrScalarString(varargin{1}));
if hasTimeInfo
  startArg = 2;
  if isInMATLAB
      FsSupplied = isscalar(varargin{1});
  else
      FsSupplied = coder.internal.isConst(isscalar(varargin{1})) && isscalar(varargin{1});
  end

  isOutSingle = isOutSingle || (~FsSupplied && isnumeric(varargin{1}) && isUnderlyingType(varargin{1},"single"));
  if isOutSingle
    outputPrototype = zeros(1,1,"single"); % output prototype
  else
    outputPrototype = zeros(1,1,"double");
  end
  y = cast(y1,"like",outputPrototype);

  if FsSupplied
    % Fs
    validateattributes(varargin{1},{'numeric'},{'real','finite','positive'},'findpeaks','Fs');
    Fs = cast(varargin{1},"like",outputPrototype);
    x = (0:M-1).'/Fs;
    xIsRow = yIsRow;
  else
    % X
    validateattributes(varargin{1},{'numeric','datetime'},{'vector'},'findpeaks','X');
    if ~isInMATLAB
        coder.internal.errorIf(isdatetime(varargin{1}),'signal:findpeaks:DatetimeInputsNotSupported');
    end
    if isnumeric(varargin{1})
      validateattributes(varargin{1},{'numeric'},{'real','finite','increasing','numel',M},'findpeaks','X');
      Xin = cast(varargin{1},"like",outputPrototype);
    else % isdatetime(Xin)
      Xin1 = varargin{1};
      validateattributes(seconds(Xin1-Xin1(1)),{'double'},{'real','finite','increasing','numel',M},'findpeaks','X');
      Xin = Xin1;
    end
    
    if isInMATLAB
        xIsRow = isrow(Xin);
    else
        xIsRow = coder.internal.isConst(isrow(Xin)) && isrow(Xin);
    end
    x = reshape(Xin,M,1);
  end
else
  y = y1;
  outputPrototype = zeros(1,1,"like",y([]));
  startArg = 1;
  % unspecified, use index vector
  x = (1:M).';
  xIsRow = yIsRow;
end

%#function dspopts.findpeaks
if isInMATLAB
    p = signal.internal.findpeaks.getParser();
    parse(p,varargin{startArg:end});
    Ph = p.Results.MinPeakHeight;
    Pp = p.Results.MinPeakProminence;
    Wmin = p.Results.MinPeakWidth;
    Wmax = p.Results.MaxPeakWidth;
    Pd = p.Results.MinPeakDistance;
    Th = p.Results.Threshold;
    Np = p.Results.NPeaks;
    Str = p.Results.SortStr;
    Ann = p.Results.Annotate;
    Ref = p.Results.WidthReference;
else
    defaultMinPeakHeight = -inf;
    defaultMinPeakProminence = 0;
    defaultMinPeakWidth = 0;
    defaultMaxPeakWidth = Inf;
    defaultMinPeakDistance = 0;
    defaultThreshold = 0;
    defaultNPeaks = [];
    defaultSortStr = 'none';
    defaultAnnotate = 'peaks';
    defaultWidthReference = 'halfprom';

    parms = struct('MinPeakHeight',uint32(0), ...
                'MinPeakProminence',uint32(0), ...
                'MinPeakWidth',uint32(0), ...
                'MaxPeakWidth',uint32(0), ...
                'MinPeakDistance',uint32(0), ...
                'Threshold',uint32(0), ...
                'NPeaks',uint32(0), ...
                'SortStr',uint32(0), ...
                'Annotate',uint32(0), ...
                'WidthReference',uint32(0));
    pstruct = eml_parse_parameter_inputs(parms,[],varargin{startArg:end});
    Ph = eml_get_parameter_value(pstruct.MinPeakHeight,defaultMinPeakHeight,varargin{startArg:end});
    Pp = eml_get_parameter_value(pstruct.MinPeakProminence,defaultMinPeakProminence,varargin{startArg:end});
    Wmin = eml_get_parameter_value(pstruct.MinPeakWidth,defaultMinPeakWidth,varargin{startArg:end});
    Wmax = eml_get_parameter_value(pstruct.MaxPeakWidth,defaultMaxPeakWidth,varargin{startArg:end});
    Pd = eml_get_parameter_value(pstruct.MinPeakDistance,defaultMinPeakDistance,varargin{startArg:end});
    Th = eml_get_parameter_value(pstruct.Threshold,defaultThreshold,varargin{startArg:end});
    Np = eml_get_parameter_value(pstruct.NPeaks,defaultNPeaks,varargin{startArg:end});
    Str = eml_get_parameter_value(pstruct.SortStr,defaultSortStr,varargin{startArg:end});
    Ann = eml_get_parameter_value(pstruct.Annotate,defaultAnnotate,varargin{startArg:end});
    Ref = eml_get_parameter_value(pstruct.WidthReference,defaultWidthReference,varargin{startArg:end});
end

% limit the number of peaks to the number of input samples
if isempty(Np)
    NpOut = M;
else
    NpOut = Np;
end

% ignore peaks below zero when using halfheight width reference
if strcmp(Ref,'halfheight')
  Ph = max(Ph,0);
end

validateattributes(Ph,{'numeric'},{'real','scalar','nonempty'},'findpeaks','MinPeakHeight');
if isnumeric(x)
  validateattributes(Pd,{'numeric'},{'real','scalar','nonempty','nonnegative','<',x(M)-x(1)},'findpeaks','MinPeakDistance');
else
  if isInMATLAB && isduration(Pd)
    validateattributes(seconds(Pd),{'numeric'},{'real','scalar','nonempty','nonnegative'},'findpeaks','MinPeakDistance');
  else 
    validateattributes(Pd,{'numeric'},{'real','scalar','nonempty','nonnegative'},'findpeaks','MinPeakDistance');
  end    
end
validateattributes(Pp,{'numeric'},{'real','scalar','nonempty','nonnegative'},'findpeaks','MinPeakProminence');
if isInMATLAB && isduration(Wmin)
  validateattributes(seconds(Wmin),{'numeric'},{'real','scalar','finite','nonempty','nonnegative'},'findpeaks','MinPeakWidth');
else
  validateattributes(Wmin,{'numeric'},{'real','scalar','finite','nonempty','nonnegative'},'findpeaks','MinPeakWidth');
end
if isInMATLAB && isduration(Wmax)
  validateattributes(seconds(Wmax),{'numeric'},{'real','scalar','nonnan','nonempty','nonnegative'},'findpeaks','MaxPeakWidth');
else
  validateattributes(Wmax,{'numeric'},{'real','scalar','nonnan','nonempty','nonnegative'},'findpeaks','MaxPeakWidth');
end
if isInMATLAB && isduration(Pd)
  validateattributes(seconds(Pd),{'numeric'},{'real','scalar','nonempty','nonnegative'},'findpeaks','MinPeakDistance');
else
  validateattributes(Pd,{'numeric'},{'real','scalar','nonempty','nonnegative'},'findpeaks','MinPeakDistance');
end  
validateattributes(Th,{'numeric'},{'real','scalar','nonempty','nonnegative'},'findpeaks','Threshold');
validateattributes(NpOut,{'numeric'},{'real','scalar','nonempty','integer','positive'},'findpeaks','NPeaks');
Str = validatestring(Str,{'ascend','none','descend'},'findpeaks','SortStr');
Ann = validatestring(Ann,{'peaks','extents'},'findpeaks','SortStr');
Ref = validatestring(Ref,{'halfprom','halfheight'},'findpeaks','WidthReference');

%--------------------------------------------------------------------------
function [iPk,iInf,iInflect] = getAllPeaks(y)
% fetch indices all infinite peaks
iInf = find(isinf(y) & y>0);

% temporarily remove all +Inf values
yTemp = y;
yTemp(iInf) = NaN;

% determine the peaks and inflection points of the signal
[iPk,iInflect] = findLocalMaxima(yTemp);


%--------------------------------------------------------------------------
function [iPk, iInflect] = findLocalMaxima(yTemp)
% bookend Y by NaN and make index vector
yTemp = [NaN; yTemp; NaN];
iTemp = (1:length(yTemp)).';

% keep only the first of any adjacent pairs of equal values (including NaN).
yFinite = ~isnan(yTemp);
iNeq = [1; 1 + find((yTemp(1:end-1) ~= yTemp(2:end)) & ...
                    (yFinite(1:end-1) | yFinite(2:end)))];
iTemp = iTemp(iNeq);

% take the sign of the first sample derivative
s = sign(diff(yTemp(iTemp)));

% find local maxima
iMax = 1 + find(diff(s)<0);

% find all transitions from rising to falling or to NaN
iAny = 1 + find(s(1:end-1)~=s(2:end));

% index into the original index vector without the NaN bookend.
iInflect = iTemp(iAny)-1;
iPk = iTemp(iMax)-1;


%--------------------------------------------------------------------------
function [iPk,iInf,iInflect] = getAllPeaksCodegen(y)
% One-pass code generation version of getAllPeaks
coder.varsize('iPk');
coder.varsize('iInf');
coder.varsize('iInflect');
% Define constants.
ZERO = coder.internal.indexInt(0);
ONE = coder.internal.indexInt(1);
DECREASING = 'd';
INCREASING = 'i';
NEITHER = 'n';
NonFiniteSupport = coder.internal.get_eml_option('NonFinitesSupport');
% Allocate output arrays.
iPk = coder.nullcopy(zeros(size(y),'like',ONE));
iInf = coder.nullcopy(zeros(size(y),'like',ONE));
iInflect = coder.nullcopy(zeros(size(y),'like',ONE));
ny = coder.internal.indexInt(length(y));
% Counter variables to store the number of elements in each array that are
% in use.
nPk = ZERO;
nInf = ZERO;
nInflect = ZERO;
% Initial direction.
dir = NEITHER;
if NonFiniteSupport || ny == 0
    % This is the typical start. With kfirst = 0 and ykfirst = +Inf, the
    % first value is an artificial +Inf. Unless the signal begins with
    % +Infs and/or NaNs, we'll pick up the first non-NaN, non-Inf value in
    % the first iteration, replace ykfirst with it, and proceed from there.
    kfirst = ZERO; % index of first element of a series of equal values
    ykfirst = coder.internal.inf('like',y); % first element of a series of equal values
    isinfykfirst = true;
else
    % With no non-finite support, we know the first element of the signal
    % is finite, so we can start with it.
    kfirst = ONE; % index of first element of a series of equal values
    ykfirst = y(1); % first element of a series of equal values
    isinfykfirst = false;
end
for k = kfirst + 1:ny
    yk = y(k);
    if isnan(yk)
        % yk is NaN. Convert it to +Inf.
        yk = coder.internal.inf('like',yk);
        isinfyk = true;
    elseif isinf(yk) && yk > 0
        % yk is +Inf. Record its position in the iInf array.
        isinfyk = true;
        nInf = nInf + 1;
        iInf(nInf) = k;
    else
        isinfyk = false;
    end
    if yk ~= ykfirst
        previousdir = dir;
        if NonFiniteSupport && (isinfyk || isinfykfirst)
            dir = NEITHER;
            % kfirst == 0 implies that ykfirst was just the artificial
            % starting value. We don't want to add the artificial value to
            % the array of inflection points, so we only append if kfirst
            % is at least 1.
            if kfirst >= 1
                nInflect = nInflect + 1;
                iInflect(nInflect) = kfirst;
            end
        elseif yk < ykfirst
            dir = DECREASING;
            if dir ~= previousdir
                % Previously the direction was not decreasing and now it
                % is. At least record an inflection point.                
                nInflect = nInflect + 1;
                iInflect(nInflect) = kfirst;
                if previousdir == INCREASING
                    % Since the direction was previously increasing and now
                    % is decreasing, y(kfirst) is a peak.
                    nPk = nPk + 1;
                    iPk(nPk) = kfirst;
                end
            end
        else % if yk > ykfirst
            dir = INCREASING;
            if dir ~= previousdir
                % Direction was previously not increasing. Record the
                % inflection point y(kfirst).
                nInflect = nInflect + 1;
                iInflect(nInflect) = kfirst;
            end
        end
        % yk becomes the new ykfirst.
        ykfirst = yk;
        kfirst = k;
        isinfykfirst = isinfyk;
    end
end
% Add last point as inflection point if it is finite and not already there.
if ny > 0 && ~isinfykfirst && (nInflect == 0 || iInflect(nInflect) < ny)
    nInflect = nInflect + 1;
    iInflect(nInflect) = ny;
end
% Shorten the variable-size arrays down to the number of elements in use.
iPk = iPk(1:nPk,1);
iInf = iInf(1:nInf,1);
iInflect = iInflect(1:nInflect,1);

%--------------------------------------------------------------------------
function iPk = removePeaksBelowMinPeakHeight(Y,iPk,Ph,widthRef)
if ~isempty(iPk) 
  iPk = iPk(Y(iPk) > Ph);
  if isempty(iPk) && ~strcmp(widthRef,'halfheight')
    warning(message('signal:findpeaks:largeMinPeakHeight', 'MinPeakHeight', 'MinPeakHeight'));
  end
end
    
%--------------------------------------------------------------------------
function iPk = removePeaksBelowThreshold(Y,iPk,Th)
base = max(Y(iPk-1),Y(iPk+1));
iPk = iPk(Y(iPk)-base >= Th);

%--------------------------------------------------------------------------
function iPk = removeSmallPeaks(y,iFinite,minH,thresh)
% Combination of removePeaksBelowMinPeakHeight and
% removePeaksBelowThreshold for code generation
iPk = coder.nullcopy(iFinite);
nPk = coder.internal.indexInt(0);
n = coder.internal.indexInt(length(iFinite));
for k = 1:n
    j = iFinite(k);
    pk = y(j);
    if pk > minH
        base = max(y(j - 1),y(j + 1));
        if pk - base >= thresh
            nPk = nPk + 1;
            iPk(nPk) = j;
        end
    end
end
iPk = iPk(1:nPk,1);

%--------------------------------------------------------------------------
function [iPkOut,bPk,bxPk,byPk,wxPk] = combinePeaks(iPk,iInf,outputPrototype)
iPkOut = union(iPk,iInf);
bPk = zeros(0,1,"like",outputPrototype);
bxPk = zeros(0,2,"like",outputPrototype);
byPk = zeros(0,2,"like",outputPrototype);
wxPk = zeros(0,2,"like",outputPrototype);

%--------------------------------------------------------------------------
function idx = findPeaksSeparatedByMoreThanMinPeakDistance(y,x,iPk,Pd,sortDir)
% Start with the larger peaks to make sure we don't accidentally keep a
% small peak and remove a large peak in its neighborhood. 

if isempty(iPk) || Pd==0
  IONE = ones('like',getIZERO);
  idx = orderPeaks(y,iPk,(IONE:length(iPk)).',sortDir);
  return
end

% copy peak values and locations to a temporary place
pks = y(iPk);
locs_temp = x(iPk);

% Order peaks from large to small
if coder.target('MATLAB')
    [~, sortIdx] = sort(pks,'d');
else

    ZERO = coder.internal.indexInt(0);
    sortIdx = coder.nullcopy(zeros(numel(pks), 1, 'like', ZERO));
    sortIdx = coder.internal.mergesort(sortIdx,pks,'d', ...
        ZERO,coder.internal.indexInt(numel(pks)));
end

locs_temp = locs_temp(sortIdx);

idelete = zeros(size(locs_temp), 'logical');

for i = 1:length(idelete)
  if ~idelete(i)
    % If the peak is not in the neighborhood of a larger peak, find
    % secondary peaks to eliminate.

    if coder.target('MATLAB')
        % Check for equality within EPS for EPS supported classes
        if (isa(x(1), 'single') || isa(x(1), 'double'))
            idelete = idelete | ...
                (locs_temp - (locs_temp(i) - Pd) > -eps(class(x))) & ...
                (locs_temp - (locs_temp(i) + Pd) < eps(class(x)));
        else
            idelete = idelete | (locs_temp>=locs_temp(i)-Pd)&(locs_temp<=locs_temp(i)+Pd);
        end
    else
		% explicit loop for better memory profile
        for jj = length(idelete):-1:1
            idelete(jj) = idelete(jj) | (locs_temp(jj)>=locs_temp(i)-Pd)&(locs_temp(jj)<=locs_temp(i)+Pd);
        end
    end

    idelete(i) = 0; % Keep current peak
  end
end

% report back indices in consecutive order
idx = sortIdx(~idelete);

if isempty(idx)
    return
end

% re-order and bound the number of peaks based upon the index vector and
% sortDir.

if strcmp(sortDir,'none')
    if coder.target('MATLAB')
        idx = sort(idx);
    else
        idx = coder.internal.introsort(idx,coder.internal.indexInt(1), ...
            coder.internal.indexInt(length(idx)));
    end
elseif sortDir(1) == 'a'
    idx = flipud(idx);
end

%--------------------------------------------------------------------------
function idx = orderPeaks(Y,iPk,idx,Str)

if isempty(idx) || strcmp(Str,'none')
  return
end

if coder.target('MATLAB')
  [~,s]  = sort(Y(iPk(idx)),Str);
else
  ZERO = coder.internal.indexInt(0);
  s = zeros(numel(idx), 1, 'like', ZERO);  
  s = coder.internal.mergesort(s, Y(iPk(idx)), Str(1), ...
      ZERO,coder.internal.indexInt(numel(idx)));
end
idx = idx(s);

%--------------------------------------------------------------------------
function [bPk,bxPk,byPk,wxPk] = fetchPeakExtents(idx,bPk,bxPk,byPk,wxPk)


bPk = bPk(idx);
bxPk = bxPk(idx,:);
byPk = byPk(idx,:);
wxPk = wxPk(idx,:);

%--------------------------------------------------------------------------
function [YpkOut,XpkOut] = assignOutputs(y,x,iPk,yIsRow,xIsRow)
coder.internal.prefer_const(yIsRow,xIsRow);

% fetch the coordinates of the peak
Ypk = y(iPk);
Xpk = x(iPk);

% preserve orientation of Y
if yIsRow
  YpkOut = Ypk.';
else
  YpkOut = Ypk;
end

% preserve orientation of X
if xIsRow
  XpkOut = Xpk.';
else
  XpkOut = Xpk;
end

%--------------------------------------------------------------------------
function [YpkOut,XpkOut,WpkOut,PpkOut] = assignFullOutputs(y,x,iPk,wxPk,bPk,yIsRow,xIsRow,idx,maxN)
coder.internal.prefer_const(yIsRow,xIsRow);

% fetch the coordinates of the peak
Ypk = y(iPk);
Xpk = x(iPk);

% compute the width and prominence

Wpk = diff(wxPk(idx(1:maxN),:),1,2);

Ppk = Ypk - bPk(idx(1:maxN));

% preserve orientation of Y (and P)
if yIsRow
  YpkOut = Ypk.';
  PpkOut = Ppk.';
else
  YpkOut = Ypk;
  PpkOut = Ppk;  
end

% preserve orientation of X (and W)
if xIsRow
  XpkOut = Xpk.';
  WpkOut = Wpk.';
else
  XpkOut = Xpk;
  WpkOut = Wpk;  
end

%--------------------------------------------------------------------------
function y = getIZERO
% Return zero of the indexing type: double 0 in MATLAB,
% coder.internal.indexInt(0) for code generation targets.
if coder.target('MATLAB')
    y = 0;
else
    y = coder.internal.indexInt(0);
end

% [EOF]