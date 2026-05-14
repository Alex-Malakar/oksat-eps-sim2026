function [i_charge_actual, i_discharge_actual, power_loss] = battery_efficiency_model(i_charge, i_discharge, soc, params)
%Apply charge/discharge efficiency losses
% Charge efficiency (95% - 5% lost as heat)
eta_charge = params.pcdu.efficiency_battery_charge;  % 0.95

% Discharge efficiency depends on C-rate
% Higher discharge rates = more losses
c_rate = i_discharge / params.battery.capacity;

if c_rate < 0.05
    eta_discharge = 0.98;  % Very efficient at low rates
elseif c_rate < 0.15
    eta_discharge = 0.96;  % Nominal efficiency
else
    eta_discharge = 0.93;  % Higher losses at >1C
end

% Apply efficiencies
i_charge_actual = i_charge * eta_charge;
i_discharge_actual = i_discharge / eta_discharge;  % Need MORE current from battery to deliver load

% Calculate power losses
V_nominal = params.battery.nominal_voltage;
power_loss_charge = i_charge * V_nominal * (1 - eta_charge);
power_loss_discharge = i_discharge * V_nominal * (1 / eta_discharge - 1);
power_loss = power_loss_charge + power_loss_discharge;

end