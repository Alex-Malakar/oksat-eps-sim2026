# OKSat — Electrical Power System Simulation
**Oklahoma State University | Senior Design | Spring 2026**

MATLAB/Simulink model for electrical power system (EPS) and thermal analysis of the OKSat 3U CubeSat over a 5-year mission in Low Earth Orbit. Developed by the EPS subsystem team as part of OSU's senior capstone program. Originally based on CodrutRomas' 6U PolySat simulation, redesigned for OKSat.

---

## Mission Overview

| Parameter | Value |
|---|---|
| Satellite | 3U OKSat |
| Orbit Altitude | 650 km |
| Inclination | 45° |
| Orbital Period | ~97.6 min |
| Eclipse Fraction | ~36.5% per orbit |
| Mission Lifetime | 5 years |
| Primary Payload | Debris-field flux validation (acoustic / thin-film impact sensors) |

---

## Attitude & Body Frame Convention

OKSat uses an **Earth-Centered Inertial (ECI)** reference frame for all orbital and attitude computations. The satellite maintains **nadir-pointing** attitude via the iADCS400-15 throughout the mission.

| Axis | Direction |
|---|---|
| +Z | Velocity (ram direction) |
| +Y | Anti-nadir (away from Earth) |
| +X | Cross-track (Z × Y, right-hand triad) |

Panel normals are defined in this body frame. The 4 deployed wing panels face anti-nadir (`+Y`); the 2 body panels tilt 45 degree from anti-nadir in the YZ plane.

---

## Hardware Stack

| Subsystem | Component | Notes |
|---|---|---|
| Solar Panels | GomSpace NanoPower DSP 135° | 2 DSPs: 2 body-mounted panels ±45° from anti-nadir + 4 deployed wing panels (6 total) |
| Solar Cells | AzurSpace 3G30-Advanced | 29.8% BOL efficiency, 6 cells per panel, 30 cm² per cell |
| Battery | GomSpace BPX | 4S-2P, 14.4V nominal, 7.0 Ah, 100.8 Wh |
| EPS | GomSpace P60 Supply Dock | ACU-200 (MPPT) + PDU-200 |
| OBC | GomSpace NanoMind A3200 | |
| ADCS | AAC Clyde Space iADCS400-15 | Nadir-pointing throughout mission |
| Communications | GomSpace NanoCom AX100 | RX 0.182 W / TX 2.640 W |

---

## Simulation Architecture

The simulation is built around a MATLAB/Simulink model (`main_simulation.slx`). All parameters are initialized via `init_parameters.m` and loaded into the Simulink base workspace before each run. There is no `params_simulink.mat` — parameters are passed directly from the MATLAB base workspace.

<img width="1438" height="792" alt="Image" src="https://github.com/user-attachments/assets/55e76803-30b2-4400-8de3-82c5f93f2471" />

### Subsystem Models

**Solar Array** (`solar_array_model.m`)
Computes per-panel power using the cosine illumination law across all 6 panels simultaneously via vectorized DCM rotation. Efficiency degrades linearly from BOL (29.8%) to EOL (23.8%) over 5 years at 1.2%/year, traceable to the AzurSpace 3G30-Advanced datasheet. Temperature correction uses a clamped derating factor (floor 50%, ceiling 115%) with coefficient −0.25%/°C above 28°C reference. Power is converted to battery-side charge current via `p_mppt × η_MPPT / V_battery`, correctly accounting for the ACU-200 buck/boost voltage transformation.

**Attitude Determination** (`attitude_determination.m`)
Builds the body-to-ECI DCM from instantaneous position and velocity vectors. Body frame: `+Z = velocity`, `+Y = anti-nadir (r_hat)`, `+X = cross(Z, Y)`. DCM is constructed with body axes as columns. Panel normals are rotated body → ECI each timestep via `DCM * panel_normals_body`.

**Battery** (`battery_voltage_model.m`, `battery_degradation_model.m`, `battery_efficiency_model.m`)
Models a GomSpace BPX 4S-2P pack. OCV uses a polynomial fit for 4S Li-ion chemistry:
```
V_oc = 11.9934 + 5.2518·SOC − 1.5739·SOC² + 1.113·SOC³
```
giving 11.99V (empty) → 14.4V (nominal) → 16.78V (full), matching 3.0–4.2V/cell range. Degradation tracks calendar aging (Arrhenius + SEI growth) and cycle-life fade (Wöhler-weighted, one cycle per orbit period). Charge efficiency is 95% (ACU-200); discharge efficiency is C-rate dependent (99% below 0.1C, 97% below 0.5C, 95% above).

**Power Mode FSM** (`power_mode_fsm.m`)
Three-state finite state machine (Safe / Nominal / Science) with hysteresis thresholds and a minimum transition delay to prevent chattering.

