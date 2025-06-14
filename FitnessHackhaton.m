
    clearvars -except m
    distanceTravelled=0;  % Total distance in meters
    
    % Initialize
    latV = [];
    lonV = [];
    timeV = [];
    m.Logging = 1;
    
    % User inputs (modify these!)
    weightKg = 70; % User's weight in kg
    activityType = 'walking'; % Options: 'walking', 'running', 'cycling'
    
    % Set collection duration
    collectionTime = 0.5 * 60; % in seconds (0.5 minutes = 30 seconds)
    startTime = datetime('now');
    
    % Collect data in a loop
    while seconds(datetime('now') - startTime) < collectionTime
        [lat, lon, ~, ~, ~, ~, ~] = poslog(m); % Extract position data
        
        if ~isempty(lat)
            latV = [latV; lat(end)];
            lonV = [lonV; lon(end)];
            timeV = [timeV; datetime('now')];
        end
        pause(1); % Sampling interval (1 second)
    end
    m.Logging = 0;
    
    speeds = []; % Speed between points (m/s)
    timeDiffs = []; % Time differences (seconds)
    
    for i = 2:length(latV)
        % Haversine distance (meters)
        d = distance(latV(i-1), lonV(i-1), latV(i), lonV(i)) * (pi/180) * 6371000;
        distanceTravelled = distanceTravelled + d;
        
        % Time difference (seconds)
        dt = seconds(timeV(i) - timeV(i-1));
        timeDiffs = [timeDiffs; dt];
        
        % Speed (m/s)
        speed = d / dt;
        speeds = [speeds; speed];
    end
    
    SITTING_SPEED_THRESHOLD = 0.2;
    avgSpeed = mean(speeds);
    
    
    disp('===== FITNESS TRACKING RESULTS =====');
    disp(['Distance travelled: ', num2str(distanceTravelled), ' meters']);
    disp(['Average speed: ', num2str(mean(speeds)), ' m/s']);
    
    avgSpeedKmh = mean(speeds) * 3.6; % Convert m/s to km/h
    
    % MET lookup table (adjust as needed)
    if avgSpeed < SITTING_SPEED_THRESHOLD
        activityType = 'sitting';
        MET = 1.0;
    else
        % If not sitting, use normal activity detection
        switch lower(activityType)
            case 'walking'
                if avgSpeed*3.6 < 1
                    MET = 2.5; % Slow walk
                else
                    MET = 3.5; % Brisk walk
                end
            case 'running'
                if avgSpeed*3.6 < 8
                    MET = 6.0; % Jogging
                else
                    MET = 8.0; % Running
                end
            case 'cycling'
                if avgSpeed*3.6 < 16
                    MET = 4.0; % Leisure cycling
                else
                    MET = 8.0; % Vigorous cycling
                end
            otherwise
                MET = 1.0; % Default (resting)
        end
    end
    
    distances = zeros(length(timeV)-1,1);  % Stores each segment's distance
for i = 2:length(timeV)
    distances(i-1) = distance(latV(i-1), lonV(i-1), latV(i), lonV(i)) * (pi/180) * 6371000;
end

    disp(['Activity: ', activityType, ' | MET: ', num2str(MET)]);
    
    
    totalTimeHours = seconds(timeV(end) - timeV(1)) / 3600; % Total time in hours
    caloriesBurned = MET * weightKg * totalTimeHours;
    
    disp(['Calories burned: ', num2str(caloriesBurned), ' kcal']);
    disp('========================================');
    figure('Position', [100 100 800 800]); % Set figure size

    %% Plot results
figure('Position', [100 100 800 800]);

% Subplot 1: Speed
subplot(3,1,1);
plot(timeV(2:end), speeds, '-o', 'Color', [0 0.5 0.8], 'LineWidth', 1.5);
title('Speed Over Time');
ylabel('Speed (m/s)');
grid on;

% Subplot 2: Distance Travelled (using distanceTravelled)
subplot(3,1,2);
% Create array showing accumulated distance at each point
distancePoints = [0; cumsum(distances)];  % Starts at 0, then adds each segment
plot(timeV, distancePoints, '-r', 'LineWidth', 2);
hold on;
plot(timeV(end), distanceTravelled, 's', 'MarkerSize', 10, 'MarkerFaceColor', [0.8 0.2 0.2]);
title('Distance Travelled Over Time');
ylabel('Distance (m)');
xlabel('Time');
grid on;

% Subplot 3: Calories
subplot(3,1,3);
bar(timeV(end), caloriesBurned, 'FaceColor', [0.2 0.8 0.2]);
title('Total Calories Burned');
ylabel('Calories (kcal)');
xlabel('Time');
grid on;
