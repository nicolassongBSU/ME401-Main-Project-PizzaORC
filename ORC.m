% ORC_POWER_FROM_TEMPERATURES
% Sweeps condenser and evaporator temperatures.
% Calculates turbine power and gross efficiency.
% One working fluid at a time.

clc;
clear;
close all;

fprintf('===== ORGANIC RANKINE CYCLE =====\n');

% ========== STEP 1: SELECT WORKING FLUID ==========

fprintf('\nSelect a working fluid:\n');
fprintf('1. Ammonia\n');
fprintf('2. Acetone\n');

fluidChoice = input('Enter selection (1 or 2): ');

validateattributes(fluidChoice, {'numeric'}, ...
    {'scalar','real','finite','integer','>=',1,'<=',2});

switch fluidChoice
    case 1
        fluidName = 'Ammonia';
    case 2
        fluidName = 'Acetone';
end


% ========== STEP 2: CONDENSER TEMPERATURE SWEEP ==========

fprintf('\n===== CONDENSER TEMPERATURE =====\n');

TcondMin = input('Enter minimum temperature (C): ');
TcondMax = input('Enter maximum temperature (C): ');
TcondStep = input('Enter temperature increment (C): ');


% ========== STEP 3: EVAPORATOR TEMPERATURE SWEEP ==========

fprintf('\n===== EVAPORATOR TEMPERATURE =====\n');

TevapMin = input('Enter minimum temperature (C): ');
TevapMax = input('Enter maximum temperature (C): ');
TevapStep = input('Enter temperature increment (C): ');


% ========== STEP 4: VALIDATE INPUTS ==========

allInputs = [TcondMin, TcondMax, TcondStep, ...
             TevapMin, TevapMax, TevapStep];

validateattributes(allInputs, {'numeric'}, ...
    {'vector','real','finite'});

if TcondMin > TcondMax
    error('Condenser minimum exceeds maximum.');
end

if TevapMin > TevapMax
    error('Evaporator minimum exceeds maximum.');
end

if TcondStep <= 0 || TevapStep <= 0
    error('Temperature increments must be positive.');
end

% Generate temperature arrays

TcondValues = unique([TcondMin:TcondStep:TcondMax, ...
                      TcondMax]);

TevapValues = unique([TevapMin:TevapStep:TevapMax, ...
                      TevapMax]);

numberOfCases = numel(TcondValues) * numel(TevapValues);

if numberOfCases > 5000
    error('Too many combinations. Increase temperature increments.');
end

fprintf('\nTotal temperature combinations: %d\n', numberOfCases);


% ========== STEP 5: CREATE RESULT ARRAYS ==========

[TcondGrid, TevapGrid] = meshgrid(TcondValues, TevapValues);

turbinePower = NaN(size(TcondGrid));
orcEfficiency = NaN(size(TcondGrid));

skippedCases = 0;
failedCases = 0;
firstError = '';


% ========== STEP 6: SWEEP TEMPERATURES ==========

for i = 1:numel(TcondValues)

    for j = 1:numel(TevapValues)

        T_cond = TcondValues(i);
        T_evap = TevapValues(j);

        % Check temperature restrictions
        if T_evap <= T_cond || T_evap >= 170
            skippedCases = skippedCases + 1;
            continue;
        end

        try

            % Find properties for selected fluid
            properties = Modified_Property_Finder( ...
                fluidChoice, T_cond, T_evap);

            % Calculate turbine power and efficiency
            results = ORC_Turbine_Power(properties);

            % Store results
            turbinePower(j,i) = results.WdotTurbine;

            orcEfficiency(j,i) = ...
                results.grossEfficiency_pct;

        catch ME

            failedCases = failedCases + 1;

            if isempty(firstError)
                firstError = ME.message;
            end

        end

    end

end


% ========== STEP 7: ORGANIZE RESULTS ==========

validResults = isfinite(turbinePower) & ...
               isfinite(orcEfficiency) & ...
               turbinePower > 0 & ...
               orcEfficiency > 0;

if ~any(validResults(:))

    fprintf('\nNo valid results were calculated.\n');

    if ~isempty(firstError)
        fprintf('First error: %s\n', firstError);
    end

    error('Temperature sweep produced no valid results.');

end

