function turbineResults = ORC_Turbine_Power(results)
% ORC_TURBINE_POWER
% Calculates turbine power and gross efficiency
% for one working fluid.

% Assumed component efficiencies
etaTurbine = 0.80;
etaPump = 0.75;
etaHeatExchanger = 1.0;

% Pizza oven exhaust properties
exhaustVolFlow = 3.72;    % m^3/s
exhaustDensity = 0.71;    % kg/m^3
cpExhaust = 1.10;         % kJ/(kg*K)

TExhaustIn = 170;         % C
TExhaustOut = 120;        % C

% Optional manually verified isentropic outlet enthalpy
% Leave as NaN if not available.
% Must correspond to the selected fluid and temperatures.
h4sManual = NaN;

% Calculate exhaust mass flow rate
mDotExhaust = exhaustVolFlow * exhaustDensity;

% Calculate available heat
QdotAvailable = mDotExhaust * cpExhaust * ...
    (TExhaustIn - TExhaustOut);

% Heat transferred into ORC
QdotEvaporator = etaHeatExchanger * QdotAvailable;

% Retrieve selected fluid properties
r = results;

% Pump outlet enthalpy
% Pressure must be in kPa and density in kg/m^3.
if ~isfinite(r.rho1) || r.rho1 <= 0 || r.P2 <= r.P1
    error('Invalid liquid density or pump pressure rise.');
end

h2 = r.h1 + (r.P2 - r.P1)/(r.rho1 * etaPump);

% Specific heat input
qInSpecific = r.h3 - h2;

if ~isfinite(qInSpecific) || qInSpecific <= 0
    error('Invalid evaporator enthalpy rise.');
end

% Calculate working fluid mass flow rate
mDotORC = QdotEvaporator / qInSpecific;

% Determine isentropic turbine outlet state
% s4s = s3

sfg4 = r.sg4 - r.sf4;

if ~isfinite(sfg4) || sfg4 <= 0
    error('Invalid saturated entropy values.');
end

% Calculate isentropic quality
x4s = (r.s3 - r.sf4)/sfg4;

% Determine isentropic outlet enthalpy
if isfinite(h4sManual)

    h4s = h4sManual;
    propertyMethod = 'Manual property value';

elseif x4s >= 0 && x4s <= 1

    h4s = r.hf4 + x4s*(r.hg4 - r.hf4);
    propertyMethod = 'Saturated mixture';

else

    h4s = NaN;
    propertyMethod = 'Additional property data required';

end

% Calculate actual turbine outlet enthalpy
if isfinite(h4s)

    h4 = r.h3 - etaTurbine*(r.h3 - h4s);

    % Specific turbine work
    wTurbine = r.h3 - h4;

    if wTurbine <= 0
        warning('Nonpositive turbine work. Verify properties.');
    end

    % Turbine power output (kW)
    WdotTurbine = mDotORC * wTurbine;

    % Gross turbine-based efficiency (%)
    grossEfficiency_pct = ...
        (WdotTurbine/QdotEvaporator)*100;

else

    h4 = NaN;
    wTurbine = NaN;
    WdotTurbine = NaN;
    grossEfficiency_pct = NaN;

end

% Store results
turbineResults.fluid = r.fluid;

turbineResults.h2 = h2;
turbineResults.h4s = h4s;
turbineResults.h4 = h4;

turbineResults.mDotORC = mDotORC;
turbineResults.x4s = x4s;

turbineResults.wTurbine = wTurbine;
turbineResults.WdotTurbine = WdotTurbine;

turbineResults.QdotEvaporator = QdotEvaporator;
turbineResults.grossEfficiency_pct = grossEfficiency_pct;

turbineResults.propertyMethod = propertyMethod;

end
