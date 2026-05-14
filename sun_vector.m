function sun_vec = sun_vector(t, params)
%Calculate sun position in ECI frame
%Inputs: t - time since mission start [s]
%        params - parameters from init_parameters.m
%Outputs: sun_vec - unit vector pointing from Earth to sun in ECI frame

%% Extract mission start date
mission_start = params.mission.start_date;

%% J2000 epoch
J2000 = datetime(2000, 1, 1, 12, 0, 0);

%% Calc julian date
JD_start = days(mission_start - J2000);
JD = JD_start + t / 86400;

%% Calc mean longitude of the sun
L0    = 280.460;
L_dot = 360/365.25;
L     = mod(L0 + L_dot * JD, 360);
L_rad = deg2rad(L);

%% Obliquity of the ecliptic
epsilon = deg2rad(23.45);

%% Sun position in ecliptic frame
r_sun      = params.constants.AU;
r_ecliptic = r_sun * [cos(L_rad);
                      sin(L_rad);
                      0];

%% Rotate ecliptic to ECI
R_ecliptic_to_ECI = [1,  0,             0;
                     0,  cos(epsilon), -sin(epsilon);
                     0,  sin(epsilon),  cos(epsilon)];

r_sun_ECI = R_ecliptic_to_ECI * r_ecliptic;

%% Output — unit vector in ECI
sun_vec = r_sun_ECI / norm(r_sun_ECI);

end