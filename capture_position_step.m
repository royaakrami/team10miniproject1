% Controls
% capture_position_step.m
% this runs an experimental position step on MiniProject_PositionControl.ino
% it saves it so that position_control_sim.m can compare against it

% before running it we need to upload MiniProject_PositionControl.ino, then we need to close the serial monitor
% then we set both wheels with tape '0' facing up. 
% opening the port will reset the arduino, this zeroes the encoders at that position
% then we unplug the pi from a4/a5, or ensure that goals arent being set so theres
% no overrides on the goals sent here

% this is intended to output:
% positionData.mat with variable pdata, columns [time goal_L pos_L volt_L goal_R pos_R volt_R]

port = "COM3";          % the port we havee
goal_byte = 3;          % 3 has both wheels to the pi, wanting to have one wheel would mean using 1 or 2
wait_before_step = 1.0; % the datas s at the goal 0 before the step
capture_time = 4.0;     % this is the s of the data after the steps occurence

s = serialport(port, 115200);
configureTerminator(s, "LF");
pause(2.5);             % resetting arduino here
flush(s);

lines = {};
t0 = tic;
sent = false;
while toc(t0) < wait_before_step + capture_time
    if ~sent && toc(t0) >= wait_before_step
        write(s, char('0' + goal_byte), "char");   % this is like typing the digit itself
        sent = true;
    end
    if s.NumBytesAvailable > 0
        try
            lines{end+1} = readline(s); 
        catch
        end
    end
end
clear s

pdata = [];
for i = 1:numel(lines)
    v = sscanf(lines{i}, '%f');
    if numel(v) == 7
        pdata(end+1,:) = v'; 
    end
end
if isempty(pdata)
    error('Data wasnt parsed look at the sketch');
end

% start the time axis at the first captured row
pdata(:,1) = pdata(:,1) - pdata(1,1);
save('positionData.mat', 'pdata');
fprintf('This saved %d rows to positionData.mat. So to compare, run position_control_sim.m.\n', size(pdata,1));
