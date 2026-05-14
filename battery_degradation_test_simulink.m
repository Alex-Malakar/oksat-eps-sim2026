%% Comprehensive Battery Degradation Test - Full Mission Profile
% Tests degradation from BOL to EOL with detailed analysis

clear; close all; clc;

fprintf('\n');
fprintf('╔════════════════════════════════════════════════════════════════╗\n');
fprintf('║  CUBESAT BATTERY DEGRADATION TEST - FULL MISSION SIMULATION   ║\n');
fprintf('╚════════════════════════════════════════════════════════════════╝\n');

%% Initialize once before loop
init_parameters;

%% Test Configuration
test_configs = {
    'Week 1',     7 * 24 * 3600;
    'Month 1',    30 * 24 * 3600;
    'Month 6',    180 * 24 * 3600;
    'Year 1',     365 * 24 * 3600;
    'Year 3',     3 * 365 * 24 * 3600;
    'Year 5',     5 * 365 * 24 * 3600
};

results = struct();
start_time = datetime('now');

%% Run Simulations
for test_idx = 1:size(test_configs, 1)
    test_name = test_configs{test_idx, 1};
    sim_duration = test_configs{test_idx, 2};
    
    fprintf('\n┌─────────────────────────────────────────────────────────────┐\n');
    fprintf('│ Test %d/%d: %s\n', test_idx, size(test_configs,1), test_name);
    fprintf('└─────────────────────────────────────────────────────────────┘\n');
    fprintf('  Duration: %.1f days (%.2f years)\n', sim_duration/86400, sim_duration/(365.25*86400));
    
    % Get params from base workspace
    params = evalin('base', 'params');
    
    % Update params with new duration
    params.sim.duration_orbits = sim_duration / params.orbit.period;
    params.sim.duration = sim_duration;
    
   % Adaptive solver settings
if sim_duration < 60 * 24 * 3600
    params.sim.max_step = 20;     %20s for short sims
    params.sim.min_step = 0.1;
    params.sim.reltol = 1e-4;
elseif sim_duration < 365 * 24 * 3600
    params.sim.max_step = 30;     %30s for medium sims
    params.sim.min_step = 1;
    params.sim.reltol = 1e-4;
else
    params.sim.max_step = 40;     %40s for long sims
    params.sim.min_step = 5;
    params.sim.reltol = 1e-4;
end
    
    % Update to base workspace
    assignin('base', 'params', params);
    
    fprintf('  Configured duration: %.1f days (%.0f orbits)\n', ...
        params.sim.duration/86400, params.sim.duration_orbits);
    
    % Run simulation
    tic;
    try
        fprintf('  Status: Running (solver=%s, max_step=%ds)... ', params.sim.solver, params.sim.max_step);
        out = sim('main_simulation', 'SrcWorkspace', 'base');
        elapsed = toc;
        fprintf('✓ Done in %.1f min\n', elapsed/60);
    catch ME
        fprintf('✗ FAILED\n');
        fprintf('  Error: %s\n', ME.message);
        continue;
    end
    
    % Extract data
    try
        soc_data = out.soc.Data;
        voltage_data = out.battery_voltage.Data;
        capacity_factor_data = out.capacity_factor.Data;
        cycle_count_data = out.cycle_count.Data;
        
        % Calculate metrics
        mission_years = sim_duration / (365.25 * 86400);
        capacity_factor_eol = capacity_factor_data(end);
        cycle_count_final = cycle_count_data(end);
        
        % SOC statistics
        soc_steady = soc_data(floor(length(soc_data)/2):end);
        
        % Estimate cycles from orbits
        orbits = sim_duration / params.orbit.period;
        
        % Store results
        field_name = strrep(test_name, ' ', '_');
        results.(field_name) = struct(...
            'duration_seconds', sim_duration, ...
            'duration_days', sim_duration / 86400, ...
            'duration_years', mission_years, ...
            'capacity_factor_initial', capacity_factor_data(1), ...
            'capacity_factor_final', capacity_factor_eol, ...
            'capacity_loss_percent', (1 - capacity_factor_eol) * 100, ...
            'cycle_count', cycle_count_final, ...
            'orbits_completed', orbits, ...
            'soc_initial', soc_data(1), ...
            'soc_final', soc_data(end), ...
            'soc_min', min(soc_steady), ...
            'soc_max', max(soc_steady), ...
            'soc_mean', mean(soc_steady), ...
            'soc_range', max(soc_steady) - min(soc_steady), ...
            'voltage_initial', voltage_data(1), ...
            'voltage_final', voltage_data(end), ...
            'voltage_min', min(voltage_data), ...
            'voltage_max', max(voltage_data), ...
            'voltage_mean', mean(voltage_data), ...
            'sim_time_minutes', elapsed/60 ...
        );
        
        % Print results
        fprintf('\n  Results:\n');
        fprintf('    Capacity:      %.2f%% → %.2f%% (loss: %.2f%%)\n', ...
            capacity_factor_data(1)*100, capacity_factor_eol*100, ...
            (1-capacity_factor_eol)*100);
        fprintf('    Cycles:        %.1f (%.1f orbits)\n', cycle_count_final, orbits);
        fprintf('    SOC range:     %.2f%% - %.2f%% (Δ%.2f%%)\n', ...
            min(soc_steady)*100, max(soc_steady)*100, ...
            (max(soc_steady)-min(soc_steady))*100);
        fprintf('    Voltage:       %.2f - %.2f V (mean: %.2f V)\n', ...
            min(voltage_data), max(voltage_data), mean(voltage_data));
        fprintf('    Effective Ah:  %.2f Ah (from 13.6 Ah)\n', ...
            13.6 * capacity_factor_eol);
        
    catch ME
        fprintf('  ✗ Data extraction failed: %s\n', ME.message);
    end