% Create results table
powerSummary = table( ...
    TcondGrid(validResults), ...
    TevapGrid(validResults), ...
    turbinePower(validResults), ...
    orcEfficiency(validResults), ...
    'VariableNames', ...
    {'CondenserTemp_C', ...
     'EvaporatorTemp_C', ...
     'TurbinePower_kW', ...
     'GrossEfficiency_pct'});

% Sort results by highest turbine power
powerSummary = sortrows(powerSummary, ...
    'TurbinePower_kW', 'descend');


% ========== STEP 8: FIND MAXIMUM TURBINE POWER ==========

[maxPower, powerIndex] = ...
    max(powerSummary.TurbinePower_kW);

bestPowerTcond = ...
    powerSummary.CondenserTemp_C(powerIndex);

bestPowerTevap = ...
    powerSummary.EvaporatorTemp_C(powerIndex);

bestPowerEfficiency = ...
    powerSummary.GrossEfficiency_pct(powerIndex);


% ========== STEP 9: FIND MAXIMUM EFFICIENCY ==========

[maxEfficiency, efficiencyIndex] = ...
    max(powerSummary.GrossEfficiency_pct);

bestEfficiencyTcond = ...
    powerSummary.CondenserTemp_C(efficiencyIndex);

bestEfficiencyTevap = ...
    powerSummary.EvaporatorTemp_C(efficiencyIndex);

bestEfficiencyPower = ...
    powerSummary.TurbinePower_kW(efficiencyIndex);


% ========== STEP 10: DISPLAY RESULTS ==========

fprintf('\n===== TEMPERATURE SWEEP RESULTS =====\n');

fprintf('Working Fluid: %s\n', fluidName);
fprintf('Total Cases: %d\n', numberOfCases);
fprintf('Valid Cases: %d\n', height(powerSummary));
fprintf('Skipped Cases: %d\n', skippedCases);
fprintf('Calculation Errors: %d\n', failedCases);

fprintf('\n===== MAXIMUM TURBINE POWER =====\n');

fprintf('Turbine Power: %.3f kW\n', maxPower);
fprintf('Condenser Temperature: %.2f C\n', bestPowerTcond);
fprintf('Evaporator Temperature: %.2f C\n', bestPowerTevap);
fprintf('Gross Efficiency: %.3f %c\n', ...
    bestPowerEfficiency, '%');

fprintf('\n===== MAXIMUM EFFICIENCY =====\n');

fprintf('Gross Efficiency: %.3f %c\n', ...
    maxEfficiency, '%');

fprintf('Condenser Temperature: %.2f C\n', ...
    bestEfficiencyTcond);

fprintf('Evaporator Temperature: %.2f C\n', ...
    bestEfficiencyTevap);

fprintf('Turbine Power: %.3f kW\n', ...
    bestEfficiencyPower);

fprintf('\n===== ALL POWER RESULTS =====\n');

disp(powerSummary);


% ========== STEP 11: EFFICIENCY VS EVAPORATOR GRAPH ==========

figure;

hold on;

% Each line represents a condenser temperature
for i = 1:numel(TcondValues)

    if any(isfinite(orcEfficiency(:,i)))

        plot(TevapValues, orcEfficiency(:,i), ...
            '-o', 'LineWidth', 1.5, ...
            'DisplayName', ...
            sprintf('Tcond = %.1f C', TcondValues(i)));

    end

end

xlabel('Evaporator Temperature (C)');
ylabel('Gross Efficiency (%)');

title(['Efficiency Chart - ', fluidName]);

legend('Location','best');
grid on;

hold off;


% ========== STEP 12: COMPLETION ==========

fprintf('\nTemperature sweep complete.\n');


% ========== STEP 13: SAVE RESULTS TO CSV FILE ==========

% Create a unique filename using the fluid and current date/time
fileName = sprintf('ORC_%s_Results_%s.csv', ...
    fluidName, datestr(now, 'yyyymmdd_HHMMSS'));

% Save the CSV file in the current MATLAB folder
filePath = fullfile(pwd, fileName);

% Export all valid temperature sweep results
writetable(powerSummary, filePath);

% Display confirmation
fprintf('\n===== CSV EXPORT =====\n');
fprintf('Results successfully saved to:\n%s\n', filePath);
fprintf('Total rows exported: %d\n', height(powerSummary));


%% ========== STEP 14: MAXIMUM TURBINE POWER BAR CHART ==========

% Working fluids to compare
fluidNames = {'Ammonia', 'Acetone'};

