%% position_control_sim.m
% EENG 350 - Mini Project, position control design and verification
% Mohammed Al Abri

% Controls
% position_control_sim.m
% this simulates the cascaded controller running on the arduino miniproject_positioncontrol.ino for both of the wheels
% and this overlays the step response if positiondata.mat is in the folder
%
% for the outer loop,  desired_speed = Kp_pos*e + Ki_pos*int(e) is clamped to increase/decrease max speed, integrator is frozen during clamping
% for the inner loop, Va = Kp*(desired_speed - measured_speed), saturated at Vsat
% for the motor, w(s)/Va(s) = K*sigma/(s + sigma),  theta = int(w)
%
% The controller runs at the arduinos 10 ms sample period. it sees the encoder-quantized position, 3200 counts/rev
%
% files that are used in this are stepData.mat (refits the sigma) and positionData.mat, but theyre both optional.

clear; 
close all; 
clc

% motor param
% the k values are the exercise 2a fits, and sigma is refit from stepdata.mat
% when the file is present but if not then the fallback values are used
K     = [1.673 1.449];     % this is rad/(s*V) for motor 1 and motor 2
sigma = [10 10];           % 1/s this is the working value here

if isfile('stepData.mat')
    load('stepData.mat', 'data');
    for m = 1:2
        [K(m), sigma(m)] = fit_first_order(data(:,1), data(:,1+2*m), 1.0, 3.0);
    end
    fprintf('fitted from stepData.mat\n');
end
fprintf('Motor 1: K = %.3f, sigma = %.2f    Motor 2: K = %.3f, sigma = %.2f\n', ...
    K(1), sigma(1), K(2), sigma(2));

% parameters for the controller
Kp        = [3.0 3.0];     % inner velocity loop V per rad/s
Kp_pos    = 8.0;           % outer position loop (rad/s) per rad
Ki_pos    = 2.0;           % outer position loop (rad/s) per rad*s
max_speed = 8.0;           % rad/s desired_speed clamp
Vsat      = 7.8;           % battery voltage
Ts        = 0.01;          % controller sample period s
counts_per_rev = 3200;

% simulation
% for experimental data, goal and step time matched here
% but for now this si set to simulate 0 going to pi step on both wheels at t = 1 s
goal = [pi pi];
step_time = 1.0;
t_end = 4.0;

have_exp = isfile('positionData.mat');
if have_exp
    load('positionData.mat', 'pdata');
    te = pdata(:,1);
    % the columns are: time goal_L pos_L volt_L goal_R pos_R volt_R
    goal = [pdata(end,2) pdata(end,5)];
    istep = find(pdata(:,2) ~= pdata(1,2) | pdata(:,5) ~= pdata(1,5), 1, 'first');
    if ~isempty(istep), step_time = te(istep); end
    t_end = te(end);
end

% simulating each wheel here
% the wheel index 1 = motor 1 (LEFT in the .ino), 2 = motor 2 (RIGHT).
res = 2*pi*2/counts_per_rev;      % the resolution is 2 counts bc ISR counts by 2
results = struct();
for m = 1:2
    [ts, th, Va] = simulate_position(K(m), sigma(m), Kp(m), Kp_pos, Ki_pos, ...
        max_speed, Vsat, Ts, res, goal(m), step_time, t_end);
    results(m).t = ts; results(m).theta = th; results(m).Va = Va;

    % time is settledd to 2% and overshoot
    after = ts >= step_time;
    band = abs(th - goal(m)) > 0.02*abs(goal(m));
    last_out = find(band & after, 1, 'last');
    t_settle = ts(last_out) - step_time;
    OS = max(0, (max(th) - goal(m))/goal(m)*100);
    fprintf('Wheel %d simulated: settling (2%%) = %.2f s, overshoot = %.1f%%\n', m, t_settle, OS);
end

% this makes the plots, position and voltage, simulated vs experimental
names = {'Left wheel (motor 1)', 'Right wheel (motor 2)'};
exp_pos_col  = [3 6];
exp_volt_col = [4 7];

figure
for m = 1:2
    subplot(2,2,m)
    plot(results(m).t, results(m).theta, 'LineWidth', 2); hold on
    if have_exp
        plot(te, pdata(:,exp_pos_col(m)), '.', 'MarkerSize', 5);
    end
    yline(goal(m), 'k--');
    hold off; grid on
    xlabel('Time (s)'); ylabel('Angle (rad)')
    title([names{m} ': position'])
    if have_exp, legend('Simulated','Experimental','Goal','Location','southeast'); end

    subplot(2,2,m+2)
    plot(results(m).t, results(m).Va, 'LineWidth', 2); hold on
    if have_exp
        plot(te, pdata(:,exp_volt_col(m)), '.', 'MarkerSize', 5);
    end
    hold off; grid on
    xlabel('Time (s)'); ylabel('Voltage (V)')
    title([names{m} ': commanded voltage'])
end

% local functions here
function [t, theta, Va] = simulate_position(K, sigma, Kp, Kp_pos, Ki_pos, ...
        max_speed, Vsat, Ts, res, goal, step_time, t_end)
    % the integrated with step h, and the controller is updated every Ts
    h = Ts/20;
    n = round(t_end/Ts) + 1;
    t = (0:n-1)'*Ts;
    theta = zeros(n,1); Va = zeros(n,1);
    th = 0; w = 0; I = 0; prev_q = 0;
    for k = 1:n
        q = floor(th/res)*res;             % this is anencoder-quantized position
        w_meas = (q - prev_q)/Ts; prev_q = q;
        g = goal*(t(k) >= step_time);

        e = g - q;
        wd = Kp_pos*e + Ki_pos*I;
        if wd > max_speed
            wd = max_speed;
        elseif wd < -max_speed
            wd = -max_speed;
        else
            I = I + e*Ts;                  % this is integrated only when it isnt clamped
        end

        v = max(min(Kp*(wd - w_meas), Vsat), -Vsat);
        Va(k) = v; theta(k) = th;

        for j = 1:round(Ts/h)              % this holds v for one sample
            w  = w + h*(-sigma*w + K*sigma*v);
            th = th + h*w;
        end
    end
end

function [K, sigma] = fit_first_order(t, w, step_start, testVoltage)
    idx = t >= step_start;
    ts = t(idx); ws = w(idx);
    tail = ts >= step_start + 0.8*(max(ts) - step_start);
    w_ss = mean(ws(tail));
    K = w_ss/testVoltage;
    k63 = find(ws >= 0.632*w_ss, 1, 'first');
    sigma = 1/(ts(k63) - step_start);
end
