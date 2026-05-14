function [DCM_body_to_ECI, panel_normal_ECI] = attitude_determination(...
         r_sat, v_sat, sun_vec, eclipse_flag, params)

panel_normals_body = params.solar.panel_normal; 

%% Build body frame directly in ECI — no ECEF conversion
r_hat = r_sat / norm(r_sat);
v_hat = v_sat / norm(v_sat);

%% Body frame


    z_body = v_hat;                % +Z along velocity
    y_body = r_hat;               % +Y toward Earth (nadir)
    x_body = cross(z_body, y_body);% +X cross-track
    x_body = x_body / norm(x_body);
% 
% if eclipse_flag 
%     % Nadir pointing mode 
%     z_body = v_hat;                % +Z along velocity
%     y_body = r_hat;               % +Y toward Earth (nadir)
%     x_body = cross(z_body, y_body);% +X cross-track
%     x_body = x_body / norm(x_body);
% 
% else 
%     % SUN-POINTING MODE (sunlight)
%     % Rotate +Y (wing panels) toward Sun for maximum power
%     y_body = sun_vec;                              % +Y toward Sun
%     z_body = v_hat - dot(v_hat, sun_vec)*sun_vec;  % +Z ⊥ to sun, along velocity
%     z_body = z_body / norm(z_body);
%     x_body = cross(z_body, y_body);
%     x_body = x_body / norm(x_body);
% end

%% DCM body to ECI — columns are body axes in ECI
DCM_body_to_ECI = [x_body, y_body, z_body];

%% Panel normals


panel_normal_ECI = DCM_body_to_ECI * panel_normals_body;

end