function p_load = duty_cycle_load(t, mode, params)
% DUTY_CYCLE_LOAD - Calculate time-varying load based on operational duty cycles
%
% Inputs:
%   t      - Current time [s]
%   mode   - Power mode (1=safe, 2=nominal, 3=science)
%   params - Parameter structure
%
% Output:
%   p_load - Instantaneous load power [W]

% Base loads always on
p_obc = params.loads.obc.power_avg;         % Always on
p_pcdu = params.pcdu.quiescent_power;       % Always on

% Initialize periodic loads
p_adcs = 0;
p_comms = 0;
p_payload = 0;

% Orbital position (for periodic events)
orbit_period = params.orbit.period;
orbit_phase = mod(t, orbit_period) / orbit_period;  % 0-1 phase within orbit

% ADCS: active 70% of orbit (constant duty)
if orbit_phase < 0.70
    p_adcs = params.loads.adcs.power_peak;
else
    p_adcs = params.loads.adcs.power_avg * 0.2;  % Idle power
end

% COMMS: bursts during ground station passes
% Assume 4 passes per day, 10 min each
% Simulate pass every ~6 hours (21600s), active for 600s
pass_period = 21600;  % 6 hours between passes [s]
pass_duration = 600;  % 10 min pass [s]
time_in_pass = mod(t, pass_period);

if time_in_pass < pass_duration
    p_comms = params.loads.comms.power_peak;  % TX active
else
    p_comms = params.loads.comms.power_avg * 0.15;  % RX listening only
end

% PAYLOAD: depends on mode and orbit phase
% In science mode, active 25% of orbit (during sunlight for imaging)
if mode == 3  % Science mode
    if orbit_phase > 0.35 && orbit_phase < 0.60  % Active during mid-sunlight
        p_payload = params.loads.payload.power_peak;
    else
        p_payload = 0;
    end
else
    p_payload = 0;  % Off in safe/nominal
end

% Total load depends on mode
switch mode
    case 1  % Safe mode
        p_load = p_obc + p_pcdu;
        
    case 2  % Nominal mode
        p_load = p_obc + p_pcdu + p_adcs + p_comms;
        
    case 3  % Science mode
        p_load = p_obc + p_pcdu + p_adcs + p_comms + p_payload;
        
    otherwise
        p_load = p_obc + p_pcdu;
end

% Clamp to mode power budget
switch mode
    case 1
        p_load = min(p_load, params.power_mode.safe.power_budget);
    case 2
        p_load = min(p_load, params.power_mode.nominal.power_budget);
    case 3
        p_load = min(p_load, params.power_mode.science.power_budget);
end

end
