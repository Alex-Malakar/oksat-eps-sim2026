function [r_ECI, v_ECI] = orbit_propagator(t, params)
%Orbit propagator-calculates sat position and velocity in earth-centered    
%inertial (ECI) frame using Keplerian orbital mechanics with J2
%perturbations
%Inputs - t - time;
%       - params - parameter structure from init_parameters.m
%Outputs - r_ECI - postition vector [x,y,z] in ECI frame
%        - v_ECI - position velocity [vx,vy,vz] in ECI frame

%% Extract orbit parameters
a = params.orbit.semi_major_axis; %Semi major axis
e = params.orbit.eccentricity; %Eccentricity
i = params.orbit.inclination; %Inclination
RAAN_0 = params.orbit.RAAN; %Initial RAAN
omega_0 = params.orbit.arg_periapsis; %Initial argument of periapsis
M_0 = params.orbit.true_anomaly_0; %Initial mean anomaly

%% Extract constants
mu = params.constants.mu_earth; %Earth's gravitational parameter
R_e = params.constants.R_earth; %Earth radius
J2 = params.constants.J2; %J2 coef

%calc mean motion 
n = sqrt(mu/a^3);

%% J2 Perturbations (secular effects/dynamic orbit changes)
%Causes slow drift in RAAN and arg of periapsis

%RAAN drift rate
RAAN_dot = -1.5 * n * J2 * (R_e/a)^2 * cos(i);

%Argument of periapsis drift rate
omega_dot = 0.75 * n * J2 * (R_e/a)^2 * (5*cos(i)^2-1);

%Update RAAN and omega with time
RAAN = RAAN_0 + RAAN_dot * t; %Current RAAN 
omega = omega_0 + omega_dot * t; %Current arg of periapsis

% Mean anomaly increases linearly with time
M = M_0 + n * t; %Mean anomaly [rad]
M = mod(M, 2*pi); %Wrap to [0, 2π]

%% Solve Kepler's equation: M = E - e*sin(E)
%We will use Newthon-Raphson iteration to find the eccentric anomaly
E = M; %Initial guess
tolerance = 1e-8;
max_iter = 10;

for iter = 1:max_iter
    f = E - e * sin(E) - M; %Function
    f_prime = 1 - e*cos(E); %Derivative
    E_new = E - f/f_prime; %Newthon-Raphson step
    if abs(E_new - E) < tolerance
        break;
    end
    E = E_new;
end

%Convert eccentric anomaly to true anomaly
nu = 2 * atan2(sqrt(1+e)*sin(E/2), sqrt(1-e)*cos(E/2));
nu = mod(nu, 2*pi);

%Calc orbital radius
r = a * (1-e*cos(E));

%% Position and velocity in orbital frame (perifocal coordinates)
%Position in perifocal frame
r_peri = [r*cos(nu); %x component
          r*sin(nu); %y component
          0]; %z component

%Velocity in perifocal frame
v_peri = (sqrt(mu/a) / (1 - e*cos(E))) * [-sin(nu);
                                             sqrt(1-e^2)*cos(nu);
                                             0];

%% Rotation from perifocal to ECI frame
%Rotation about z-axis by angle theta: R3(theta)
R3 = @(theta) [cos(theta), sin(theta), 0;
               -sin(theta), cos(theta), 0;
                0,          0,         1];

%Rotation about x-axis by angle theta: R1(theta)
R1 = @(theta) [1,  0,           0;
               0,  cos(theta),  sin(theta);
               0, -sin(theta),  cos(theta)];

%Combined rotation matrix (perifocal → ECI)
R_peri_to_ECI = R3(-RAAN) * R1(-i) * R3(-omega);

%Rotate position and velocity
r_ECI = R_peri_to_ECI * r_peri; %Position in ECI 
v_ECI = R_peri_to_ECI * v_peri; %Velocity in ECI 

end