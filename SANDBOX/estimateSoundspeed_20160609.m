function varargout = estimateSoundspeed_20160609(varargin)
% ESTIMATESOUNDSPEED Estimate sound speeds of calibration sphere
%   This GUI is to be used for estimating the longitudinal and transversal
%   sounds speeds of a calibration sphere. Typically these sound speeds are
%   set for nominal values depending on the sphere type, but slight changes
%   in sound speed can potentially lead to large changes in calibration
%   results, particularly around nulls in the TS spectra.
%
%   This program will either accept an input of pre-obtained TS(f) data, or
%   can subscribe to TS(f) from an EK80. The measured TS(f) will then be
%   fit with a theoretical TS curve, using least-squares regression to
%   solve for the optimal values of sound speeds. If available, preferably
%   the sphere density can also be provided, however if it is excluded then
%   the program can also estimate the sphere density.
%
%   The theory behind this method is somewhat cyclical: measured TS is used
%   to fit theoretical TS so that measured TS is more accurate. Therefore,
%   if the measured TS is substantially "wrong" (e.g. G(f) values are
%   inaccurate), the curve fit may be jeapordized. The crux of the curve
%   fit is to fit nulls in the TS spectra, which are mainly affected by the
%   sphere sound speeds, however inaccurate G(f) will affect the magnitude
%   of the TS curve. Therefore, it is recommended that measured TS(f) data
%   is obtained on-axis (so that angular compensation can be ignored) and
%   with no frequency-dependent gain applied.

% Edit the above text to modify the response to help estimateSoundspeed_20160609

% Last Modified by GUIDE v2.5 09-Jun-2016 11:34:30

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @estimateSoundspeed_20160609_OpeningFcn, ...
                   'gui_OutputFcn',  @estimateSoundspeed_20160609_OutputFcn, ...
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


% --- Executes just before estimateSoundspeed_20160609 is made visible.
function estimateSoundspeed_20160609_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to estimateSoundspeed_20160609 (see VARARGIN)

