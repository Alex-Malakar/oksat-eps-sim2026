%% init_parameters.m
%  OKSat 3U CubeSat - Power & Thermal Simulation Parameters
%  Oklahoma State University | EPS Engineer
%  Orbit: 650 km, 45 deg inclination, 5-year mission
 
clear; clc;
 
%%  PHYSICAL CONSTANTS
params.constants.mu_earth         = 3.986004418e14;  % Earth gravitational parameter [m^3/s^2]
params.constants.R_earth          = 6371e3;           % Earth mean radius [m]
params.constants.J2               = 1.08263e-3;       % Earth oblateness coefficient [-]
params.constants.AU               = 1.496e11;         % Astronomical Unit [m]
params.constants.solar_constant   = 1367;             % Solar flux at 1 AU [W/m^2]
params.constants.stefan_boltzmann = 5.670374419e-8;   % Stefan-Boltzmann constant [W/m^2/K^4]
params.constants.earth_albedo     = 0.3;              % Earth average albedo [-]
params.constants.earth_IR         = 237;              % Earth IR emission [W/m^2]
params.constants.T_space          = 2.7;              % Deep space temperature [K]
params.constants.omega_e          = 7.2921150e-5;     % Earth rotation rate [rad/s]

jd = juliandate(datetime(2025, 1, 1, 0, 0, 0));
gmst0_deg = mod(280.46061837 + 360.98564736629 * (jd - 2451545.0), 360);
params.gmat.gmst0_rad = deg2rad(gmst0_deg);
%%  ORBIT PARAMETERS 

params.orbit.altitude         = 650e3;                % OKSat design altitude [m]
params.orbit.semi_major_axis  = params.constants.R_earth + params.orbit.altitude;  % [m]
params.orbit.eccentricity     = 0.001;                % Near-circular
params.orbit.inclination      = deg2rad(45.0);        % OKSat: 45 deg inclination [rad]
params.orbit.RAAN             = deg2rad(90);          % Right Ascension of Ascending Node [rad]
params.orbit.arg_periapsis    = deg2rad(0);           % Argument of periapsis [rad]
params.orbit.true_anomaly_0   = deg2rad(0);           % Initial true anomaly [rad]
 
% Derived orbital parameters
params.orbit.period           = 2*pi*sqrt(params.orbit.semi_major_axis^3 / ...
                                params.constants.mu_earth);  % [s]
params.orbit.mean_motion      = 2*pi / params.orbit.period;  % [rad/s]
 
% Eclipse fraction: geometric estimate for 650 km, 45 deg inclination
% eclipse_detector.m computes actual geometry each step; this is for budget estimates only
params.orbit.eclipse_fraction  = 0.365;               % ~36.5% for 650 km orbit
params.orbit.eclipse_duration  = params.orbit.eclipse_fraction * params.orbit.period;  % [s]
params.orbit.sunlight_duration = params.orbit.period - params.orbit.eclipse_duration;  % [s]
 
% Mission timing
params.mission.start_date      = datetime(2025, 1, 1, 0, 0, 0);
params.mission.duration_years  = 5;                   % OKSat 5-year design life

%% GMAT Data
gmat = readmatrix('GMAT_output.txt', 'NumHeaderLines', 1, 'Delimiter', ',');
gmat_t       = gmat(:, 1);           % elapsed seconds [s]
gmat_sat_x   = gmat(:, 8)  * 1e3;   % sat X ECEF [m]
gmat_sat_y   = gmat(:, 9)  * 1e3;   % sat Y ECEF [m]
gmat_sat_z   = gmat(:, 10) * 1e3;   % sat Z ECEF [m]
gmat_sun_x   = gmat(:, 5)  * 1e3;   % sun X ECEF [m]
gmat_sun_y   = gmat(:, 6)  * 1e3;   % sun Y ECEF [m]
gmat_sun_z   = gmat(:, 7)  * 1e3;   % sun Z ECEF [m]
gmat_vx      = gmat(:, 15) * 1e3;   % sat VX ECEF [m/s]
gmat_vy      = gmat(:, 16) * 1e3;   % sat VY ECEF [m/s]
gmat_vz      = gmat(:, 17) * 1e3;   % sat VZ ECEF [m/s]