```
Safe Mode     (SOC < 0.77)
  │  SOC > 0.80
  ↓
Nominal Mode  (0.80 ≤ SOC < 0.88)
  │  SOC ≥ 0.88
  ↓
Science Mode  (SOC ≥ 0.88)
  │  SOC < 0.80
  └→ Nominal
```

**Power Mode Load Budget**

| Mode | Subsystems Active | Approx. Load |
|---|---|---|
| Safe | OBC only | ~2.0 W |
| Nominal | OBC + ADCS + COMMS RX | ~6.1 W |
| Science | OBC + ADCS + COMMS RX + Payload | ~9.1 W |
| TX delta (ground contact) | +COMMS TX | +2.64 W |

**Eclipse Detector** (`eclipse_detector.m`)
Cylindrical shadow model: checks day/night hemisphere via dot product, then computes perpendicular distance to Sun vector and compares to Earth radius. Parameters pulled from `params.constants` — no hardcoded values. Wrapped by `eclipse_detector_block.m` for Simulink output port compatibility.

**MPPT / PCDU** (`mppt_algorithm.m`, `power_to_current.m`)
Simulates ACU-200 MPPT at 95% efficiency (GomSpace ACU-200 datasheet). MPP voltage is 80% of V_oc, consistent with GaAs cell characteristics. Power is correctly transformed across the buck/boost converter: `i_charge = p_mppt × 0.95 / V_battery`. This properly accounts for the voltage ratio between solar array MPP voltage and battery bus voltage.

**Heater Controller** (`heater_controller.m`)
Bang-bang thermostat for battery, OBC, and payload nodes. Activates below 12.5°C, deactivates above 17.5°C (±2.5°C deadband around 15°C setpoint). Maximum heater power 6 W per BPX datasheet limit.

**Orbit Propagator** (`orbit_propagator.m`)
Keplerian propagation with J2 secular perturbations (RAAN drift and argument of periapsis precession). Returns instantaneous ECI position and velocity vectors used by attitude determination and eclipse detection each timestep.

---

## Orbital Data

Orbital ephemeris (`GMAT_output.txt`) was generated by the OKSat Aero team using GMAT for the 650 km / 45° orbit. Eclipse timing (`Eclipse.txt`) is derived from the same propagation. The orbit propagator (`orbit_propagator.m`) independently computes ECI state vectors for attitude and eclipse calculations at each simulation timestep.

---

## Key Results (2 DSPs — 6 Panels, Nadir-Pointing, 180-Day Validation Run)

| Metric | Value |
|---|---|
| Peak solar power (normal incidence, BOL) | ~35 W |
| Orbit-mean solar power | ~15–35 W (varies with beta angle) |
| SOC operating range | 75–95% |
| EOL capacity retention (5-year projected) | ~97.5% |
| Cycle count (180-day) | ~1,800 orbits |
| Cumulative energy generated (180-day) | ~48 kWh |
| Cumulative energy consumed (180-day) | ~27 kWh |
| Dominant FSM state | Nominal |
| Safe mode triggered | Not observed with dual DSP |

> **Dual DSP configuration sustains strong positive power margin throughout the mission. The large generation surplus (~21 kWh over 180 days) indicates a shunt regulator or dump load will be required in the flight design to dissipate excess energy when the battery reaches SOC ceiling. Single DSP validation confirmed marginal — Safe mode triggered during worst-case beta — validating the dual-DSP hardware requirement.**


### Note for Future Teams

This simulation represents the **first EPS model developed for OKSat** as part of the Spring 2026 senior capstone. It establishes the baseline architecture, parameter traceability, and Simulink wiring for all future iterations. Several areas are intentionally left for future teams to expand:

- **Shunt regulator / dump load modeling** — currently the simulation has no mechanism to dissipate excess solar power when the battery is full. A real flight system needs this.
- **Sun-pointing attitude mode** — the attitude block has a stub for sun-pointing during sunlight but currently runs nadir-pointing throughout. Implementing true mode-switching will increase orbit-mean power and improve Science mode utilization.
- **Thermal model fidelity** — currently a single lumped thermal node for all panels. A multi-node model separating body vs. deployed panels would improve accuracy.
- **Anomaly scenarios** — single-panel failure, partial deployment, and eclipse survival stress tests are not currently modeled.
- **FSM Science mode utilization** — with dual DSP the battery charges so quickly that Science mode thresholds may need retuning to reflect actual payload duty cycle requirements.

---

## Quick Start

