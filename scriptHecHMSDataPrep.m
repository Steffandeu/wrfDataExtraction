% A script for preparing HEC-MSC grid from wrfout file.
%
% Author: Jamal Uddin Khan
% Created: 16/04/2016

% Constrants
TRMMGRID = 0.25;

% Loading file
[inFileName, inFileLoc] =  ReadFile('Select the nc file', '*.nc');

% lat lon and meshes
[lon, lat, meshLon, meshLat] = GetLatLonGrid(inFileLoc);

fprintf('Model domain is bounded by %f to %f longitude.\n', min(lon), max(lon));
fprintf('\t\t\tAnd %f to %f in latitude.\n', min(lat), max(lat));

% time and time steps
[times, nTimeStep, minuteElapsed] = GetTimes(inFileLoc);

% Outfile
outFileName = [inFileName, '.csv'];

% TRMM Grid
% From TRMM nc file
trmmLon = 0.1250 : TRMMGRID : 359.8750;
trmmLat = -49.8750 : TRMMGRID : 49.8750;

% lat-lon range of interest
lonW = input('Enter longitude of the west end in degree east : ');
lonE = input('Enter longitude of the east end in degree east : ');

latS = input('Enter latitude of the south end in degree north : ');
latN = input('Enter latitude of the north end in degree north : ');

% create listing for lat-lon of interest
% First finding the nearest value on the grid.
[latS, ~] = FindClosest(trmmLat, latS);
[latN, ~] = FindClosest(trmmLat, latN);
[lonW, ~] = FindClosest(trmmLon, lonW);
[lonE, ~] = FindClosest(trmmLon, lonE);

% lat lon of interst
lonOut = lonW : TRMMGRID : lonE; % x
latOut = latS : TRMMGRID : latN; % y
[meshLonOut, meshLatOut] = meshgrid(lonOut, latOut);

% Creating output format
outPosition = zeros(2, length(lonOut)*length(latOut));
for i = 1 : length(latOut)
    outPosition(1, (i-1)*length(lonOut) + 1 : i * length(lonOut)) = ones(1, length(lonOut))*latOut(i);
    outPosition(2, (i-1)*length(lonOut) + 1 : i * length(lonOut)) = lonOut;
end

% Create headers
headers = num2cell(outPosition);
headers = [{'Latitude';'Longitude'} headers];
[row, col] = size(headers);

% Creating format specifier
dayString = {'%s,'};
numForm = {'%f,'};
endElem = {'%f\n'};
stringFormat = [dayString repelem(numForm, length(outPosition)-1) endElem];
stringFormat = cell2mat(stringFormat);

% opening file for writing header in write mode
fid = fopen(outFileName, 'w');
% now writing header line by line using fprintf
for i = 1 : row
    fprintf(fid, stringFormat, headers{i, :});
end
fclose(fid);

% opening file for writing data values
% this file will be closed at the end
fid = fopen(outFileName, 'a');

% Now iterate over the time steps
% Reading the precipitation on the specific time step
for timeStep = 1 : nTimeStep
    if timeStep == 1
        [precip, ncRain, cRain] = GetAccuPrecip(inFileLoc, timeStep);
    else
        [precip2, ncRain2, cRain2] = GetAccuPrecip(inFileLoc, timeStep); 
        [precip1, ncRain1, cRain1] = GetAccuPrecip(inFileLoc, timeStep - 1);
        precip = precip2 - precip1;
        ncRain = ncRain2 - ncRain1;
        cRain = cRain2 - cRain1;
    end
    
    outChunk = cell(1, length(outPosition) + 1);
    outChunk{1} = datestr(times{timeStep}, 'yyyy-mm-dd HH:MM:SS');
    
    % Interpolation of data
    precipInterp = griddata(double(meshLon), double(meshLat), double(precip), meshLonOut', meshLatOut');
    
    
    % Reading precipitation only
    for i = 1 : length(outPosition)
        % position is in latitude, longitude format in i th column
        outChunk{1, i + 1} = precipInterp(find(lonOut == outPosition(2, i)), find(latOut == outPosition(1, i)));
    end
    
    % Writing data to file
    fprintf(fid, stringFormat, outChunk{1, :});
    msg = ['Timestep ', num2str(timeStep), ' of ', num2str(nTimeStep), ' - Completed.'];
    disp(msg);
end

% Completion message
disp('Completed!');


% Closing all file
fclose('all');