gmat_period  = gmat_t(end);               % ~86400s wrap period

% Store raw data and period for periodic lookup
params.gmat.t          = gmat_t;
params.gmat.sat_pos    = [gmat_sat_x, gmat_sat_y, gmat_sat_z];
params.gmat.sat_vel    = [gmat_vx, gmat_vy, gmat_vz];
params.gmat.sun_pos    = [gmat_sun_x, gmat_sun_y, gmat_sun_z];
params.gmat.period     = gmat_period;

% Griddedinterpolants for fast lookup
params.gmat.interp.sat_x = griddedInterpolant(gmat_t, gmat_sat_x, 'linear');
params.gmat.interp.sat_y = griddedInterpolant(gmat_t, gmat_sat_y, 'linear');
params.gmat.interp.sat_z = griddedInterpolant(gmat_t, gmat_sat_z, 'linear');
params.gmat.interp.sat_vx = griddedInterpolant(gmat_t, gmat_vx, 'linear');
params.gmat.interp.sat_vy = griddedInterpolant(gmat_t, gmat_vy, 'linear');
params.gmat.interp.sat_vz = griddedInterpolant(gmat_t, gmat_vz, 'linear');
params.gmat.interp.sun_x = griddedInterpolant(gmat_t, gmat_sun_x, 'linear');
params.gmat.interp.sun_y = griddedInterpolant(gmat_t, gmat_sun_y, 'linear');
params.gmat.interp.sun_z = griddedInterpolant(gmat_t, gmat_sun_z, 'linear');

 
%% =========================================================================
%  SOLAR ARRAY

% Physical parameters
params.solar.num_panels         = 6;                  % 6 physical panels total (2 body + 4 deployed)
params.solar.area_per_panel     = 0.018;             % [DS-DSP] 6 cells × 30 cm^2 = 0.0180 m^2 per panel
params.solar.cells_per_panel    = 6;                  % [DS-DSP] Sec 2.1: 6 cells per panel
params.solar.area_per_cell      = 30e-4;              % [DS-DSP] Sec 2.1: 30 cm^2 = 30e-4 m^2 per cell
params.solar.total_area         = params.solar.num_panels * params.solar.area_per_panel;  % 0.108 m^2

s45 = sind(45);
c45 = cosd(45);
params.solar.panel_normal = [0,  0,  0, 0, 0, 0 ;
                            s45, -s45, 1, 1, 1, 1;
                            s45, 0,  0, 0, 0, 0];
 
% Electrical parameters
params.solar.efficiency_BOL     = 0.298;             
params.solar.efficiency_EOL     = 0.238;              
params.solar.degredation_rate   = (params.solar.efficiency_BOL - params.solar.efficiency_EOL) / ...
                                   params.mission.duration_years;  % [1/year]
 
% Cell/string electrical parameters
params.solar.num_cells_series       = 6;              
params.solar.num_strings_parallel   = 3;              
params.solar.open_circuit_voltage   = 2.42;           
params.solar.short_circuit_current  = 0.508;          

% Thermal properties
params.solar.temp_coefficient   = -0.0025;            % Power loss per deg C above reference [1/deg C]
                                                      % Typical for TJ GaAs (AzurSpace 3G30A / CESI CTJ-LC)
params.solar.reference_temp     = 28 + 273.15;        % Reference temperature [K]
params.solar.absorptivity       = 0.92;               % Solar cell absorptivity
params.solar.emissivity         = 0.84;               % IR emissivity
params.solar.thermal_mass       = 200;                % Heat capacity [J/K] (2x DSP 135 deg, 449 g each)
                                                      % [DS-DSP] Sec 13: Mass 135 deg = 449 g
 
