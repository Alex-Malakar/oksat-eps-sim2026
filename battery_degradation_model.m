function [capacity_factor, cycle_count] = battery_degradation_model(soc, i_net, cycle_count_prev, t, params)
%BATTERY_DEGRADATION_MODEL  Capacity fade for GomSpace BPX 4S-2P over mission life
%
%  Inputs:
%    soc             - Current state of charge [0-1]
%    i_net           - Net current (positive=charge, negative=discharge) [A]
%    cycle_count_prev- Accumulated equivalent full cycles from previous step
%    t               - Mission elapsed time [s]
%    params          - Parameter structure from init_parameters.m
%
%  Outputs:
%    capacity_factor - Current capacity as fraction of BOL [0.5-1.0]
%    cycle_count     - Updated accumulated equivalent full cycles
%
%  Model structure (three independent fade mechanisms, multiplicative):
%    1. Calendar aging  : exponential decay + sqrt(t) SEI growth term
%    2. Cycle-life fade : DOD-weighted Woehler law relative to rated 25% DOD
%    3. Temperature     : Arrhenius acceleration factor on calendar term
%

%% Persistent state
persistent soc_prev direction_prev;

% Reset on t=0 or first call — fixes Simulink multi-run caching bug
if isempty(soc_prev) || t == 0
    soc_prev       = soc;
    direction_prev = 0;
end

mission_years = t / (365.25 * 86400);

%% =========================================================================
%  1. CALENDAR AGING
%     Two-term model:
%       a) Bulk electrolyte decomposition  : exponential, rate k_cal [1/yr]
%       b) SEI layer growth                : sqrt(t) kinetics [Ref 2,3]
%     Both terms are accelerated by temperature via Arrhenius [Ref 3]
%% =========================================================================

% Temperature-dependent acceleration factor
T_bat = params.battery.temp_nominal;   % [K]  ideally a live signal; nominal used here
T_ref = 298.15;                         % [K]  25°C reference temperature
Ea    = 24000;                          % [J/mol]  activation energy, typical 18650 
R_gas = 8.314;                          % [J/(mol·K)]
temp_accel = exp((Ea / R_gas) * (1/T_ref - 1/T_bat));
% At T_bat = 293 K (20°C): temp_accel ≈ 0.83  (slightly slower than reference)
% At T_bat = 313 K (40°C): temp_accel ≈ 1.54  (54% faster)

% Bulk exponential decay [Ref 1]
k_cal = params.battery.calendar_fade_rate;   % [1/yr], default 0.010
bulk_fade = exp(-k_cal * mission_years * temp_accel);

% SEI growth term — sqrt(t) dominates early life [Ref 2]
k_sei = 0.004;                               % tuned for ~2% SEI loss at 5 yr, 25°C
sei_fade = k_sei * sqrt(mission_years * temp_accel);
sei_fade = min(sei_fade, 0.15);              % cap SEI contribution at 15%

calendar_retention = bulk_fade * (1 - sei_fade);
calendar_retention = max(0.5, calendar_retention);

%% =========================================================================
%  2. CYCLE-LIFE FADE  (DOD-weighted Woehler law)
%     Standard form: N_life(DOD) = N_rated * (DOD_rated / DOD)^k
%     Equivalently, each cycle at depth d consumes fraction:
%       (d / DOD_rated)^k  of a rated cycle
%     k ~ 1.5 for Li-ion [Ref 1, Ch.5]
%% =========================================================================

dod_rated  = 0.25;     % Rated cycle life defined at 25% DOD [CDR requirement]
k_wohler   = 1.5;      % Woehler exponent for Li-ion 18650 [Ref 1]

% Direction-reversal half-cycle detection
% Counts a half-cycle only when the SOC direction reverses (peak/trough)
% This avoids accumulating fake cycles from noise
raw_delta = soc - soc_prev;

cycle_increment = 0;
if abs(raw_delta) > 0.005   % 0.5% SOC noise floor
    current_dir = sign(raw_delta);
    if current_dir ~= direction_prev && direction_prev ~= 0
        % Direction reversed: a half-cycle of depth |raw_delta| just completed
        dod_this   = abs(raw_delta);
        dod_factor = (dod_this / dod_rated)^k_wohler;
        cycle_increment = 0.5 * dod_factor;   % 0.5 = half cycle
    end
    direction_prev = current_dir;
end

soc_prev    = soc;
cycle_count = cycle_count_prev + cycle_increment;

% Cycle-life retention: linear fade to 80% at rated cycle life [Ref 1]
% 0.20 = 20% capacity loss at cycle_life cycles
cycle_retention = 1.0 - 0.20 * (cycle_count / params.battery.cycle_life);
cycle_retention = max(0.5, cycle_retention);   % floor at 50%

%% =========================================================================
%  3. COMBINED CAPACITY FACTOR
%     Multiplicative — calendar and cycle aging are treated as independent
%     failure modes acting on the same capacity reservoir [Ref 1]
%% =========================================================================

capacity_factor = calendar_retention * cycle_retention;
capacity_factor = max(0.5, min(1.0, capacity_factor));

end