 %% FINAL 5-YEAR CUBESAT COMPREHENSIVE TEST


clear all; close all; clc;

fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════════════════════╗\n');
fprintf('║                     FINAL 5-YEAR MISSION ANALYSIS                            ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════════════════╝\n');

%% Initialize
init_parameters;

%% Configure 5-year run
YEARS        = 5;
sim_duration = YEARS * 365.25 * 86400;
params       = evalin('base', 'params');
params.sim.duration        = sim_duration;
params.sim.duration_orbits = sim_duration / params.orbit.period;
params.sim.max_step = 50;
params.sim.min_step = 5;
params.sim.reltol   = 1e-4;

assignin('base', 'params', params);

fprintf('Duration: %.2f years (%.0f orbits)\n', YEARS, params.sim.duration_orbits);
fprintf('Solver: %s (max_step=%ds)\n', params.sim.solver, params.sim.max_step);

%% Run simulation
tic;
try

    fprintf('Running... ');
    out = sim('main_simulation', 'SrcWorkspace', 'base');
    elapsed = toc;
    fprintf('✓ Done in %.1f min\n', elapsed/60);
catch ME
    fprintf('\n✗ FAILED: %s\n', ME.message);
    return;
end

%% Extract signals
soc         = out.soc.Data;
vbat        = out.battery_voltage.Data;
cap_factor  = out.capacity_factor.Data;
cycles      = out.cycle_count.Data;
p_solar     = out.solar_power.Data;
p_load      = out.p_loads_total.Data;
eclipse     = out.eclipse_flag.Data;
mode        = out.new_mode.Data;
p_loss      = out.power_loss.Data;
t_soc       = out.soc.Time;
t_solar     = out.solar_power.Time;

% Panel temp (if exists)
try
    panel_temp = out.panel_temp.Data;
    if isempty(panel_temp) || all(isnan(panel_temp))
        panel_temp = [];
    end
catch
    panel_temp = [];
end

%% Compute metrics
mission_years = sim_duration / (365.25*86400);
orbits        = sim_duration / params.orbit.period;

% Solar efficiency (reported)
eff_BOL  = params.solar.efficiency_BOL * 100;
eff_EOL  = (params.solar.efficiency_BOL - params.solar.degredation_rate * mission_years) * 100;
eff_loss = (eff_BOL - eff_EOL) / eff_BOL * 100;

% Solar power - overall
p_sol_mean = mean(p_solar);
p_sol_min  = min(p_solar);
p_sol_max  = max(p_solar);
p_sol_std  = std(p_solar);

% Solar power - sunlight only
sun_idx       = (eclipse == 0);
p_sol_sun_mean = mean(p_solar(sun_idx));
p_sol_sun_min  = min(p_solar(sun_idx));
p_sol_sun_max  = max(p_solar(sun_idx));

% Energy
dt_sol       = mean(diff(t_solar));
energy_total = sum(p_solar) * dt_sol / 3600;    % Wh
energy_orbit = energy_total / orbits;
energy_day   = energy_total / (sim_duration/86400);

% Load
p_load_mean = mean(p_load);
p_load_min  = min(p_load);
p_load_max  = max(p_load);
margin_mean = p_sol_mean - p_load_mean;

% Battery
cap_init     = cap_factor(1) * 100;
cap_final    = cap_factor(end) * 100;
cap_loss_pct = 100 - cap_final;
cyc_final    = cycles(end);
cyc_per_yr   = cyc_final / mission_years;

% SOC/Vbat (steady-state = last half)
idx_ss    = floor(length(soc)/2):length(soc);
soc_min   = min(soc(idx_ss)) * 100;
soc_max   = max(soc(idx_ss)) * 100;
soc_mean  = mean(soc(idx_ss)) * 100;
vbat_min  = min(vbat(idx_ss));
vbat_max  = max(vbat(idx_ss));
vbat_mean = mean(vbat(idx_ss));

% Battery losses
dt_soc      = mean(diff(t_soc));
loss_mean_W = mean(p_loss);
loss_total  = sum(p_loss) * dt_soc / 3600;    % Wh

% Modes (0=safe, 1=nominal, 2=peak)
mode0_pct = sum(mode == 0) / numel(mode) * 100;  % Safe
mode1_pct = sum(mode == 1) / numel(mode) * 100;  % Nominal
mode2_pct = sum(mode == 2) / numel(mode) * 100;  % Peak

% Eclipse
ecl_pct  = sum(eclipse) / numel(eclipse) * 100;
ecl_time = ecl_pct/100 * params.orbit.period;
sun_time = params.orbit.period - ecl_time;

% Thermal
if ~isempty(panel_temp)
    temp_min  = min(panel_temp) - 273.15;
    temp_max  = max(panel_temp) - 273.15;
    temp_mean = mean(panel_temp) - 273.15;
else
    temp_min = NaN; temp_max = NaN; temp_mean = NaN;
end

