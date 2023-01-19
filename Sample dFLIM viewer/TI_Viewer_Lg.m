function varargout = TI_Viewer_Lg(varargin)
% TI_VIEWER_LG MATLAB code for TI_Viewer_Lg.fig
%      TI_VIEWER_LG, by itself, creates a new TI_VIEWER_LG or raises the existing
%      singleton*.
%
%      H = TI_VIEWER_LG returns the handle to a new TI_VIEWER_LG or the handle to
%      the existing singleton*.
%
%      TI_VIEWER_LG('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in TI_VIEWER_LG.M with the given input arguments.
%
%      TI_VIEWER_LG('Property','Value',...) creates a new TI_VIEWER_LG or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before TI_Viewer_Lg_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to TI_Viewer_Lg_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help TI_Viewer_Lg

% Last Modified by GUIDE v2.5 12-Nov-2019 10:10:15

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @TI_Viewer_Lg_OpeningFcn, ...
                   'gui_OutputFcn',  @TI_Viewer_Lg_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before TI_Viewer_Lg is made visible.
function TI_Viewer_Lg_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to TI_Viewer_Lg (see VARARGIN)

% Choose default command line output for TI_Viewer_Lg
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

jSlider = com.jidesoft.swing.RangeSlider(40,400,110,200);
% X,Y = X(axes5)-5, Y(axes5)-50
jSlider = javacomponent(jSlider,[811,27,330,20]);

handles.jSlider    = jSlider;
set(jSlider,'MouseReleasedCallback',@jSlider_Callback);
jSlider.setLowValue(100*str2double(handles.eLT_lo.String));
jSlider.setHighValue(100*str2double(handles.eLT_hi.String));

global TI_Viewer_app
evalin('base','global TI_Viewer_app');
TI_Viewer_app = TI_Viewer_Class(handles);

colormap(handles.figure1,gray(256));
cmap = zeros(256,1,3); cmap(:,1,:)=dFLIM_Image.Colormap;
image(handles.axesCB,cmap);
set(handles.axesCB,'YDir','normal','YTick',256*(0.2:0.2:0.8),'XTick',[], ...
    'YTickLabel','');
setCBScale;
colormap(handles.axes1,gray(256));




% UIWAIT makes TI_Viewer_Lg wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = TI_Viewer_Lg_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;



function eImageNumber_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
function eChannel_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
function eLT_hi_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
function eLT_lo_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
function eLUT_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
function eLUT_LT_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
function eTPeak_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function eImageNumber_Callback(hObject, eventdata, handles)
global TI_Viewer_app
if ~TI_Viewer_app.tiExpt.info.streaming
    handles.lbFiles.Value = str2double(handles.eImageNumber.String);
end
showImages;

function showImages
global TI_Viewer_app
handles = TI_Viewer_app.handles;
imgNum  = str2double(handles.eImageNumber.String);
ch      = selectedChannel; % str2double(handles.eChannel.String);
hAxes   = [handles.axes1 handles.axes2 handles.axes4];
TI_Viewer_app.showImage(imgNum,ch,hAxes);

% channel change requires new file reading
function eChannel_Callback(hObject, eventdata, handles)
global TI_Viewer_app
TI_Viewer_app.readImages(handles.cbLoadXYT.Value); 
eImageNumber_Callback([],[],handles);

% most callbacks invoke redisplay, not re-read
function eLT_hi_Callback(hObject, eventdata, handles)
global TI_Viewer_app
jSlider = TI_Viewer_app.handles.jSlider;
jSlider.setHighValue(100*str2double(hObject.String));
setCBScale;
showImages;

function eLT_lo_Callback(hObject, eventdata, handles)
global TI_Viewer_app
jSlider = TI_Viewer_app.handles.jSlider;
jSlider.setLowValue(100*str2double(hObject.String));
setCBScale;
showImages;

function eLUT_Callback(hObject, eventdata, handles)
showImages;

function eLUT_LT_Callback(hObject, eventdata, handles)
showImages;
         
function pbDC_Callback(hObject, eventdata, handles)
datacursormode toggle

function pbDecrImageN_Callback(hObject, eventdata, handles)
currImageN = str2double(handles.eImageNumber.String);
if currImageN >1
    handles.eImageNumber.String = num2str(currImageN-1);
    eImageNumber_Callback([],[],handles);
else
    handles.tMessages.String = 'Can''t decrement image number below 1';
end

function pbIncrImageN_Callback(hObject, eventdata, handles)
currImageN = str2double(handles.eImageNumber.String);
global TI_Viewer_app
if currImageN < size(TI_Viewer_app.dfi,2)
    handles.eImageNumber.String = num2str(currImageN+1);
    eImageNumber_Callback([],[],handles);
else
    handles.tMessages.String = 'Can''t increment image number further';
end

% --- Executes on button press in cbFixTPeak.
function cbFixTPeak_Callback(hObject, eventdata, handles)
if hObject.Value
    eImageNumber_Callback([],[],handles);
end

function eTPeak_Callback(hObject, eventdata, handles)
if handles.cbFixTPeak.Value
    eImageNumber_Callback([],[],handles);
end


% --- Executes on selection change in lbFolders.
function lbFolders_Callback(hObject, eventdata, handles)
global TI_Viewer_app
TI_Viewer_app.newFolderSelection;
if isfield(handles,'cbLoadXYT')
    TI_Viewer_app.readImages(handles.cbLoadXYT.Value); 
else
    TI_Viewer_app.readImages(false);
end
eImageNumber_Callback([], [], handles);

function lbFolders_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function lbFiles_Callback(hObject, eventdata, handles)
global TI_Viewer_app
if ~TI_Viewer_app.tiExpt.info.streaming
    handles.eImageNumber.String = num2str(hObject.Value);
    eImageNumber_Callback([], [], handles);
end

function lbFiles_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function pbChooseDir_Callback(hObject, eventdata, handles)
global TI_Viewer_app 
TI_Viewer_app.chooseTopDirectory(eventdata);

function uibgChannel_SelectionChangedFcn(hObject, eventdata, handles)
eImageNumber_Callback([],[],handles);

function ch = selectedChannel
global TI_Viewer_app 
sel = TI_Viewer_app.handles.uibgChannel.SelectedObject;
chans = 'ABCD';
ch = find(chans==sel.String);

function jSlider_Callback(obj,chg)
global TI_Viewer_app
lims = [obj.getLowValue obj.getHighValue]/100;
hh = TI_Viewer_app.handles;
hh.eLT_lo.String = num2str(lims(1));
hh.eLT_hi.String = num2str(lims(2));
setCBScale;
showImages;

function setCBScale
global TI_Viewer_app
hh = TI_Viewer_app.handles;
lims = [str2double(hh.eLT_lo.String) str2double(hh.eLT_hi.String)];
yyaxis(hh.axesCB,'right');
ax = axis(hh.axesCB);
ax(3:4) = lims;
axesCB.YTickLabelMode = 'auto';
axesCB.YTickMode = 'auto';
axis(hh.axesCB,ax);
yyaxis(hh.axesCB,'left');
set(hh.axesCB,'YTick',[],'XTick',[]);

function cbSkipLTHistoUpdate_Callback(hObject, eventdata, handles)
if hObject.Value==0, showImages; end

function pmBinning_Callback(hObject, eventdata, handles)
showImages;

function pmBinning_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function tbZoom_Callback(hObject, eventdata, handles)
ax = [handles.axes1 handles.axes2];
linkaxes(ax);
% axis(ax,'square');
% set(ax,'DataAspectRatioMode','manual');
if hObject.Value
    zoom on
else
    zoom out
    zoom off
end
