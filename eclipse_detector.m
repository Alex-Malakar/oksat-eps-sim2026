function [eclipse_flag, solar_flux] = eclipse_detector(r_sat, sun_vec, params)


    R_earth = params.constants.R_earth;  % meters
    solar_constant = params.constants.solar_constant;  % W/m^2
    % Distance from Earth center
    r_mag = norm(r_sat);
    
    % Check if satellite is on night side
    cos_angle = dot(r_sat, sun_vec) / r_mag;
    
    if cos_angle >= 0
        % Day side - no eclipse
        eclipse_flag = 0;
    else
        % Night side - check if Earth blocks sun
        d_perp = norm(r_sat - dot(r_sat, sun_vec) * sun_vec);
        
        if d_perp < R_earth
            eclipse_flag = 1;  % In umbra
        else
            eclipse_flag = 0;  % No eclipse
        end
    end
    
    % Solar flux
    if eclipse_flag
        solar_flux = 0;
    else
        solar_flux = solar_constant;
    end
end