end

%% Summary Table
fprintf('\n\n');
fprintf('╔════════════════════════════════════════════════════════════════════════════════╗\n');
fprintf('║                           DEGRADATION SUMMARY                                  ║\n');
fprintf('╚════════════════════════════════════════════════════════════════════════════════╝\n\n');

field_names = fieldnames(results);

if length(field_names) > 0
    fprintf('%-12s │ %8s │ %10s │ %12s │ %10s │ %10s │ %8s\n', ...
        'Period', 'Days', 'Years', 'Capacity', 'Loss (%)', 'Cycles', 'DOD (%)');
    fprintf('%s\n', repmat('─', 1, 95));
    
    for i = 1:length(field_names)
        field = field_names{i};
        r = results.(field);
        dod_per_cycle = r.soc_range * 100;
        fprintf('%-12s │ %8.0f │ %10.3f │ %11.2f%% │ %10.2f │ %10.0f │ %8.2f\n', ...
            strrep(field, '_', ' '), r.duration_days, r.duration_years, ...
            r.capacity_factor_final*100, r.capacity_loss_percent, ...
            r.cycle_count, dod_per_cycle);
    end
end

%% Detailed Analysis
fprintf('\n\n');
fprintf('╔════════════════════════════════════════════════════════════════════════════════╗\n');
fprintf('║                            DETAILED ANALYSIS                                   ║\n');
fprintf('╚════════════════════════════════════════════════════════════════════════════════╝\n');

for idx = 1:length(field_names)
    field = field_names{idx};
    r = results.(field);
    
    fprintf('\n┌── %s (%.2f years) ──────────────────────────\n', ...
        strrep(field, '_', ' '), r.duration_years);
    
    fprintf('│ CAPACITY:\n');
    fprintf('│   Factor:         %.4f\n', r.capacity_factor_final);
    fprintf('│   Remaining:      %.2f%% (%.2f Ah)\n', ...
        r.capacity_factor_final*100, 13.6*r.capacity_factor_final);
    fprintf('│   Lost:           %.2f%% (%.2f Ah)\n', ...
        r.capacity_loss_percent, 13.6*(1-r.capacity_factor_final));
    fprintf('│   Energy:         %.0f Wh (from 391 Wh)\n', ...
        391*r.capacity_factor_final);
    
    fprintf('│\n│ CYCLING:\n');
    fprintf('│   Cycles:         %.1f\n', r.cycle_count);
    fprintf('│   Orbits:         %.0f\n', r.orbits_completed);
    fprintf('│   Cycles/orbit:   %.3f\n', r.cycle_count/r.orbits_completed);
    
    fprintf('│\n│ SOC BEHAVIOR:\n');
    fprintf('│   Range:          %.2f%% - %.2f%%\n', r.soc_min*100, r.soc_max*100);
    fprintf('│   Swing:          %.2f%%\n', r.soc_range*100);
    fprintf('│   Mean:           %.2f%%\n', r.soc_mean*100);
    
    fprintf('│\n│ VOLTAGE:\n');
    fprintf('│   Range:          %.2f - %.2f V\n', r.voltage_min, r.voltage_max);
    fprintf('│   Mean:           %.2f V\n', r.voltage_mean);
    fprintf('│   Drop from BOL:  %.2f V\n', r.voltage_initial - r.voltage_final);
    
    fprintf('└────────────────────────────────────────────────────────────\n');
end

%% Degradation Breakdown
fprintf('\n\n');
fprintf('╔════════════════════════════════════════════════════════════════════════════════╗\n');
fprintf('║                         DEGRADATION BREAKDOWN                                  ║\n');
fprintf('╚════════════════════════════════════════════════════════════════════════════════╝\n\n');

params = evalin('base', 'params');

