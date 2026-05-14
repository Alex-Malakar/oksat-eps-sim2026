%% Short-duration test with full detail plots
% Run this for a 1-week or 1-month test to see detailed dynamics

clear; close all; clc;

% Initialize and configure for short run
init_parameters;
params = evalin('base', 'params');

% Set short duration (choose one):
%sim_duration = 7 * 24 * 3600;      % 1 week
%sim_duration = 30 * 24 * 3600;       % 1 month
sim_duration = 180 * 24 * 3600;    % 6 months
%sim_duration = 365 * 24 * 3600;

params.sim.duration = sim_duration;
params.sim.duration_orbits = sim_duration / params.orbit.period;
params.sim.max_step = 100;  % Smaller step for detail
params.battery.SOC_initial = 0.50;  % Start at 50% to see full dynamics 
assignin('base', 'params', params);

fprintf('Running %.1f day simulation...\n', sim_duration/86400);

% Run simulation
tic;
out = sim('main_simulation', 'SrcWorkspace', 'base');
elapsed = toc;
fprintf('Completed in %.1f min\n', elapsed/60);

%% Generate detailed plots
figure('Position', [50 50 1600 1200], 'Color', 'w');

% Convert time to days for x-axis
t_days = out.soc.Time / 86400;
t_solar_days = out.solar_power.Time / 86400;

%% Plot 1: SOC evolution
subplot(3,3,1);
plot(t_days, out.soc.Data*100, 'b-', 'LineWidth', 2);
xlabel('Mission Time (days)');
ylabel('SOC (%)');
title('Battery State of Charge', 'FontWeight', 'bold');
grid on;
yline(70, 'g--', 'Peak Entry');
yline(50, 'r--', 'Peak Exit');

%% Plot 2: Solar Power with eclipse shading
subplot(3,3,2);
plot(t_solar_days, out.solar_power.Data, 'b-', 'LineWidth', 1.5);
xlabel('Mission Time (days)');
ylabel('Solar Power (W)');
title('Solar Array Output', 'FontWeight', 'bold');
grid on;

%% Plot 3: Power Mode
subplot(3,3,3);
stairs(t_days, out.new_mode.Data, 'LineWidth', 2);
xlabel('Mission Time (days)');
ylabel('Mode');
title('Power Mode', 'FontWeight', 'bold');
yticks([0 1 2]); yticklabels({'Safe', 'Nominal', 'Peak'});
ylim([-0.5 2.5]);
grid on;

%% Plot 4: Power Budget
subplot(3,3,4);
plot(t_solar_days, out.solar_power.Data, 'b-', 'LineWidth', 1.5);
hold on;
plot(t_solar_days, out.p_loads_total.Data, 'r-', 'LineWidth', 1.5);
fill([t_solar_days; flipud(t_solar_days)], ...
     [out.solar_power.Data; flipud(out.p_loads_total.Data)], ...
     'g', 'FaceAlpha', 0.15, 'EdgeColor', 'none');
xlabel('Mission Time (days)');
ylabel('Power (W)');
title('Power Generation vs Load', 'FontWeight', 'bold');
legend('Solar', 'Load', 'Location', 'best');
grid on;

%% Plot 5: Battery Voltage
subplot(3,3,5);
plot(t_days, out.battery_voltage.Data, 'Color', [0.8 0.4 0], 'LineWidth', 1.5);
xlabel('Mission Time (days)');
ylabel('Voltage (V)');
title('Battery Voltage', 'FontWeight', 'bold');
grid on;

%% Plot 6: Capacity & Cycles
subplot(3,3,6);
yyaxis left
plot(t_days, out.capacity_factor.Data*100, 'b-', 'LineWidth', 2);
ylabel('Capacity (%)');
yyaxis right
plot(t_days, out.cycle_count.Data, 'r-', 'LineWidth', 2);
ylabel('Cycle Count');
xlabel('Mission Time (days)');
title('Battery Degradation', 'FontWeight', 'bold');
grid on;

