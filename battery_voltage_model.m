function voltage = battery_voltage_model(soc, i_net, params)
%Calculate battery voltage based on SOC and current
%Inputs: soc - State of charge [0-1]
%        i_net - Net current (positive=charging, negative=discharging) [A]
%        params - parameter structure
% OVC Curve was found using MATLAB linear alegbra
%Outputs: voltage - Terminal voltage [V]

% Battery pack parameters
%V_nom = params.battery.nominal_voltage;  % 28.8V (8S)
R_internal = params.battery.R0;  % Internal resistance (0.08 Ohm)

% Open-circuit voltage vs SOC (typical Li-ion curve)    
%V_oc = 22.4 + 8.8*soc - 4.0*soc^2 + 3.2*soc^3;  % Non-linear curve
V_oc = 11.9934 + 5.2518*soc - 1.5739*soc^2 + 1.113*soc^3;   % 4S Li-ion OCV curve [V]

% Clamp to physical limits
%V_oc = max(22.4, min(33.6, V_oc));  % 2.8V to 4.2V per cell

% Terminal voltage including resistive drop
% V_terminal = V_oc - I*R (discharge) or V_oc + I*R (charge)
voltage = V_oc - i_net * R_internal;

% Clamp to safe operating range
voltage = max(params.battery.voltage_min, min(params.battery.voltage_max, voltage));

end