1. **Initialize Parameters**

    ```matlab
    bdclose all
    run('init_parameters.m')
    ```

    > ⚠️ **Critical:** Always run `init_parameters.m` before opening or running the Simulink model. Parameters are loaded from the MATLAB base workspace — there is no MAT-file cache. If the workspace is stale, Simulink will use old values silently.

2. **Run simulation**

    ```matlab
    run('full_sim.m')
    ```

3. **Generate Plots**

    ```matlab
    run('plots.m')
    ```

4. **View Results**
    - Console output: mission summary printed on completion
    - Workspace: output signals accessible via `out.*` (e.g. `out.soc`, `out.solar_power`)


---

## Custom Simulations

### Modify Duration

```matlab
init_parameters;
params = evalin('base', 'params');
params.sim.duration        = 30 * 24 * 3600;  % e.g. 1 month in seconds
params.sim.duration_orbits = params.sim.duration / params.orbit.period;
assignin('base', 'params', params);
out = sim('main_simulation', 'SrcWorkspace', 'base');
```

### Change Solar Configuration

```matlab
% 2 DSPs — 6 panels (2 body + 4 deployed), nominal flight config
c45 = cosd(45); s45 = sind(45);
params.solar.panel_normal = [  0,    0,   0,  0,  0,  0;   % X
                              c45,  c45,   1,  1,  1,  1;   % Y (anti-nadir = +Y)
                              s45, -s45,   0,  0,  0,  0];  % Z ( 45 degree body tilt)
params.solar.total_area   = 6 * 6 * 30e-4;   % 0.108 m²
assignin('base', 'params', params);

% Single DSP — 3 panels (1 body + 2 deployed), failure/sensitivity case
params.solar.panel_normal = [ 0,    0,   0;   % X
                              c45,  1,   1;   % Y
                              s45,  0,   0];  % Z
params.solar.total_area   = 3 * 6 * 30e-4;   % 0.054 m^2
assignin('base', 'params', params);
```

### Adjust Solver

```matlab
% Faster, lower accuracy (good for long runs)
params.sim.max_step = 100;   % larger timestep [s]
params.sim.reltol   = 1e-4;

% Slower, higher accuracy (good for short diagnostic runs)
params.sim.max_step = 10;
params.sim.reltol   = 1e-5;
assignin('base', 'params', params);
```

### Set Initial SOC

```matlab
% Start at 75% (nominal) or lower to observe full charge dynamics
params.battery.SOC_initial = 0.75;
assignin('base', 'params', params);
```

### Tune FSM Thresholds

```matlab
params.power_mode.safe.soc_enter         = 0.77;
params.power_mode.safe.soc_exit          = 0.80;
params.power_mode.nominal.soc_exit_low   = 0.77;
params.power_mode.nominal.soc_exit_high  = 0.88;
params.power_mode.science.soc_enter      = 0.88;
params.power_mode.science.soc_exit       = 0.80;
params.power_mode.transition_delay       = 60;   % 1 min minimum between transitions
assignin('base', 'params', params);
```

### Change Mission Start Date

```matlab
% Affects sun vector and solar degradation fraction at t=0
params.mission.start_date = datetime(2026, 1, 1, 0, 0, 0);
assignin('base', 'params', params);
```

---

## File Structure

```
.
├── init_parameters.m               # Master parameter initialization — run first
├── full_sim.m                      # Mission simulation driver
├── plots.m                         # Post-processing plots
│
├── solar_array_model.m             # Multi-panel power + thermal model
├── battery_voltage_model.m         # 4S OCV polynomial voltage model
├── battery_degradation_model.m     # Calendar aging + cycle-life fade
├── battery_efficiency_model.m      # Charge/discharge efficiency (C-rate dependent)
├── battery_degradation_test_simulink.m  # Degradation validation sweep
│
├── power_mode_fsm.m                # Safe / Nominal / Science FSM
├── eclipse_detector.m              # Cylindrical shadow model
├── eclipse_detector_block.m        # Simulink wrapper for eclipse_detector.m
├── mppt_algorithm.m                # ACU-200 MPPT (95% efficiency, 0.80×Voc)
├── power_to_current.m              # Power → battery-side current conversion
├── heater_controller.m             # Bang-bang battery heater thermostat
├── duty_cycle_load.m               # Mode-dependent load scheduler
├── attitude_determination.m        # Body frame DCM → ECI
├── sun_vector.m                    # Sun unit vector in ECI (low-precision almanac)
├── orbit_propagator.m              # Keplerian + J2 ECI state propagator
│
├── GMAT_output.txt                 # Orbital ephemeris (OKSat Aero team, GMAT)
├── Eclipse.txt                     # Eclipse timing data (GMAT)
│
└── [Datasheets]
    ├── PWRSolar_DSP.pdf            # GomSpace NanoPower DSP 135° (DS 1018088)
    ├── PWRBattery_BPX100.PDF       # GomSpace BPX (DS 1076870)
    ├── P60.pdf                     # GomSpace P60 Supply Dock
    ├── P60ACU200.pdf               # ACU-200 MPPT (DS 1006901)
    ├── P60PDU200.pdf               # PDU-200 (DS 1014111)
    ├── A3200_Datasheet.pdf         # NanoMind A3200 OBC
    ├── COMSTranseicver_AX100.pdf   # NanoCom AX100 (DS 1013823)
    ├── COMSAntenna_NanoCom_ANT430.PDF
    ├── COMSDock_NanoDock_DMC3.pdf
    ├── iADCS4001_Utlizing_Currently.pdf  # iADCS400-15 (Feb 2023)
    ├── bdb_000108910100_tj3g30advanced_4x8.pdf  # AzurSpace 3G30-Advanced
    └── GPS.pdf
```