for i = 1:length(field_names)
    field = field_names{i};
    r = results.(field);
    
    % Calculate individual contributions
    calendar_fade = params.battery.calendar_fade_rate * r.duration_years * 100;
    cycle_fade = 0.20 * (r.cycle_count / params.battery.cycle_life) * 100;
    total_fade = r.capacity_loss_percent;
    
    fprintf('%s (%.2f years):\n', strrep(field, '_', ' '), r.duration_years);
    fprintf('  Calendar aging: %.2f%% (%.1f%% per year)\n', ...
        calendar_fade, calendar_fade/r.duration_years);
    fprintf('  Cycle fade:     %.2f%% (from %.0f cycles)\n', ...
        cycle_fade, r.cycle_count);
    fprintf('  Total loss:     %.2f%%\n', total_fade);
    if total_fade > 0
        fprintf('  Ratio:          %.0f%% calendar / %.0f%% cycles\n\n', ...
            100*calendar_fade/total_fade, 100*cycle_fade/total_fade);
    else
        fprintf('  Ratio:          N/A (no degradation yet)\n\n');
    end
end

%% Plotting
if length(field_names) > 0
    figure('Position', [50 50 1600 1000]);
    
    % Extract arrays
    years = []; capacity = []; losses = []; cycles = []; 
    voltage_means = []; soc_ranges = [];
    
    for i = 1:length(field_names)
        r = results.(field_names{i});
        years = [years, r.duration_years];
        capacity = [capacity, r.capacity_factor_final*100];
        losses = [losses, r.capacity_loss_percent];
        cycles = [cycles, r.cycle_count];
        voltage_means = [voltage_means, r.voltage_mean];
        soc_ranges = [soc_ranges, r.soc_range*100];
    end
    
    % Plot 1: Capacity over time
    subplot(3,3,1);
    plot(years, capacity, 'b-o', 'LineWidth', 2.5, 'MarkerSize', 10, 'MarkerFaceColor', 'b');
    hold on;
    yline(80, 'r--', 'LineWidth', 2);
    yline(50, 'r:', 'LineWidth', 1.5);
    xlabel('Mission Time (years)', 'FontWeight', 'bold');
    ylabel('Capacity (%)', 'FontWeight', 'bold');
    title('Battery Capacity Degradation', 'FontSize', 12, 'FontWeight', 'bold');
    legend('Actual', 'EOL (80%)', 'Min (50%)', 'Location', 'southwest');
    grid on; grid minor;
    ylim([45 105]);
    
    % Plot 2: Capacity loss
    subplot(3,3,2);
    plot(years, losses, 'r-s', 'LineWidth', 2.5, 'MarkerSize', 10, 'MarkerFaceColor', 'r');
    xlabel('Mission Time (years)', 'FontWeight', 'bold');
    ylabel('Capacity Loss (%)', 'FontWeight', 'bold');
    title('Cumulative Capacity Loss', 'FontSize', 12, 'FontWeight', 'bold');
    grid on; grid minor;
    
    % Plot 3: Cycle count
    subplot(3,3,3);
    plot(years, cycles, 'g-d', 'LineWidth', 2.5, 'MarkerSize', 10, 'MarkerFaceColor', 'g');
    hold on;
    yline(3000, 'r--', 'LineWidth', 2);
    xlabel('Mission Time (years)', 'FontWeight', 'bold');
    ylabel('Cycle Count', 'FontWeight', 'bold');
    title('Battery Cycling', 'FontSize', 12, 'FontWeight', 'bold');
    legend('Actual', 'Rated (3000)', 'Location', 'northwest');
    grid on; grid minor;
    
    % Plot 4: Degradation rate
    subplot(3,3,4);
    deg_rates = losses ./ years;
    bar(years, deg_rates, 'FaceColor', [1 0.5 0], 'EdgeColor', 'black', 'LineWidth', 1.5);
    xlabel('Mission Time (years)', 'FontWeight', 'bold');
    ylabel('Rate (%/year)', 'FontWeight', 'bold');
    title('Annual Degradation Rate', 'FontSize', 12, 'FontWeight', 'bold');
    grid on;
    
    % Plot 5: Voltage degradation
    subplot(3,3,5);
    plot(years, voltage_means, 'm-^', 'LineWidth', 2.5, 'MarkerSize', 10, 'MarkerFaceColor', 'm');
    xlabel('Mission Time (years)', 'FontWeight', 'bold');
    ylabel('Mean Voltage (V)', 'FontWeight', 'bold');
    title('Battery Voltage Over Time', 'FontSize', 12, 'FontWeight', 'bold');
    grid on; grid minor;
    
    % Plot 6: SOC swing
    subplot(3,3,6);
    plot(years, soc_ranges, 'c-p', 'LineWidth', 2.5, 'MarkerSize', 10, 'MarkerFaceColor', 'c');
    xlabel('Mission Time (years)', 'FontWeight', 'bold');
    ylabel('SOC Swing (%)', 'FontWeight', 'bold');
    title('Depth of Discharge per Orbit', 'FontSize', 12, 'FontWeight', 'bold');
    grid on; grid minor;
    
    % Plot 7: Degradation sources
    subplot(3,3,7);
    last_idx = length(field_names);
    r = results.(field_names{last_idx});
    calendar = params.battery.calendar_fade_rate * r.duration_years * 100;
    cycle_f = r.capacity_loss_percent - calendar;
    if cycle_f < 0, cycle_f = 0; end
    pie([calendar, cycle_f], {sprintf('Calendar (%.1f%%)', calendar), ...
        sprintf('Cycles (%.1f%%)', cycle_f)});
    title(sprintf('Degradation Sources @ %.1f years', r.duration_years), ...
        'FontSize', 12, 'FontWeight', 'bold');
    
    % Plot 8: Capacity vs cycles
    subplot(3,3,8);
    scatter(cycles, capacity, 100, years, 'filled');
    colorbar;
    xlabel('Cycle Count', 'FontWeight', 'bold');
    ylabel('Capacity (%)', 'FontWeight', 'bold');
    title('Capacity vs Cycling', 'FontSize', 12, 'FontWeight', 'bold');
    grid on;
    
    % Plot 9: Energy capacity
    subplot(3,3,9);
    energy_wh = capacity .* 391 / 100;
    plot(years, energy_wh, 'k-o', 'LineWidth', 2.5, 'MarkerSize', 10, 'MarkerFaceColor', 'k');
    xlabel('Mission Time (years)', 'FontWeight', 'bold');
    ylabel('Energy (Wh)', 'FontWeight', 'bold');
    title('Effective Battery Energy', 'FontSize', 12, 'FontWeight', 'bold');
    grid on; grid minor;
    
    sgtitle('6U CubeSat Battery Degradation - Complete Mission Analysis', ...
        'FontSize', 16, 'FontWeight', 'bold');
