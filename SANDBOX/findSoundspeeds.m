function findSoundspeeds

% This script attempts to calculate the transversal and longitudinal
% soundspeeds of a calibration sphere. The user must input the location of
% the nulls, then it will minimize a function so that the estimated nulls
% are closest.

% Define sphere parameters
diameter = 38.1;            % Sphere diameter in mmeimate t
sphereDensity = 14441.44;   % Density of the sphere in kg/m^3
waterDensity = 1025;        % Density of the surrounding water in kg/m^3
f = linspace(160e3, 260e3, 1000);       	% Frequency vector in Hz
c = 1521;                   % Water sound speed in m/s

% Define threshold for finding nulls
thresh = 50;
% nulls = [135.5 174.2 210.0 245.0].*1e3;   % For 38.1
nulls = [171 206 240].*1e3;     % For 33.2

% null1 = 115.8e3;
% null2 = 135.5e3;

% Minimize TS error function
options = optimset('Display', 'iter', 'FunValCheck', 'off', 'TolFun', 1e-8, 'TolX', 1e-8);
% options = optimoptions('fmincon');
% options = optimoptions(options, 'FunValCheck', 'off', 'Display', 'iter', 'TolCon', 1e-20, 'TolFun', 1e-20);
X0 = [6000 4000 14900];
% X0 = [6800 4100];
LB = [6600 4000];
UB = [7200 4400];
X = fminsearch(@(x) sphere_TS(x, diameter, waterDensity, ...
    f, c, thresh, nulls), X0, options);
% X = fminsearch(@(x) sphere_TS(x, diameter, sphereDensity, waterDensity, ...
%     f, c, thresh, nulls), X0, options);

% X = fmincon(@(x) sphere_TS(x, diameter, sphereDensity, waterDensity, ...
%     f, c, thresh, nulls), X0, [], [], [], [], LB, UB, [], options);

% Display results
fprintf('Longitudinal sound speed = %.2f m/s\n', X(1));
fprintf('Transversal sound speed = %.2f m/s\n', X(2));
fprintf('Sphere density = %.2f kg/m^3\n', X(3));

% Get TS using new results
[error, f, TS] = sphere_TS(X, diameter, waterDensity, ...
    f, c, thresh, nulls);

% Plot TS
figure; plot(f/1e3, TS); hold on

% Plot nulls
ylims = get(gca, 'YLim');
for i = 1:length(nulls)
    plot([nulls(i) nulls(i)]/1e3, ylims, 'r');
end


function [error, f, TS] = sphere_TS(x, d, rho, f, c, thresh, nulls)
% function [error, f, TS] = sphere_TS(x, d, rho1, rho, f, c, thresh, nulls)
% This is a parameterized function for minimization. The input variables
% are:
%   x(1) = Longitudinal sound speed (m/s)
%   x(2) = Transversal sound speed (m/s)
%   d = Sphere diameter (mm)
%   rho1 = Sphere density (kg/m^3)
%   rho = Water density (kg/m^3)
%   f = Frequency range (Hz)
%   c = Water sound speed (m/s)

c1 = x(1);
c2 = x(2);
rho1 = x(3);

a = 1e-3*d/2;               % Calculate sphere radius

% Cycle through sound speeds
TS = nan(length(c), length(f));         % Initialize TS variable
h = waitbar(0, 'Processing...');        % Create waitbar
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
        
        % If nu for every frequency is NaN, then stop summation
        if isequal(sum(idx),0)
            flag = 1;                   % Set flag to 1 to exit while loop
        end
        
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
    
    waitbar(i/length(c), h)                 % update waitbar
    
    % Clear variables defined in next sound speed loop iteration
    clear sigma f_inf l flag buff q2 q1 q k
end
close(h)                                    % clear waitbar

% Invert TS for finding nulls
invTS = -1.*TS;

% Find peaks above some threshold
[PKS, LOCS]= findpeaks(invTS, f, 'MinPeakHeight', thresh);

% If number of peaks doesn't match up with number of nulls, return NaNs
if length(LOCS) ~= length(nulls)
    error = NaN;
else

    % Calculate error by taking sum of squares
    error = sum((LOCS - nulls).^2);
end


function answer = j(n,x)
% Spherical bessel function of the first order

answer = besselj(n+.5, x) .* sqrt(pi./(2*x));

function answer = y(n,x)
% Spherical bessel function of the second order

answer = bessely(n+.5, x) .* sqrt(pi./(2*x));

function answer = j1(n,x)
% First derivative of spherical bessel function of the first order

answer = (j(n-1,x) - j(n+1,x))./2 - j(n,x)./(2.*x);

function answer = j2(n,x)
% Second derivative of spherical bessel function of the first order

answer = (x.^2.*j(n-2,x) - 2.*x.^2.*j(n,x) + x.^2.*j(n+2,x) - ...
    2.*x.*j(n-1,x) + 2.*x.*j(n+1,x) + 3.*j(n,x)) ./ (4.*x.^2);

function answer = y1(n,x)
% First derivative of spherical bessel function of the second order

answer = (y(n-1,x) - y(n+1,x))./2 - y(n,x)./(2.*x);