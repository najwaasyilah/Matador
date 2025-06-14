m = mobiledev;

%% Initialize
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

distanceTravelled = 0; % Total distance in meters
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

disp(['Distance travelled: ', num2str(distanceTravelled), ' meters']);
disp(['Average speed: ', num2str(mean(speeds)), ' m/s']);

avgSpeedKmh = mean(speeds) * 3.6; % Convert m/s to km/h

% MET lookup table (adjust as needed)
MET = 0;
switch lower(activityType)
    case 'walking'
        if avgSpeedKmh < 5
            MET = 2.5; % Slow walk
        else
            MET = 3.5; % Brisk walk
        end
    case 'running'
        if avgSpeedKmh < 8
            MET = 6.0; % Jogging
        else
            MET = 8.0; % Running
        end
    case 'cycling'
        if avgSpeedKmh < 16
            MET = 4.0; % Leisure cycling
        else
            MET = 8.0; % Vigorous cycling
        end
    otherwise
        MET = 1.0; % Default (resting)
end

disp(['Activity: ', activityType, ' | MET: ', num2str(MET)]);


totalTimeHours = seconds(timeV(end) - timeV(1)) / 3600; % Total time in hours
caloriesBurned = MET * weightKg * totalTimeHours;

disp(['Calories burned: ', num2str(caloriesBurned), ' kcal']);