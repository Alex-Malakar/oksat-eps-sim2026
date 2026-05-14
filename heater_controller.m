function [heater_power, heater_state] = heater_controller(node_temps, heater_state_prev, params)
%Thermostat control for satellite heaters
%Controls elecrtric resitive heaters on critical thermal nodes (on/off)
% INPUTS: node_temps - Temperature of all thermal nodes [K]
%         heater_state_prev - Previous heater states (logical array, 1=ON, 0=OFF)
%         params - Parameter structure
%
% OUTPUTS: heater_power - Total heater power consumption [W]
%          heater_state - Current heater states (logical array)

%% Extract parameters
T_setpoint = params.thermal.heater_setpoint; %288.15 K (15°C)
deadband = params.thermal.heater_deadband; %5 K
heater_locations = params.thermal.heater_locations; %[1, 3, 6] (Battery, OBC, Payload)
P_heater_max = params.loads.heaters.power_max; %12W total

%% Heater power allocation
%Distribute 12W total across heated nodes
%Priority: Battery > Payload > OBC
heater_power_allocation = [4;  %Battery (8W) - most critical
                           1;  %OBC (1W) - backup
                           1]; %Payload (3W) - camera temp control

%% Calculate control thresholds
T_low = T_setpoint - deadband/2; %Turn ON below this (285.65 K = 12.5°C)
T_high = T_setpoint + deadband/2; %Turn OFF above this (290.65 K = 17.5°C)

%% Initialize heater state
num_heaters = length(heater_locations);
heater_state = heater_state_prev; %Start with previous state

%% Bang-bang control for each heater
for i = 1:num_heaters
    node_idx = heater_locations(i); %Which thermal node
    T_node = node_temps(node_idx); %Temperature of this node [K]
    
    %Bang-bang logic with hysteresis
    if T_node < T_low
        %Too cold - turn heater ON
        heater_state(i) = true;
        
    elseif T_node > T_high
        %Warm enough - turn heater OFF
        heater_state(i) = false;
        
    else
        %In deadband - keep previous state (no change)
        heater_state(i) = heater_state_prev(i);
    end
end

%% Calculate total heater power
%Sum power from all active heaters
heater_power = 0;
for i = 1:num_heaters
    if heater_state(i)
        heater_power = heater_power + heater_power_allocation(i);
    end
end

%% Safety limit
%Ensure total power doesn't exceed maximum
heater_power = min(heater_power, P_heater_max);

end