%% =========================================================================
%  BATTERY  -  GomSpace NanoPower BPX, 4S-2P configuration = 100 Wh
%  [DS-BPX] gs-ds-nanopower-bpx-4.1, Section 2.2, Section 8
%  =========================================================================
 
% Cell configuration
params.battery.num_cells_series   = 4;                % [DS-BPX] Sec 2.2: Series Cells
params.battery.num_cells_parallel = 2;                % [DS-BPX] Sec 2.2: Parallel Cells
params.battery.cell_nominal_voltage = 3.6;            % Li-ion nominal cell voltage [V]
params.battery.cell_capacity        = 3.5;            % [DS-BPX] Sec 2.1: 3500 mAh nominal per cell

params.battery.nominal_voltage = params.battery.num_cells_series * params.battery.cell_nominal_voltage; % 14.4 [V]
params.battery.capacity        = params.battery.num_cells_parallel * params.battery.cell_capacity;      % 7 [Ah]         
params.battery.energy          = params.battery.nominal_voltage * params.battery.capacity;              % Apporx 100 [Wh]   
 
% Operating Limits
params.battery.voltage_max    = params.battery.num_cells_series * 4.2;             
params.battery.voltage_min    = params.battery.num_cells_series * 3.0;            
params.battery.SOC_min        = 0.75;                 % CDR requirement: 25% DOD limit -> SOC floor = 75%
params.battery.SOC_max        = 0.95;                 % Charge limit (avoid Li-ion overcharge stress)
params.battery.SOC_initial    = 0.50;                 % Simulation starting SOC
 
% Charge/discharge C-rates
params.battery.max_charge_rate    = 0.5;             % 0.5C max charge [1/h]
params.battery.max_discharge_rate = 0.67;             % 2C max discharge [1/h]
 
% Temperature constraints (Li-ion standard)
params.battery.temp_charge_min    = 0   + 273.15;    % Min charge temperature [K]
params.battery.temp_charge_max    = 45  + 273.15;    % Max charge temperature [K]
params.battery.temp_discharge_min = -20 + 273.15;    % Min discharge temperature [K]
params.battery.temp_discharge_max = 60  + 273.15;    % Max discharge temperature [K]
params.battery.temp_nominal       = 20  + 273.15;    % Nominal operating temperature [K]
 
% Equivalent circuit model (Li-ion 18650, 4S-2P)
params.battery.R0             = 0.060;                % Internal resistance 4S-2P [Ohm] (estimated)
params.battery.R1             = 0.030;                % RC pair resistance [Ohm]
params.battery.C1             = 2000;                 % RC pair capacitance [F]
 
% Degradation model
% 27,500 cycle life at 25% DOD for LEO Li-ion (CDR-confirmed value)
% Calendar fade: ~1%/year exponential decay constant
params.battery.cycle_life          = 27500;           % cycles to 80% capacity at 25% DOD in LEO
params.battery.calendar_fade_rate  = 0.010;           % Exponential decay [1/year]
 
% Heater
params.battery.heater_power_max   = 6.0;           
 
% Thermal properties
params.battery.thermal_mass           = 900;          % Heat capacity [J/K] (BPX 500 g pack, [DS-BPX] Sec 9)
params.battery.heat_generation_factor = 0.05;         % Fraction of power dissipated as heat
 
%% =========================================================================
%  P60 POWER CONTROL & DISTRIBUTION  (ACU-200 + PDU-200 on P60 Dock)
 
% ACU-200 MPPT efficiency
params.pcdu.efficiency_mppt           = 0.95;         % [DS-ACU200] Sec 5: MPPT min efficiency = 90%
 
% PDU-200 converter efficiencies
params.pcdu.efficiency_3V3            = 0.88;         % [DS-PDU200] Sec 7: ~88% at 3.3 V output
params.pcdu.efficiency_5V             = 0.88;         % [DS-PDU200] Sec 7: ~88% at 5 V output
params.pcdu.efficiency_battery_charge = 0.95;         % ACU to battery charge path efficiency
 