% Choose default command line output for estimateSoundspeed_20160609
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes estimateSoundspeed_20160609 wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = estimateSoundspeed_20160609_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on button press in loadTS.
function loadTS_Callback(hObject, eventdata, handles)
% hObject    handle to loadTS (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Prompt user to select .mat file
[filename, pathname] = uigetfile('*.mat', 'Pick TS data file');

% If a file was selected
if ~isequal(filename, 0)
    
    % Load data
    handles.data = load(fullfile(pathname, filename));
    
    % Check that frequency and TS vectors exist
    if ~isfield(handles.data, 'frequency') || ~isfield(handles.data, 'TS')
        errordlg('Data file must contain vectors ''frequency'' and ''TS''', ...
            'Incorrect data');
        
    % Otherwise, if they exist, plot the data
    else
        
        % Clear current plots
        cla(handles.axesTS);
        
        % Make frequency and TS row vectors
        if size(handles.data.frequency, 2) == 1
            handles.data.frequency = handles.data.frequency';
        end
        if size(handles.data.TS, 2) == 1
            handles.data.TS = handles.data.TS';
        end
        
        handles.h(1) = plot(handles.axesTS, handles.data.frequency/1e3, ...
            handles.data.TS);
        hold(handles.axesTS, 'on')
        handles.axesTS.XMinorGrid = 'on';
        handles.axesTS.YMinorGrid = 'on';
        xlabel(handles.axesTS, 'Frequency (kHz)')
        ylabel(handles.axesTS, 'Standardized TS (dB)')
        
        % Add a second empty plot for plotting TS estimates
        handles.h(2) = plot(handles.axesTS, handles.data.frequency/1e3, ...
            nan(size(handles.data.TS)), 'r');
    end
end

guidata(handles.output, handles)


% --- Executes on button press in startEstimate.
function startEstimate_Callback(hObject, eventdata, handles)
% hObject    handle to startEstimate (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% If button is pressed
if get(hObject, 'Value')
    
%     profile on

    % First verify that there is data to process
    if ~isfield(handles, 'data')
        errordlg('There is no TS data to process', 'No data available')
        return
    end
    
    % Change start button
    set(hObject, 'String', 'Estimating...', 'BackgroundColor', 'r');
    drawnow nocallbacks

    % Get data from GUI
    handles.d = str2double(get(handles.sphereDiameter, 'String'));
    handles.rho1 = str2double(get(handles.sphereDensity, 'String'));
    handles.rho = str2double(get(handles.waterDensity, 'String'));
    handles.c = str2double(get(handles.waterSoundSpeed, 'String'));

    % Set options for minimization
    options = optimset('fminsearch');
    options.Display = 'iter';
    options.OutputFcn = @(x,o,s,y)plotProgress(x,o,s,handles);

    % Define starting points based on sphere type
    switch get(handles.sphereType, 'Value')
        case 1  % WC
            X0 = [6853 4171];
%             X0 = [7000 3900];
        case 2  % Cu
            X0 = [4760 2289];
    end

    % Begin minimization
    X = fminsearch(@(x) minFun(x, handles), X0, options);
    
%     % Use nlinfit to find sound speeds
%     options = statset('nlinfit');
%     options.Display = 'iter';
% %     options.OutputFcn = @(x,o,s,y)plotProgress(x,o,s,handles);
%     Xmat = [handles.data.frequency' ...
%         repmat(handles.d, length(handles.data.frequency), 1) ...
%         repmat(handles.rho1, length(handles.data.frequency), 1) ...
%         repmat(handles.rho, length(handles.data.frequency), 1) ...
%         repmat(handles.c, length(handles.data.frequency), 1)];
%     X = nlinfit(Xmat, handles.data.TS, @sphere_TS_nlinfit, X0, options);

    % Calculate TS using best estimates of sound speeds
    TS = sphere_TS(X(1), X(2), handles.d, handles.rho1, ...
        handles.rho, handles.data.frequency, handles.c);
    
%     % Compute z-score
%     TS = (TS - mean(TS)) / std(TS);
    
    set(hObject, 'Value', 0, 'String', 'Estimate', 'BackgroundColor', 'g')
    set(handles.h(2), 'YData', TS)
    set(handles.c1Result, 'String', X(1))
    set(handles.c2Result, 'String', X(2))
    drawnow
    
%     profile viewer
end


function rms = minFun(x, handles)
% Function to be minimized for finding the sphere sound speeds

% Calculate TS using latest values of sphere sound speeds
c1 = x(1);
c2 = x(2);
TS = sphere_TS(c1, c2, handles.d, handles.rho1, handles.rho, ...
    handles.data.frequency, handles.c);

% [PKS,LOCS] = findpeaks(-handles.data.TS, handles.data.frequency, ...
%     'MinPeakProminence', 10, 'MinPeakDistance', 5e3);
% [PKS2,LOCS2] = findpeaks(-TS, handles.data.frequency, ...
%     'MinPeakProminence', 10, 'MinPeakDistance', 5e3);

% % Compute z-score
% TS = (TS - mean(TS)) / std(TS);

% Calculate error
rms = sqrt(mean((handles.data.TS - TS).^2));
% rms = sqrt(mean((LOCS - LOCS2).^2));


% --- Executes on selection change in sphereType.
function sphereType_Callback(hObject, eventdata, handles)
% hObject    handle to sphereType (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns sphereType contents as cell array
%        contents{get(hObject,'Value')} returns selected item from sphereType


% --- Executes during object creation, after setting all properties.
function sphereType_CreateFcn(hObject, eventdata, handles)
% hObject    handle to sphereType (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function sphereDiameter_Callback(hObject, eventdata, handles)
% hObject    handle to sphereDiameter (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of sphereDiameter as text
%        str2double(get(hObject,'String')) returns contents of sphereDiameter as a double


% --- Executes during object creation, after setting all properties.
function sphereDiameter_CreateFcn(hObject, eventdata, handles)
% hObject    handle to sphereDiameter (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function sphereDensity_Callback(hObject, eventdata, handles)
% hObject    handle to sphereDensity (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of sphereDensity as text
%        str2double(get(hObject,'String')) returns contents of sphereDensity as a double


% --- Executes during object creation, after setting all properties.
function sphereDensity_CreateFcn(hObject, eventdata, handles)
% hObject    handle to sphereDensity (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function waterDensity_Callback(hObject, eventdata, handles)
% hObject    handle to waterDensity (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of waterDensity as text
%        str2double(get(hObject,'String')) returns contents of waterDensity as a double


% --- Executes during object creation, after setting all properties.
function waterDensity_CreateFcn(hObject, eventdata, handles)
% hObject    handle to waterDensity (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function waterSoundSpeed_Callback(hObject, eventdata, handles)
% hObject    handle to waterSoundSpeed (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of waterSoundSpeed as text
%        str2double(get(hObject,'String')) returns contents of waterSoundSpeed as a double


% --- Executes during object creation, after setting all properties.
function waterSoundSpeed_CreateFcn(hObject, eventdata, handles)
% hObject    handle to waterSoundSpeed (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function TS = sphere_TS(c1, c2, d, rho1, rho, f, c)
% This is a parameterized function for minimization. The input variables
% are:
%   x(1) = Longitudinal sound speed (m/s)
%   x(2) = Transversal sound speed (m/s)
%   d = Sphere diameter (mm)
%   rho1 = Sphere density (kg/m^3)
%   rho = Water density (kg/m^3)
%   f = Frequency range (Hz)
%   c = Water sound speed (m/s)

% % Ensure that f is a row vector
% if size(f,2) == 1
%     f = f';
% end

a = 1e-3*d/2;               % Calculate sphere radius

% Cycle through sound speeds
TS = nan(length(c), length(f));         % Initialize TS variable
for i = 1:length(c)
    
    % Calculate variables that don't change with l
    k = 2*pi*f/c(i);                            % Wavenumber
    q = k*a;                                    % Circumference/wavelength
    q1 = q * c(i) / c1;                         % Relative long. c
    q2 = q * c(i) / c2;                         % Relative trans. c
    alpha = 2 .* rho1./rho .* (c2./c(i)).^2;    % Used in beta and B2 calc
    beta = rho1./rho .* (c1./c(i)).^2 - alpha;  % used in B2 calc
    
    % Cycle through l's
    buff = zeros(1,length(q));          % Create summation variable
    flag = 0;                           % Flag for exiting while loop
    l = 0;                              % Initialize l variable
    
    % Perform summation in equation 7 until the results for every frequency
    % result in NaN.
    while flag == 0
        
        % Compute variables in equations 6a to 6h
        A1 = 2.*l.*(l+1) .* (q1 .* j1(l,q1) - j(l,q1));        
        A2 = (l.^2 + l - 2) .* j(l,q2) + q2.^2 .* j2(l,q2);
        B1 = q .* (A2.*q1.*j1(l,q1) - A1.*j(l,q2));
        B2 = A2.*q1.^2 .* (beta.*j(l,q1) - alpha.*j2(l,q1)) - ...
            A1.*alpha .* (j(l,q2) - q2.*j1(l,q2));
        nu = atan(-(B2.*j1(l,q) - B1.*j(l,q)) ./ ...
            (B2.*y1(l,q) - B1.*y(l,q)));
                
        % Find frequency indices which have a nu value that is not a NaN
        idx = ~isnan(nu);
        
        % Calculate the changes to each element in the buffer array
        change = (-1).^l .* (2.*l+1) .* sin(nu(idx)) .* exp(1i.*nu(idx));
        
        % If the max change is less than eps, break out of loop
        if max(abs(change)) < eps
            break
        end            

%         % If nu for every frequency is NaN, then stop summation
%         if isequal(sum(idx),0)
%             break%flag = 1;                   % Set flag to 1 to exit while loop
%         end
        
        % Perform summation from equation 7.  This will only perform the
        % summation for frequencies which continue to have nu values that
        % are real, and not a NaN.
        buff(idx) = buff(idx) + (-1).^l .* (2.*l+1) .* sin(nu(idx)) .* ...
            exp(1i.*nu(idx));
        
        l = l + 1;                      % Increment l by 1
        
        % Clear variables defined in next loop iteration
        clear idx nu P B2 B1 A2 A1
    end
    
    f_inf = -2./q .* buff;                  % Calculate Equation 7
    sigma = pi .* a.^2 .* abs(f_inf).^2;    % Calculate Equation 8
    TS(i,:) = 10*log10(sigma./(4*pi));      % Calculate TS (Equation 9)
        
    % Clear variables defined in next sound speed loop iteration
    clear sigma f_inf l flag buff q2 q1 q k
end

function TS = sphere_TS_nlinfit(BETA, X)
% Function to calculate the sphere TS using estimates of the sphere
% longitudinal and transverse sound speeds. To be used with nlinfit, which
% will define the known parameters in X and try to estimate the sound speed
% coefficients in BETA. They are defined as:
%
%   X(:,1) = Frequency (Hz)
%   X(:,2) = Sphere diameter (mm)
%   X(:,3) = Sphere density (kg/m^3)
%   X(:,4) = Water density (kg/m^3)
%   X(:,5) = Water sound speed (m/s)
%
%   BETA(1) = Longitudinal sound speed (m/s)
%   BETA(2) = Transversal sound speed (m/s)

f = X(:,1)';
d = X(1,2);
rho1 = X(1,3);
rho = X(1,4);
c = X(1,5);
c1 = BETA(1);
c2 = BETA(2);

a = 1e-3*d/2;               % Calculate sphere radius

% Cycle through sound speeds
TS = nan(length(c), length(f));         % Initialize TS variable
for i = 1:length(c)
    
    % Calculate variables that don't change with l
    k = 2*pi*f/c(i);                            % Wavenumber
    q = k*a;                                    % Circumference/wavelength
    q1 = q * c(i) / c1;                         % Relative long. c
    q2 = q * c(i) / c2;                         % Relative trans. c
    alpha = 2 .* rho1./rho .* (c2./c(i)).^2;    % Used in beta and B2 calc
    beta = rho1./rho .* (c1./c(i)).^2 - alpha;  % used in B2 calc
    
    % Cycle through l's
    buff = zeros(1,length(q));          % Create summation variable
    flag = 0;                           % Flag for exiting while loop
    l = 0;                              % Initialize l variable
    
    % Perform summation in equation 7 until the results for every frequency
    % result in NaN.
    while flag == 0
        
        % Compute variables in equations 6a to 6h
        A1 = 2.*l.*(l+1) .* (q1 .* j1(l,q1) - j(l,q1));        
        A2 = (l.^2 + l - 2) .* j(l,q2) + q2.^2 .* j2(l,q2);
        B1 = q .* (A2.*q1.*j1(l,q1) - A1.*j(l,q2));
        B2 = A2.*q1.^2 .* (beta.*j(l,q1) - alpha.*j2(l,q1)) - ...
            A1.*alpha .* (j(l,q2) - q2.*j1(l,q2));
        nu = atan(-(B2.*j1(l,q) - B1.*j(l,q)) ./ ...
            (B2.*y1(l,q) - B1.*y(l,q)));
                
        % Find frequency indices which have a nu value that is not a NaN
        idx = ~isnan(nu);
        
        % Calculate the changes to each element in the buffer array
        change = (-1).^l .* (2.*l+1) .* sin(nu(idx)) .* exp(1i.*nu(idx));
        
        % If the max change is less than eps, break out of loop
        if max(abs(change)) < eps
            break
        end            

%         % If nu for every frequency is NaN, then stop summation
%         if isequal(sum(idx),0)
%             break%flag = 1;                   % Set flag to 1 to exit while loop
%         end
        
        % Perform summation from equation 7.  This will only perform the
        % summation for frequencies which continue to have nu values that
        % are real, and not a NaN.
        buff(idx) = buff(idx) + (-1).^l .* (2.*l+1) .* sin(nu(idx)) .* ...
            exp(1i.*nu(idx));
        
        l = l + 1;                      % Increment l by 1
        
        % Clear variables defined in next loop iteration
        clear idx nu P B2 B1 A2 A1
    end
    
    f_inf = -2./q .* buff;                  % Calculate Equation 7
    sigma = pi .* a.^2 .* abs(f_inf).^2;    % Calculate Equation 8
    TS(i,:) = 10*log10(sigma./(4*pi));      % Calculate TS (Equation 9)
        
    % Clear variables defined in next sound speed loop iteration
    clear sigma f_inf l flag buff q2 q1 q k
end


function answer = j(n,x)
% Spherical bessel function of the first order

answer = besselj(n+.5, x) .* sqrt(pi./(2*x));


function answer = j1(n,x)
% First derivative of spherical bessel function of the first order

answer = (j(n-1,x) - j(n+1,x))./2 - j(n,x)./(2.*x);


function answer = j2(n,x)
% Second derivative of spherical bessel function of the first order

answer = (x.^2.*j(n-2,x) - 2.*x.^2.*j(n,x) + x.^2.*j(n+2,x) - ...
    2.*x.*j(n-1,x) + 2.*x.*j(n+1,x) + 3.*j(n,x)) ./ (4.*x.^2);


function answer = y(n,x)
% Spherical bessel function of the second order

answer = bessely(n+.5, x) .* sqrt(pi./(2*x));


function answer = y1(n,x)
% First derivative of spherical bessel function of the second order

answer = (y(n-1,x) - y(n+1,x))./2 - y(n,x)./(2.*x);


function stop = plotProgress(x, optimValues, state, handles)

if get(handles.startEstimate, 'Value')
    stop = false;
else
    stop = true;
end

% Calculate TS using sound speed values
if strcmp(state, 'iter')
    TS = sphere_TS(x(1), x(2), handles.d, handles.rho1, ...
        handles.rho, handles.data.frequency, handles.c);
    
%     % Compute z-score
%     TS = (TS - mean(TS)) / std(TS);

    set(handles.h(2), 'YData', TS)
    set(handles.c1Result, 'String', x(1))
    set(handles.c2Result, 'String', x(2))
    drawnow
end


function c1Result_Callback(hObject, eventdata, handles)
% hObject    handle to c1Result (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of c1Result as text
%        str2double(get(hObject,'String')) returns contents of c1Result as a double


% --- Executes during object creation, after setting all properties.
function c1Result_CreateFcn(hObject, eventdata, handles)
% hObject    handle to c1Result (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function c2Result_Callback(hObject, eventdata, handles)
% hObject    handle to c2Result (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of c2Result as text
%        str2double(get(hObject,'String')) returns contents of c2Result as a double


% --- Executes during object creation, after setting all properties.
function c2Result_CreateFcn(hObject, eventdata, handles)
% hObject    handle to c2Result (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function magAdjust_Callback(hObject, eventdata, handles)
% hObject    handle to magAdjust (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of magAdjust as text
%        str2double(get(hObject,'String')) returns contents of magAdjust as a double


% --- Executes during object creation, after setting all properties.
function magAdjust_CreateFcn(hObject, eventdata, handles)
% hObject    handle to magAdjust (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
