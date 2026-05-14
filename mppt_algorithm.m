    function [v_mppt, i_mppt, p_mppt, efficiency] = mppt_algorithm(solar_power_available, panel_voltage, params)
%MPPT algorithm, the maximum power point tracking
%Solar panels power output depends on the voltage at which you operate at
%MPPT is a current-voltage curve where there is only one voltage where
%power is at a peak, so we need to find that point of 'peakness'
%!For first runs we'll simplify the MPPT controller (for validation)!
%Inputs : solar_power_available - Maximum power from solar arrays
%         panel_voltage - Current panel voltage 
%         params - parameter structure
%Outputs : v_mppt - MPPT setpoint voltage [V]
%          i_mppt - Current at MPP [A]
%          p_mppt - Power at MPP [W]
%          efficiency - MPPT efficiency

%% Extracting solar array parameters
V_oc = params.solar.open_circuit_voltage  * params.solar.num_cells_series; %Total OC voltage [V]
I_sc = params.solar.short_circuit_current * params.solar.num_strings_parallel; %Total SC current [A]

%% MPPT setpoint
V_mpp_fraction = 0.80;
v_mppt = V_mpp_fraction * V_oc;

%% Calculate current at MPP
% I_mpp_fraction = 0.95;
% i_mppt = I_mpp_fraction * I_sc;
if solar_power_available > 0
    i_mppt = solar_power_available / v_mppt;
    i_mppt = min (i_mppt,I_sc);
else
    i_mppt = 0;
end
%Power at MPPT
p_mppt = v_mppt * i_mppt;

%% Mppt efficiency
efficiency = 0.95; %really simplified
v_mppt = max(0, min(v_mppt, V_oc)); %Voltage between 0 and V_oc
i_mppt = max(0, min(i_mppt, I_sc)); %Current between 0 and I_sc
p_mppt = max(0, p_mppt); %Power non-negative
end