% Power bus
params.pcdu.bus_voltage               = 14.4;         % [DS-BPX] 4S-2P nominal bus voltage [V]
params.pcdu.bus_regulation_tolerance  = 0.05;         % ±5% voltage regulation
 
% P60 system quiescent power
% [DS-PDU200] Sec 5: "VCC power consumption = 165 mW" (PDU VCC rail)
% [DS-PDU200] Sec 5: "VBAT power consumption = 80 mW per converter enabled" (PDU, 3 converters)
% [DS-P60]    Sec 2: P60 Dock standby = 600 mW (noted in ACU/PDU efficiency section)
% Total: 600 mW (dock) + 165 mW (PDU VCC) + 3 × 80 mW (3 converters) = 1005 mW
params.pcdu.quiescent_power           = 1.005;        % [DS-P60/PDU200] Dock 600 + VCC 165 + 3×80 = 1005 mW
params.pcdu.switching_loss_factor     = 0.03;         % Proportional switching loss factor
 
% Protection limits
% [DS-BPX] Sec 2.2: 4S-2P Vrange 12.0 - 16.8 V
params.pcdu.bus_voltage_max           = 16.8;         % [DS-BPX] 4S-2P max battery voltage [V]
params.pcdu.bus_voltage_min           = 12.0;         % [DS-BPX] 4S-2P min battery voltage [V]
params.pcdu.current_max               = 10.0;         % Overcurrent protection threshold [A] (conservative)
 
%% =========================================================================
%  SUBSYSTEM POWER LOADS  -  All values traced to component datasheets
%  =========================================================================
 
% --- OBC: GomSpace NanoMind A3200 ---
% [DS-A3200] Sec 5, p.11: VCC_OBC = 3.3 V (range 3.2-3.4 V)
% [DS-A3200] Sec 5, p.11: "All clocks 32 MHz, running ADCS: 45 mA @ 3.3 V = 0.149 W"
% [DS-A3200] Sec 5, p.11: "GSSB Power channels supply current @ 3.3 V = 114 mA" (max)
%   GSSB current is sourced through the A3200 VCC_OBC channel when GSSB peripherals active
%   Nominal ADCS operation: 45 mA MCU + ~30 mA GSSB typical = ~75 mA -> 0.247 W
%   Using 0.9 W avg to include full GSSB load budget per CDR analysis
params.loads.obc.voltage            = 3.3;            % [DS-A3200] Sec 5: VCC_OBC = 3.3 V
params.loads.obc.power_avg          = 0.900;          % [DS-A3200] Sec 5: 45mA MCU + GSSB overhead = ~0.9 W
params.loads.obc.power_peak         = 1.200;          % [DS-A3200] Sec 5: 64 MHz peak + full GSSB load
params.loads.obc.duty_cycle         = 1.0;            % Always ON
params.loads.obc.temp_operating_min = -30 + 273.15;   % [DS-A3200] Sec 6: -30 °C
params.loads.obc.temp_operating_max =  85 + 273.15;   % [DS-A3200] Sec 6: +85 °C
 
% --- ADCS: AAC Clyde Space iADCS400-15 ---
% NOTE: Peak power value TBD - pending confirmation from AAC Clyde Space
% iADCS400-15 Datasheet (AAC Clyde Space, Feb 13 2023):
%   Supply voltage: 3.3 V / 5 V
%   Nominal power: ~1.5 W (estimated from iADCS400 family datasheet)
%   Peak power: TBD (manufacturer has not confirmed; flagged for Section 11 update)
params.loads.adcs.voltage           = 5.0;            % iADCS400-15 supply voltage [V]
params.loads.adcs.power_avg         = 2.000;          % iADCS400-15 nominal power [W] (TBD - placeholder)
params.loads.adcs.power_peak        = 5.000;          % iADCS400-15 peak power [W]   (TBD - confirm w/ mfr)
params.loads.adcs.duty_cycle        = 0.7;           % Active 70% of orbit
params.loads.adcs.temp_operating_min = -40 + 273.15;
params.loads.adcs.temp_operating_max =  85 + 273.15;
 