%% Plot 7: Panel Temperature
subplot(3,3,7);
t_panel_days = out.panel_temp.Time / 86400;
temp_celsius = out.panel_temp.Data - 273.15;
plot(t_panel_days, temp_celsius, 'Color', [1 0.5 0], 'LineWidth', 1.5);
xlabel('Mission Time (days)');
ylabel('Temperature (°C)');
title('Solar Panel Temperature', 'FontWeight', 'bold');
grid on;

%% Plot 8: Power Loss
subplot(3,3,8);
plot(t_days, out.power_loss.Data, 'Color', [0.5 0 0.5], 'LineWidth', 1.5);
xlabel('Mission Time (days)');
ylabel('Power Loss (W)');
title('Battery Efficiency Losses', 'FontWeight', 'bold');
grid on;

%% Plot 9: Energy Balance
subplot(3,3,9);
dt_solar = mean(diff(out.solar_power.Time));
dt_load = mean(diff(out.p_loads_total.Time));
energy_gen = cumsum(out.solar_power.Data) * dt_solar / 3600;  % Wh
energy_cons = cumsum(out.p_loads_total.Data) * dt_load / 3600;  % Wh
plot(t_solar_days, energy_gen/1000, 'b-', 'LineWidth', 2);
hold on;
plot(t_solar_days, energy_cons/1000, 'r-', 'LineWidth', 2);
xlabel('Mission Time (days)');
ylabel('Energy (kWh)');
title('Cumulative Energy', 'FontWeight', 'bold');
legend('Generated', 'Consumed', 'Location', 'northwest');
grid on;

duration_str = sprintf('%.0f Days', sim_duration/86400);
sgtitle(['3U CubeSat - ' duration_str ' Mission Analysis'], 'FontSize', 16, 'FontWeight', 'bold');

% Save
filename = sprintf('mission_%dday.png', round(sim_duration/86400));
saveas(gcf, filename);
fprintf('Saved: %s\n', filename);

%% Zoomed plot: First 3 orbits
figure('Position', [100 100 1400 900], 'Color', 'w');

% First 3 orbits = ~5 hours
orbit_period = params.orbit.period;
t_zoom = 3 * orbit_period;
idx_zoom = out.soc.Time <= t_zoom;
t_zoom_min = out.soc.Time(idx_zoom) / 60;

idx_zoom_pwr = out.solar_power.Time <= t_zoom;
t_zoom_pwr_min = out.solar_power.Time(idx_zoom_pwr) / 60;

subplot(2,2,1);
plot(t_zoom_min, out.soc.Data(idx_zoom)*100, 'b-', 'LineWidth', 2);
xlabel('Time (minutes)'); ylabel('SOC (%)');
title('SOC - First 3 Orbits', 'FontWeight', 'bold'); grid on;

subplot(2,2,2);
plot(t_zoom_pwr_min, out.solar_power.Data(idx_zoom_pwr), 'b-', 'LineWidth', 2);
hold on;
plot(t_zoom_pwr_min, out.p_loads_total.Data(idx_zoom_pwr), 'r-', 'LineWidth', 2);
xlabel('Time (minutes)'); ylabel('Power (W)');
title('Power Budget', 'FontWeight', 'bold'); grid on;
legend('Solar', 'Load');

subplot(2,2,3);
plot(t_zoom_min, out.battery_voltage.Data(idx_zoom), 'Color', [0.8 0.4 0], 'LineWidth', 2);
xlabel('Time (minutes)'); ylabel('Voltage (V)');
title('Battery Voltage', 'FontWeight', 'bold'); grid on;

subplot(2,2,4);
stairs(t_zoom_min, out.new_mode.Data(idx_zoom), 'LineWidth', 2);
xlabel('Time (minutes)'); ylabel('Mode');
title('Power Mode', 'FontWeight', 'bold'); grid on;
yticks([0 1 2]); yticklabels({'Safe', 'Nominal', 'Peak'});
ylim([-0.5 2.5]);

sgtitle('First 3 Orbits Detail', 'FontSize', 14, 'FontWeight', 'bold');
saveas(gcf, 'orbit_detail_zoomed.png');
fprintf('Saved: orbit_detail_zoomed.png\n');

