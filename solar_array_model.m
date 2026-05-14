function [solar_power, panel_temp_out] = solar_array_model(sun_vec, eclipse_flag, panel_temp, t, DCM_body_to_ECI, params)
%SOLAR_ARRAY_MODEL - Multi-panel power calculation for OKSat 3U
%  Inputs:
%    sun_vec         - Unit vector from Earth to Sun in ECI frame
%    eclipse_flag    - 1 = eclipse, 0 = sunlight
%    panel_temp      - Panel temperature [K]
%    t               - Mission elapsed time [s]
%    DCM_body_to_ECI - 3x3 rotation matrix from attitude_determination.m
%    params          - Parameter structure
%
%  Outputs:
%    solar_power     - Total electrical power from all panels [W]
%    panel_temp_out  - Updated panel temperature [K]
%
%  CRITICAL NOTES FOR SIMULATION INTEGRITY:
%    1. Only panels with cos_theta > 0 contribute (shadowed panels = 0)
%    2. Body panels run hotter than deployed panels (no convective cooling,
%       conducted heat from bus) - single thermal node is a simplification
%    3. This model assumes panels deploy successfully (no stowed mode)
%    4. Each panel contributes independently - no series-string mixing
%       between panels (P2C module combines strings in parallel per DSP)

%% Extract parameters
A_total            = params.solar.total_area;  
A_cell             = params.solar.area_per_cell;        % [m^2] per cell, 30 cm^2
cells_per_panel    = params.solar.cells_per_panel;      % 6 cells per physical panel
eta_BOL            = params.solar.efficiency_BOL;
eta_EOL            = params.solar.efficiency_EOL;
k_temp             = params.solar.temp_coefficient;
T_ref              = params.solar.reference_temp;
G_sun              = params.constants.solar_constant;
mission_duration   = params.mission.duration_years * 365.25 * 86400;
panel_normals_body = params.solar.panel_normal;

% For exponentional model of degradation 
deg_rate           = 1 - (params.solar.efficiency_EOL / params.solar.efficiency_BOL)^(1/5);

%% Solar flux
if eclipse_flag
    solar_flux = 0;
else
    solar_flux = G_sun;
end

%% Degradation model 
% linear BOL to EOL
mission_fraction = min(1.0, t / mission_duration);
eta_current      = eta_BOL - (eta_BOL - eta_EOL) * mission_fraction;

% Exponetional BOL to EOL
% years_elapsed    = min(params.mission.duration_years, t / (365.25 * 86400));
% Ld               = (1 - deg_rate) ^ years_elapsed;
% eta_current      = eta_BOL * Ld;
% eta_current      = max(eta_EOL, eta_current);  

%% Temperature correction factor (AzurSpace 3G30A, k_temp = -0.0025/°C)
T_celsius     = panel_temp - 273.15;
T_ref_celsius = T_ref - 273.15;
temp_factor   = 1 + k_temp * (T_celsius - T_ref_celsius);
temp_factor   = max(0.5, min(1.15, temp_factor));  % Clamp: floor 50%, ceiling 115%

%% Panel area
A_panel = cells_per_panel * A_cell;   % Area of one physical panel [m^2]

%% Rotate panel normals from body frame to ECI
% DCM_body_to_ECI transforms a vector FROM body TO ECI
% panel_normals_body is (3 x N_panels), each column is a unit normal

N_panels = size(panel_normals_body, 2);

panel_normals_ECI = DCM_body_to_ECI * panel_normals_body; % 3 x 6 in ECI

%% Sum power across all panels

cos_theta = max(0, min(1, sum(panel_normals_ECI .* sun_vec, 1)));  % 1x6
P_panels   = A_panel * solar_flux * eta_current * temp_factor * cos_theta;
solar_power = sum(P_panels);

        % solar_power = 0;
        % 
        % for k = 1:N_panels
        %     % Cosine of incidence angle for panel k
        %     cos_theta_k = dot(panel_normals_ECI(:,k), sun_vec);
        % 
        %     % Only illuminated face contributes (cos_theta > 0)
        %     % Clamp between 0 and 1 (no negative contributions, no >1)
        %     cos_theta_k = max(0, min(1, cos_theta_k));
        % 
        %     % Power from this panel
        %     P_panel = A_panel * solar_flux * eta_current * cos_theta_k * temp_factor;
        % 
        %     solar_power = solar_power + P_panel;
        % end

%% Clamp total power
solar_power = max(0, solar_power);

%% Thermal model (single lumped panel thermal node)
% Radiation balance: absorbed solar - electrical output - radiated to space
panel_temp = mean(panel_temp);
alpha   = params.solar.absorptivity;
epsilon = params.solar.emissivity;
C_therm = params.solar.thermal_mass;
sigma   = params.constants.stefan_boltzmann;


        % Total incident solar across all panels (sum of illuminated projections)
        % Approximate: use total area × mean cos_theta for thermal
        % cos_mean = solar_power / max(1e-6, A_total * solar_flux * eta_current * temp_factor);
        % cos_mean = max(0, min(1, cos_mean));

P_incident  = A_total * solar_flux * mean(cos_theta);
P_absorbed  = alpha  * P_incident;
P_electrical = solar_power;
P_heat      = P_absorbed - P_electrical;
P_radiated  = sigma * epsilon * A_total * panel_temp^4;



P_net   = P_heat - P_radiated;
dt      = 1;  % 1-second step
dT      = (P_net / C_therm) * dt;
panel_temp_out = panel_temp + dT;

% Limit temp to physical range
panel_temp_out = max(250, min(350, panel_temp_out));  % Physical clamp [K]

end