% --- COMMS: GomSpace NanoCom AX100 ---
% [DS-AX100] Sec 7, p.11: VCC = 3.3 V
% [DS-AX100] Sec 7, p.11: Irx typ = 55 mA -> 55 mA × 3.3 V = 0.182 W (receive / standby)
% [DS-AX100] Sec 7, p.11: Itx nom (+25 C) typ = 800 mA -> 800 mA × 3.3 V = 2.640 W (transmit)
params.loads.comms.voltage          = 3.3;            % [DS-AX100] Sec 7: VCC = 3.3 V
params.loads.comms.power_avg        = 0.182;          % [DS-AX100] Sec 7: RX: 55 mA × 3.3 V = 0.182 W
params.loads.comms.power_peak       = 2.640;          % [DS-AX100] Sec 7: TX: 800 mA × 3.3 V = 2.640 W
params.loads.comms.duty_cycle       = 0.042;           % ~10% TX duty (~10 min pass per ~97 min orbit)
params.loads.comms.temp_operating_min = -30 + 273.15; % [DS-AX100] Sec 6: -30 °C
params.loads.comms.temp_operating_max =  85 + 273.15; % [DS-AX100] Sec 6: +85 °C
 
% --- Payload (placeholder - no payload in current CDR load budget) ---
% *** REPLACE WITH ACTUAL PAYLOAD DATASHEET VALUES WHEN DEFINED ***
params.loads.payload.voltage        = 5.0;            % TBD [V]
params.loads.payload.power_avg      = 2.8;            % TBD [W]
params.loads.payload.power_peak     = 4.0;            % TBD [W]
params.loads.payload.duty_cycle     = 0.25;           % TBD
params.loads.payload.temp_operating_min = 0  + 273.15;
params.loads.payload.temp_operating_max = 40 + 273.15;
 
% --- Heaters ---
% [DS-BPX] Sec 8: "Heater output power = 6 W" at 4S-2P (16 V) configuration
params.loads.heaters.voltage        = 14.4;           % Direct battery bus [V]
params.loads.heaters.power_max      = 6.0;            % [DS-BPX] Sec 8: max heater power = 6 W (4S-2P)
params.loads.heaters.duty_cycle_avg = 0.15;           % Average over mission
 
%% =========================================================================
%  POWER MODE MANAGEMENT
%  Thresholds set relative to SOC_min = 0.75 (25% DOD limit)
%  CDR nominal load: 6.435 W | Nom+Heater: 12.435 W
%  =========================================================================
 
% Safe Mode (Emergency - OBC only)
% Enter when SOC drops to within 2% of the 25% DOD floor
params.power_mode.safe.soc_enter    = 0.77;           % Enter Safe below 77% SOC
params.power_mode.safe.soc_exit     = 0.80;           % Exit Safe above 82% SOC (5% hysteresis window)
params.power_mode.safe.loads_enabled = {'obc'};       % OBC only in Safe mode
params.power_mode.safe.power_budget  = 2.0;           % OBC + PCDU quiescent ~1.9 W, budget 2 W
 
% Nominal Mode (Standard operations: OBC + ADCS + COMMS RX)
params.power_mode.nominal.soc_enter      = 0.80;      % Enter Nominal above 82% SOC
params.power_mode.nominal.soc_exit_low   = 0.77;      % Drop to Safe below 77%
params.power_mode.nominal.soc_exit_high  = 0.88;      % Rise to Science above 92%
params.power_mode.nominal.loads_enabled  = {'obc', 'adcs', 'comms'};
params.power_mode.nominal.power_budget   = 15.0;      % Nom+Heater budget headroom [W]
 
% Science Mode (Full capability - all systems)
params.power_mode.science.soc_enter   = 0.88;         % Enter Science above 92% SOC
params.power_mode.science.soc_exit    = 0.80;         % Drop to Nominal below 84% SOC
params.power_mode.science.loads_enabled = {'obc', 'adcs', 'comms', 'payload'};
params.power_mode.science.power_budget  = 20.0;       % All systems [W]
 