% Store maximum turbine power for each fluid
maxTurbinePower = NaN(1, numel(fluidNames));

% ========== READ CSV FILES ==========

for i = 1:numel(fluidNames)

    % Find all CSV files for the current fluid
    searchName = sprintf('ORC_%s_Results_*.csv', ...
        fluidNames{i});

    csvFiles = dir(fullfile(pwd, searchName));

    % Read each matching CSV file
    for j = 1:numel(csvFiles)

        filePath = fullfile(csvFiles(j).folder, ...
            csvFiles(j).name);

        data = readtable(filePath);

        % Check that turbine power data exists
        if ~ismember('TurbinePower_kW', ...
                data.Properties.VariableNames)
            warning('Missing turbine power column: %s', ...
                csvFiles(j).name);
            continue;
        end

        % Extract valid turbine power values
        powerValues = data.TurbinePower_kW;
        powerValues = powerValues(isfinite(powerValues));

        if isempty(powerValues)
            continue;
        end

        % Find highest turbine power in this file
        fileMax = max(powerValues);

        % Keep the highest value across all CSV files
        if isnan(maxTurbinePower(i)) || ...
                fileMax > maxTurbinePower(i)

            maxTurbinePower(i) = fileMax;

        end

    end

end

% ========== DISPLAY MAXIMUM VALUES ==========

fprintf('\n===== MAXIMUM TURBINE POWER COMPARISON =====\n');

validFluids = isfinite(maxTurbinePower);

for i = 1:numel(fluidNames)

    if validFluids(i)
        fprintf('%s: %.3f kW\n', ...
            fluidNames{i}, maxTurbinePower(i));
    else
        fprintf('%s: No CSV data found.\n', fluidNames{i});
    end

end

% ========== CREATE BAR CHART ==========

if any(validFluids)

    figure;

    % Plot only fluids with available results
    powerData = maxTurbinePower(validFluids);
    plotNames = fluidNames(validFluids);

    bar(powerData);

    xticks(1:numel(plotNames));
    xticklabels(plotNames);

    xlabel('Working Fluid');
    ylabel('Maximum Turbine Power (kW)');

    title('Maximum Turbine Power Comparison');

    grid on;

else

    warning('No valid CSV files found for comparison.');

end


% ========== STEP 15: SYSTEM COST AND PAYBACK ==========

% Given economic values
systemCostPerKW = 2600;       % $/kW
electricityRate = 9.64/100;   % $/kWh
operatingHours = 7000;        % Hours per year

% ========== CALCULATE SYSTEM COST ==========

% Use maximum turbine power from CSV comparisons
systemCost = maxTurbinePower * systemCostPerKW;


% ========== CALCULATE ANNUAL ENERGY GENERATION ==========

% Annual electricity generation (kWh/year)
annualEnergy = maxTurbinePower * operatingHours;


% ========== CALCULATE ANNUAL ELECTRICITY SAVINGS ==========

% Value of electricity produced each year
annualSavings = annualEnergy * electricityRate;


% ========== CALCULATE SYSTEM PAYBACK ==========

% Simple payback period (years)
paybackYears = systemCost ./ annualSavings;


% ========== DISPLAY RESULTS ==========

fprintf('\n===== ORC SYSTEM ECONOMIC ANALYSIS =====\n');

fprintf('System Cost per kW: $%.2f\n', systemCostPerKW);
fprintf('Electricity Rate: $%.4f/kWh\n', electricityRate);
fprintf('Annual Operating Hours: %.0f hours\n', operatingHours);

for i = 1:numel(fluidNames)

    if ~isfinite(maxTurbinePower(i)) || maxTurbinePower(i) <= 0

        fprintf('\n%s: No valid turbine power data.\n', ...
            fluidNames{i});
        continue;

    end

    fprintf('\n===== %s =====\n', fluidNames{i});

    fprintf('Maximum Turbine Power: %.3f kW\n', ...
        maxTurbinePower(i));

    fprintf('Total System Cost: $%.2f\n', ...
        systemCost(i));

    fprintf('Annual Energy Generation: %.2f kWh/year\n', ...
        annualEnergy(i));

    fprintf('Annual Electricity Savings: $%.2f/year\n', ...
        annualSavings(i));

    fprintf('Simple Payback Period: %.3f years\n', ...
        paybackYears(i));

end