end

%% Projections to 15 Years
fprintf('\n');
fprintf('╔════════════════════════════════════════════════════════════════════════════════╗\n');
fprintf('║                        PROJECTION TO 15-YEAR EOL                               ║\n');
fprintf('╚════════════════════════════════════════════════════════════════════════════════╝\n\n');

if ~isempty(field_names)
    % Use longest sim for projection
    longest = results.(field_names{end});
    
    if longest.duration_years < 5
        % Linear extrapolation
        deg_rate = longest.capacity_loss_percent / longest.duration_years;
        cycle_rate = longest.cycle_count / longest.duration_years;
        
        projected_15y_loss = deg_rate * 5;
        projected_15y_cycles = cycle_rate * 5;
        projected_15y_capacity = max(50, 100 - projected_15y_loss);
        
        fprintf('Based on %.2f year simulation:\n\n', longest.duration_years);
        fprintf('  Degradation rate:  %.3f%%/year\n', deg_rate);
        fprintf('  Cycle rate:        %.1f cycles/year\n\n', cycle_rate);
        fprintf('  PROJECTED 15-YEAR PERFORMANCE:\n');
        fprintf('    Total loss:      %.1f%%\n', projected_15y_loss);
        fprintf('    Capacity:        %.1f%% (%.2f Ah)\n', ...
            projected_15y_capacity, 13.6*projected_15y_capacity/100);
        fprintf('    Energy:          %.0f Wh\n', 391*projected_15y_capacity/100);
        fprintf('    Cycles:          ~%.0f\n', projected_15y_cycles);
        fprintf('    Cycle margin:    %.0f%% of rated 3000\n', ...
            100*projected_15y_cycles/3000);
        
        if projected_15y_capacity >= 80
            fprintf('\n  ✓ Battery exceeds EOL threshold (80%%) at 15 years\n');
        else
            eol_year = 80 / projected_15y_capacity * 5;
            fprintf('\n  ⚠ Battery reaches EOL (80%%) at ~%.1f years\n', eol_year);
        end
    end
end

%% Test Summary
total_time = datetime('now') - start_time;
fprintf('\n\n');
fprintf('╔════════════════════════════════════════════════════════════════════════════════╗\n');
fprintf('║                              TEST COMPLETE                                     ║\n');
fprintf('╚════════════════════════════════════════════════════════════════════════════════╝\n\n');
fprintf('  Tests completed: %d/%d\n', length(field_names), size(test_configs,1));
fprintf('  Total runtime:   %s\n', char(total_time));
fprintf('  Completed at:    %s\n\n', datetime('now'));

% After sim
dt_samples = diff(out.soc.Time);
fprintf('SOC sample intervals: min=%.1fs, max=%.1fs, mean=%.1fs\n', ...
    min(dt_samples), max(dt_samples), mean(dt_samples));