% Mode transition delay to prevent rapid switching
params.power_mode.transition_delay = 60;              % 60 s minimum between mode changes [s]
params.power_mode.initial_mode     = 'nominal';
 
%% =========================================================================
%  THERMAL NETWORK PARAMETERS  -  Scaled for 3U structure
%  =========================================================================
 
params.thermal.nodes = {'battery', 'solar_panels', 'obc', 'adcs', 'comms', ...
                        'payload', 'structure', 'radiator_Xp', 'radiator_Xm', ...
                        'radiator_Yp', 'radiator_Ym', 'radiator_Zp'};
params.thermal.num_nodes = length(params.thermal.nodes);
 
% Thermal masses [J/K] (mass × specific heat capacity)
% Al structure: Cp ~900 J/kg/K | Electronics: Cp ~800 J/kg/K
% [DS-BPX] Sec 9: BPX mass = 500 g -> 500g × 0.9 J/g/K (cells + Al) ~450 J/K, use 900 J/K conservative
params.thermal.mass.battery      = 900;               % BPX 500 g pack [DS-BPX] Sec 9
params.thermal.mass.solar_panels = 120;               % 2x DSP 135, 449 g each [DS-DSP] Sec 13
params.thermal.mass.obc          = 100;               % A3200 24 g [DS-A3200] Sec 7
params.thermal.mass.adcs         = 200;               % iADCS400-15 (estimated)
params.thermal.mass.comms        = 80;                % AX100 24.5 g + ANT430
params.thermal.mass.payload      = 150;               % TBD
params.thermal.mass.structure    = 900;               % 3U chassis (lighter than 6U)
params.thermal.mass.radiator_Xp  = 60;
params.thermal.mass.radiator_Xm  = 60;
params.thermal.mass.radiator_Yp  = 80;
params.thermal.mass.radiator_Ym  = 80;
params.thermal.mass.radiator_Zp  = 40;
 
% Surface properties (absorptivity α, emissivity ε)
params.thermal.surfaces.solar_array.alpha   = 0.92;
params.thermal.surfaces.solar_array.epsilon = 0.85;
params.thermal.surfaces.radiator.alpha      = 0.15;  % White paint/OSR coating
params.thermal.surfaces.radiator.epsilon    = 0.90;  % High emissivity
params.thermal.surfaces.mli.alpha           = 0.10;  % Multi-layer insulation outer
params.thermal.surfaces.mli.epsilon         = 0.05;
 
% Surface areas [m^2] - 3U body: 100 mm × 340.5 mm (long faces), 100 mm × 100 mm (end caps)
params.thermal.area.radiator_Xp = 0.0341;            % Long face ~100 mm × 340.5 mm [m^2]
params.thermal.area.radiator_Xm = 0.0341;
params.thermal.area.radiator_Yp = 0.0341;
params.thermal.area.radiator_Ym = 0.0341;
params.thermal.area.radiator_Zp = 0.0100;            % End cap 100 mm × 100 mm [m^2]
params.thermal.area.radiator_Zm = 0.0100;
 