---

## Design Decisions & Notes

**Battery oversizing is intentional.** The BPX 4S-2P pack provides substantial eclipse energy margin, robust heater budget, and a 5-year calendar degradation buffer. The 4S configuration (not 8S) is required for P60 16V bus compatibility; 2P strings provide cell-level redundancy.

**Single DSP is insufficient for full mission operations.** Simulation validation confirmed that a single DSP triggers Safe mode during worst-case seasonal beta minima. The second DSP is not redundancy — it is required margin for Science mode operations. Body-mounted panels alone yield ~2.39 W EOL orbit-mean, well below any operational load.

**DOD floor is 25% DOD / 75% SOC minimum.** Conservative limit for high cycle-count LEO missions per Patel & Beik *Spacecraft Power Systems* 2nd ed. Safe mode entry at 77% SOC provides a 2% buffer above the floor.

**MPPT current transformation is power-based.** The ACU-200 is a buck/boost converter — array-side MPP current cannot be used directly as battery charge current. Charge current is computed as `p_mppt × η / V_battery` to correctly account for the voltage transformation across the converter.

**Cycle counting uses orbit-period gating.** The degradation model counts one Wöhler-weighted cycle per orbital period rather than per solver timestep, avoiding thousands of spurious micro-cycles from numerical noise.

**Eclipse detector uses cylindrical shadow model.** Penumbra is not modeled — the transition from full sun to full shadow is instantaneous. Error is approximately 20–30 seconds per eclipse transition, negligible for power budget purposes.

---

## Limitations

- Cylindrical (not conical) shadow model: ~20–30 s error per eclipse transition
- Single lumped thermal node for all panels: no body vs. deployed panel temperature difference
- No anomaly modeling: constant per-mode load profiles, no component failure scenarios
- Nadir-pointing assumed throughout: no sun-pointing boost during high-power phases
- Low-precision solar almanac in `sun_vector.m`: sufficient for power budget, not suitable for precise pointing calculations

---

## References

- GomSpace DS 1018088 — NanoPower DSP 135°
- GomSpace DS 1076870 — BPX Battery Pack
- GomSpace DS 1022248 — 18650 Cell
- GomSpace DS 1006901 — NanoMind A3200 / ACU-200
- GomSpace DS 1013823 — NanoCom AX100
- GomSpace DS 1014111 — PDU-200
- AAC Clyde Space iADCS400-15 Datasheet (Feb 2023)
- AzurSpace 3G30-Advanced cell datasheet
- Wertz & Larson, *Space Mission Analysis and Design* (SMAD), Ch. 10.3
- Patel & Beik, *Spacecraft Power Systems*, 2nd ed., Ch. 5

### Simulation Foundation

This simulation was built on top of **CodrutRomas' 6U PolySat MATLAB/Simulink EPS framework** as a starting point. The original provided a basic Simulink skeleton and some initial parameter structure conventions. From that foundation, OKSat EPS substantially rewrote or replaced the solar array model (multi-panel DCM rotation, correct panel normals, vectorized power calculation), battery model (4S OCV polynomial, Arrhenius calendar aging, Wöhler cycle counting), MPPT algorithm (corrected voltage transformation and efficiency application), attitude determination (body frame convention, DCM column construction), eclipse detector (parameter traceability, removed hardcoded values), power mode FSM (three-state with hysteresis and transition delay), and all parameter definitions (full traceability to GomSpace and AzurSpace datasheets). The original 8S battery comments and Cal Poly-specific parameters have been fully replaced.

---

## Team

**Oklahoma State University — OKSat Senior Design, Spring 2026**

EPS subsystem simulation developed by [@axmalakar](https://github.com/axmalakar).
Orbital ephemeris provided by the OKSat Aero team (GMAT).
Faculty advisors: Dr. O'Hara.
