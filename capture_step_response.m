% Controls
% capture_step_response.m
% this reads the step response data from the arduinos serial port into MATLAB
% this makes it so that the arduino ide doesnt select the data in the serial monitor 
% because we were dealing with that bug earlier

% to usee it you need to close the arduino IDE serial monitor, along with any programs that could be 
% using the port. since only one port can handle one serial port at a time
% then the stepresponsetest.ino needs to be uploaded to the board
% it cant be uploaded from the IDE
% the serial montior window needs to be closed after
% and then figure out your port and select port below the boards port name
% and then run the script and you wll get data in the workspace along with a saved stepData.mat

clear data
port = 'COM3';     % port
baud = 115200;      % has to match Serial.begin() in the .ino

capture_seconds = 4.0;   % sketch halts printing at 3s; a little margin is safe

% port opening
s = serialport(port, baud);
configureTerminator(s, "LF");
flush(s);

fprintf('Port opened. waiting for board reset\n');
pause(2.5);   % gives time to reset before reading

% this reads lines until the capture window ends
rows = {};
t_capture_start = tic;
while toc(t_capture_start) < capture_seconds
    if s.NumBytesAvailable > 0
        line = readline(s);
        line = strtrim(line);
        if ~isempty(line)
            rows{end+1} = line; 
        end
    end
end

clear s   % close the port

fprintf('Captured %d lines. Parsing...\n', numel(rows));

% this parses into a numeric matrix : time, voltage1, velocity1, voltage2, velocity2

data = [];
for i = 1:numel(rows)
    vals = sscanf(rows{i}, '%f\t%f\t%f\t%f\t%f');
    if numel(vals) == 5
        data(end+1, :) = vals';
    end
    % skipping messed up lines for debugging
end

if isempty(data)
    error(['no valid data rows parsed. check that: (1) the correct sketch is ' ...
           'uploaded, (2) the port name is correct, (3) nothing else has the ' ...
           'port open, and (4) baud matches Serial.begin() in the .ino.']);
end

fprintf('Parsed %d valid data rows spanning t = %.3f to %.3f s.\n', ...
    size(data,1), data(1,1), data(end,1));

save('stepData.mat', 'data');

%% debugging plot
figure
subplot(2,1,1)
plot(data(:,1), data(:,3), '.-'); hold on
plot(data(:,1), data(:,5), '.-'); hold off
xlabel('Time (s)'); ylabel('Angular Velocity (rad/s)')
legend('Motor 1', 'Motor 2', 'Location', 'southeast')
title('Raw captured step response')

subplot(2,1,2)
plot(data(:,1), data(:,2), '.-'); hold on
plot(data(:,1), data(:,4), '.-'); hold off
xlabel('Time (s)'); ylabel('Commanded Voltage (V)')
legend('Motor 1', 'Motor 2', 'Location', 'southeast')

fprintf('\ndata and stepData.mat are ready. Run identify_K_sigma.m next.\n');