% Conduction between nodes [W/K] (scaled for 3U smaller structure)
params.thermal.conductance = zeros(params.thermal.num_nodes);
params.thermal.conductance(1,7) = 1.5; params.thermal.conductance(7,1) = 1.5; % Battery-struct
params.thermal.conductance(2,7) = 0.5; params.thermal.conductance(7,2) = 0.5; % Solar-struct (hinges)
params.thermal.conductance(3,7) = 2.0; params.thermal.conductance(7,3) = 2.0; % OBC-struct
params.thermal.conductance(4,7) = 2.0; params.thermal.conductance(7,4) = 2.0; % ADCS-struct
params.thermal.conductance(5,7) = 1.5; params.thermal.conductance(7,5) = 1.5; % COMMS-struct
params.thermal.conductance(6,7) = 2.0; params.thermal.conductance(7,6) = 2.0; % Payload-struct
params.thermal.conductance(7,8) = 3.0; params.thermal.conductance(8,7) = 3.0; % Struct-Xp
params.thermal.conductance(7,9) = 3.0; params.thermal.conductance(9,7) = 3.0; % Struct-Xm
params.thermal.conductance(7,10)= 4.0; params.thermal.conductance(10,7)= 4.0; % Struct-Yp
params.thermal.conductance(7,11)= 4.0; params.thermal.conductance(11,7)= 4.0; % Struct-Ym
params.thermal.conductance(7,12)= 5.0; params.thermal.conductance(12,7)= 5.0; % Struct-Zp (nadir)
 
% Initial temperatures
params.thermal.temp_initial = (20 + 273.15) * ones(params.thermal.num_nodes, 1);
 
% Heater control
params.thermal.heater_setpoint  = 278.15;       % Turn ON below 15 °C [K]
params.thermal.heater_deadband  = 5;                  % ±2.5 °C hysteresis [K]
params.thermal.heater_locations = [1, 3, 6];          % Node indices: Battery, OBC, Payload
 
%% =========================================================================
%  SIMULATION PARAMETERS
%  =========================================================================
params.sim.timestep        = 1;                       % Simulation timestep [s]
params.sim.duration_orbits = 10;                      % Default: simulate 10 orbits
params.sim.duration        = params.sim.duration_orbits * params.orbit.period;
params.sim.solver          = 'ode45';
params.sim.max_step        = 10;                      % Max solver timestep [s]
params.sim.min_step        = 0.01;                    % Min solver timestep [s]
params.sim.reltol          = 1e-5;
params.sim.abstol          = 1e-6;
params.sim.log_interval    = 10;
params.sim.output_vars     = {'battery_soc', 'battery_temp', 'solar_power', ...
                              'bus_voltage', 'power_mode', 'eclipse_flag', ...
                              'thermal_temps'};
 
%% =========================================================================
%  DISPLAY SUMMARY
%  =========================================================================
fprintf('=======================================================\n');
fprintf(' OKSat 3U CubeSat - Power System Parameters Loaded\n');
fprintf('=======================================================\n');
fprintf('Mission:        3U CubeSat, 650 km, 45 deg inclination\n');
fprintf('Duration:       %d years\n', params.mission.duration_years);
fprintf('Orbit Period:   %.2f min\n', params.orbit.period/60);
fprintf('Eclipse:        %.2f min (%.1f%% of orbit)\n', ...
        params.orbit.eclipse_duration/60, params.orbit.eclipse_fraction*100);
fprintf('Solar Array: %.2f W (BOL, normal incidence, 28°C)\n', params.solar.total_area * params.constants.solar_constant * params.solar.efficiency_BOL);
fprintf('Battery: %.1f Wh nominal (%.1f V, %.1f Ah)\n', params.battery.energy, params.battery.nominal_voltage, params.battery.capacity);
fprintf('Average Load: ~%.1f W\n', params.loads.obc.power_avg + ...
                                    params.loads.adcs.power_avg*params.loads.adcs.duty_cycle + ...
                                    params.loads.comms.power_avg*params.loads.comms.duty_cycle + ...
                                    params.loads.payload.power_avg*params.loads.payload.duty_cycle + ...
                                    params.pcdu.quiescent_power);
fprintf('Simulation: %d orbits (%.2f hours)\n', params.sim.duration_orbits, params.sim.duration/3600);
fprintf('Solver: %s (RelTol=%.0e, AbsTol=%.0e)\n', params.sim.solver, params.sim.reltol, params.sim.abstol);
 
 
fprintf('\nSim: %d orbits (%.2f hours)\n', params.sim.duration_orbits, params.sim.duration/3600);
fprintf('=======================================================\n');
 
% Export to base workspace for Simulink
assignin('base', 'params', params);