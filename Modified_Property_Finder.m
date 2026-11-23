function results = Modified_Property_Finder(fluidChoice, T_cond, T_evap)
% MODIFIED_PROPERTY_FINDER
% Finds thermodynamic properties for one working fluid.
%
% Fluid choices:
% 1 = Ammonia
% 2 = Acetone

% Select the working fluid and corresponding Excel file
switch fluidChoice

    case 1
        fluidName = 'Ammonia';
        fileName = 'Ammonia_Property_Table.xlsx';

    case 2
        fluidName = 'Acetone';
        fileName = 'Acetone_Property_Table.xlsx';

    otherwise
        error('Invalid fluid selection. Choose 1 or 2.');

end

% Locate Excel file
folder = fileparts(mfilename('fullpath'));
fullName = fullfile(folder, fileName);

if ~isfile(fullName)
    error('Missing property table: %s', fileName);
end

% Read the selected Excel table
data = readtable(fullName);

% Required columns:
% 1 = Temperature
% 2 = Pressure
% 3 = Saturated liquid density
% 5 = hf
% 6 = hg
% 8 = sf
% 9 = sg

columns = [2, 3, 5, 6, 8, 9];

if width(data) < max(columns)
    error('Property table must contain at least 9 columns.');
end

T_values = data{:,1};
propertyValues = data{:,columns};

if ~isnumeric(T_values) || ~isnumeric(propertyValues)
    error('Temperature and property columns must be numeric.');
end

% Remove incomplete rows
validRows = isfinite(T_values) & ...
    all(isfinite(propertyValues),2);

T_values = T_values(validRows);
propertyValues = propertyValues(validRows,:);

% Sort temperatures
[T_values, order] = sort(T_values);
propertyValues = propertyValues(order,:);

% Remove duplicate temperatures
[T_values, uniqueRows] = unique(T_values,'stable');
propertyValues = propertyValues(uniqueRows,:);

if numel(T_values) < 2
    error('Not enough valid data for interpolation.');
end

% Prevent extrapolation
if T_cond < T_values(1) || T_evap > T_values(end)
    error('Temperatures are outside the property table range.');
end

% Interpolate properties at selected temperatures
condProps = interp1(T_values, propertyValues, ...
    T_cond, 'linear');

evapProps = interp1(T_values, propertyValues, ...
    T_evap, 'linear');

% Store fluid name
results.fluid = fluidName;

% State 1: Condenser outlet (saturated liquid)
results.P1 = condProps(1);
results.rho1 = condProps(2);
results.h1 = condProps(3);
results.s1 = condProps(5);

% State 2: Pump outlet
results.P2 = evapProps(1);

% State 3: Turbine inlet (saturated vapor)
results.P3 = evapProps(1);
results.h3 = evapProps(4);
results.s3 = evapProps(6);

% State 4: Turbine outlet
results.P4 = condProps(1);
results.hf4 = condProps(3);
results.hg4 = condProps(4);
results.sf4 = condProps(5);
results.sg4 = condProps(6);

end