%% Store results
results_5y = struct( ...
    'duration_years', mission_years, ...
    'orbits', orbits, ...
    'solar_eff_BOL_pct', eff_BOL, ...
    'solar_eff_EOL_pct', eff_EOL, ...
    'solar_eff_loss_pct', eff_loss, ...
    'solar_power_mean_W', p_sol_mean, ...
    'solar_power_min_W', p_sol_min, ...
    'solar_power_max_W', p_sol_max, ...
    'solar_power_std_W', p_sol_std, ...
    'solar_power_sunlight_mean_W', p_sol_sun_mean, ...
    'solar_power_sunlight_min_W', p_sol_sun_min, ...
    'solar_power_sunlight_max_W', p_sol_sun_max, ...
    'energy_total_Wh', energy_total, ...
    'energy_per_orbit_Wh', energy_orbit, ...
    'energy_per_day_Wh', energy_day, ...
    'load_mean_W', p_load_mean, ...
    'load_min_W', p_load_min, ...
    'load_max_W', p_load_max, ...
    'margin_mean_W', margin_mean, ...
    'capacity_BOL_pct', cap_init, ...
    'capacity_EOL_pct', cap_final, ...
    'capacity_loss_pct', cap_loss_pct, ...
    'cycles_total', cyc_final, ...
    'cycles_per_year', cyc_per_yr, ...
    'soc_min_pct', soc_min, ...
    'soc_max_pct', soc_max, ...
    'soc_mean_pct', soc_mean, ...
    'vbat_min_V', vbat_min, ...
    'vbat_max_V', vbat_max, ...
    'vbat_mean_V', vbat_mean, ...
    'battery_loss_mean_W', loss_mean_W, ...
    'battery_loss_total_Wh', loss_total, ...
    'panel_temp_min_C', temp_min, ...
    'panel_temp_max_C', temp_max, ...
    'panel_temp_mean_C', temp_mean, ...
    'mode_safe_pct', mode0_pct, ...
    'mode_nominal_pct', mode1_pct, ...
    'mode_science_pct', mode2_pct, ...
    'eclipse_pct', ecl_pct, ...
    'eclipse_time_per_orbit_s', ecl_time, ...
    'sunlight_time_per_orbit_s', sun_time, ...
    'sim_time_min', elapsed/60 ...
);

assignin('base', 'results_5y', results_5y);

%% Print summary
fprintf('\n');
fprintf('════════════════════════════  5-YEAR SUMMARY  ════════════════════════════════\n\n');

fprintf('SOLAR EFFICIENCY:\n');
fprintf('  BOL → EOL:           %.2f%% → %.2f%%  (loss: %.2f%%)\n', eff_BOL, eff_EOL, eff_loss);

fprintf('\nSOLAR POWER (overall):\n');
fprintf('  Mean:                %.2f W\n', p_sol_mean);
fprintf('  Min:                 %.2f W\n', p_sol_min);
fprintf('  Max:                 %.2f W\n', p_sol_max);
fprintf('  Std:                 %.2f W\n', p_sol_std);

fprintf('\nSOLAR POWER (sunlight only):\n');
fprintf('  Mean:                %.2f W\n', p_sol_sun_mean);
fprintf('  Min:                 %.2f W\n', p_sol_sun_min);
fprintf('  Max:                 %.2f W\n', p_sol_sun_max);

fprintf('\nENERGY GENERATION:\n');
fprintf('  Total:               %.1f Wh\n', energy_total);
fprintf('  Per orbit:           %.2f Wh\n', energy_orbit);
fprintf('  Per day:             %.1f Wh\n', energy_day);

fprintf('\nPOWER BUDGET:\n');
fprintf('  Load mean:           %.2f W  (min: %.2f, max: %.2f)\n', p_load_mean, p_load_min, p_load_max);
fprintf('  Solar mean:          %.2f W\n', p_sol_mean);
fprintf('  Margin:              %.2f W\n', margin_mean);

fprintf('\nBATTERY:\n');
fprintf('  Capacity:            %.2f%% → %.2f%%  (loss: %.2f%%)\n', cap_init, cap_final, cap_loss_pct);
fprintf('  Cycles:              %.0f total  (%.1f /year)\n', cyc_final, cyc_per_yr);
fprintf('  SOC (steady):        %.2f%% - %.2f%%  (mean: %.2f%%)\n', soc_min, soc_max, soc_mean);
fprintf('  Voltage (steady):    %.2f - %.2f V  (mean: %.2f V)\n', vbat_min, vbat_max, vbat_mean);
fprintf('  Efficiency losses:   mean %.2f W, total %.1f Wh\n', loss_mean_W, loss_total);

fprintf('\nTHERMAL (panel):\n');
fprintf('  Temperature:         %.1f - %.1f °C  (mean: %.1f °C)\n', temp_min, temp_max, temp_mean);

fprintf('\nOPERATIONS:\n');
fprintf('  Modes:               Safe %.1f%% | Nominal %.1f%% | Peak %.1f%%\n', mode0_pct, mode1_pct, mode2_pct);
fprintf('  Eclipse:             %.1f%%  (%.1f s/orbit)\n', ecl_pct, ecl_time);
fprintf('  Sunlight:            %.1f%%  (%.1f s/orbit)\n', 100-ecl_pct, sun_time);

fprintf('\nSIMULATION:\n');
fprintf('  Runtime:             %.1f minutes\n', elapsed/60);

fprintf('\n═══════════════════════════════════════════════════════════════════════════════\n');
fprintf('Results saved to workspace as: results_5y\n');