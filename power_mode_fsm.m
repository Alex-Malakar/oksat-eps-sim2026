 function [new_mode, loads_enabled] = power_mode_fsm(current_mode, battery_soc, time_in_mode, params)
%Power_mode_fsm - finite state machine for sat power management
%Manages transitions between safe, nominal, and science modes
% INPUTS: current_mode - Current power mode (string): 'safe', 'nominal', or 'science'
%         battery_soc - Battery state of charge [0-1] (0 = empty, 1 = full)
%         time_in_mode - Time spent in current mode [s] (for transition delay)
%         params - Parameter structure
%
% OUTPUTS: new_mode - New power mode (string): 'safe', 'nominal', or 'science'
%          loads_enabled - Cell array of subsystems to enable
%                          Example: {'obc', 'adcs', 'comms'}

%% Extract mode parameters
min_transition_delay = params.power_mode.transition_delay; %Minimum time before switching [s]

%Safe mode thresholds
soc_safe_enter = params.power_mode.safe.soc_enter; 
soc_safe_exit = params.power_mode.safe.soc_exit; 

%Science mode thresholds  
soc_science_enter = params.power_mode.science.soc_enter; 
soc_science_exit = params.power_mode.science.soc_exit; 

%% Check transition delay
%Prevent mode changes until minimum time has elapsed
if time_in_mode < min_transition_delay
    new_mode = current_mode;
    loads_enabled=get_enabled_loads(current_mode, params);
    return;
end

%% State machine logic
switch lower(current_mode)
    case 'safe'
        %SAFE MODE
        %Exit condition: SOC rises above 35%
        if battery_soc > soc_safe_exit
            new_mode = 'nominal';
        else
            new_mode = 'safe';  %Stay in safe
        end
        
    case 'nominal'
        %NOMINAL MODE
        %Two possible transitions:
        %1. Drop to Safe if SOC < 25%
        %2. Rise to Science if SOC > 70%
        
        if battery_soc < soc_safe_enter
            new_mode = 'safe';
        elseif battery_soc > soc_science_enter
            new_mode = 'science';
        else
            new_mode = 'nominal';  %Stay in nominal
        end
        
    case 'science'
        %SCIENCE MODE
        %Exit condition: SOC drops below 50%
        if battery_soc < soc_science_exit
            new_mode = 'nominal';
        else
            new_mode = 'science';  % Stay in science
        end
        
    otherwise
        %Invalid mode - default to nominal (safe fallback)
        warning('Invalid power mode: %s. Defaulting to nominal.', current_mode);
        new_mode = 'nominal';
end

%Determine which loads to enable
loads_enabled = get_enabled_loads(new_mode, params);
end
%% Helper function: Get enabled loads for each mode

function loads_enabled = get_enabled_loads(mode, params)
switch lower(mode)
    case 'safe'
        loads_enabled = params.power_mode.safe.loads_enabled;
        %Only OBC: {'obc'}
        
    case 'nominal'
        loads_enabled = params.power_mode.nominal.loads_enabled;
        %OBC + ADCS + COMMS: {'obc', 'adcs', 'comms'}
        
    case 'science'
        loads_enabled = params.power_mode.science.loads_enabled;
        %All systems: {'obc', 'adcs', 'comms', 'payload'}
        
    otherwise
        %Default to nominal if invalid
        loads_enabled = params.power_mode.nominal.loads_enabled;
end

end