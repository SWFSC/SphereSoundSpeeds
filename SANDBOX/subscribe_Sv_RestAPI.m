% Load java utility for reading zero-mq data format
javaaddpath('jeromq-0.5.2.jar'); % Ensure this file is in your current folder
import org.zeromq.ZMQ;

% Initialize ZMQ Context and Subscriber
context = ZMQ.context(1);
subscriber = context.socket(ZMQ.SUB);

%% EK80 REST API: TS Detection Chirp Subscription

% Configure these to match your network
ek80_ip = '192.168.1.149';      % Processor IP
param_port = 12345;             % Parameter port
sub_port = 12346;               % Subscription port
% local_ip = '192.168.1.149';     % IP of THIS computer
% local_port = 20002;        % Port where you want to receive data

param_url = ['http://localhost:' num2str(param_port)];
sub_url = ['http://localhost:' num2str(sub_port)];

%% Get list of installed transceivers

url = [param_url '/api/sounder/ping-configuration/channel-list'];
options = weboptions('ContentType', 'json');
try
    channelIDs = webread(url, options);
    disp('Installed transceivers:');
    disp(channelIDs);
catch ME
    disp('Error:');
    disp(ME.message);
    disp('Check if EK80 is running and port 12345 is correct.');
end

%% Create subscription

% MATLAB code: POST request using raw JSON string (bypasses struct field name issues)
endpoint = '/api/sounder/data-output/integration-chirp-subscriptions';
full_url = [sub_url endpoint];

options = weboptions(...
    'ContentType', 'json', ...               % Tells MATLAB to expect JSON response
    'MediaType', 'application/json', ...     % Tells it we're sending JSON
    'HeaderFields', {...
        'Accept', 'application/json'; ...
        'Content-Type', 'application/json' ...
    });

fprintf('Subscribing to channel %s...', channelIDs{3})

% Chirp single target detections
json_body = [ ...
    '{', newline, ...
    '   "channel-id": "' channelIDs{3} '",', newline, ...
    '   "settings": {', newline, ...
    '     "range": 5,', newline, ...
    '     "range-start": 2,', newline, ...
    '     "layer-type": "pelagic",', newline, ...
    '     "update-type": "update-ping",', newline, ...
    '     "integration-state": "start",', newline, ...
    '     "margin": 0.5,', newline, ...
    '     "sv-threshold": -70,', newline, ...
    '     "sv-bin-overlap": 50,', newline, ...
    '   },', newline, ...
    '   "subscription-name": "MySvChirpSub",', newline, ...
    '   "subscriber-name": "MatlabClient"', newline, ...
    '}' ...
];

try
    subID = webwrite(full_url, json_body, options);
    disp('Done!')
    
catch ME
    fprintf('Error creating subscription:\n%s\n', ME.message);    
end

%% Create a new communication endpoint
endpoint_path = '/api/sounder/data-output/communication-end-points';
full_url = [sub_url endpoint_path];

options = weboptions(...
    'ContentType', 'json', ...
    'MediaType', 'application/json', ...
    'HeaderFields', {...
        'Accept', 'application/json'; ...
        'Content-Type', 'application/json' ...
    });

% Dynamically find a free port (using Java ServerSocket on port 0)
try
    socket = java.net.ServerSocket(0);  % Port 0 lets OS choose a free ephemeral port
    free_port = socket.getLocalPort();  % Get the assigned port (typically 1024–65535)
    socket.close();                     % Close immediately to free it for EK80 use
    disp(['Automatically selected free port: ' num2str(free_port)]);
catch ME
    error('Failed to find a free port: %s', ME.message);
end

% Build the request body as a struct
% Note: "configuration" is shown as string in curl, but often needs to be a JSON string or object
% Use dynamic field syntax if hyphens appear in real keys
json_body = [ ...
    '{', newline, ...
    '   "name": "MatlabTCP_TS_Listener",', newline, ...
    '   "configuration": "tcp://localhost:' num2str(free_port) '",', newline, ...
    '   "communication-type": "zero-mq"', newline, ...
    '}' ...
];

try
    endpointID = webwrite(full_url, json_body, options);
    
    disp('Communication endpoint created successfully!');
    disp('Server response:');
    disp(endpointID);    
catch ME
    fprintf('Error creating endpoint:\n%s\n', ME.message);    
end

%% Add subscription to the endpoint
endpoint_path = ['/api/sounder/data-output/communication-end-points/' num2str(endpointID) '/data-subscriptions'];
full_url = [sub_url endpoint_path];

json_body = [ ...
    '{', newline, ...
    '   "subscription-id": ' num2str(subID) ',', newline, ...
    '   "data-serialization": "c-struct"', newline, ...
    '}' ...
];

try
    response = webwrite(full_url, json_body, options);
    
    disp('Subscription added to endpoint successfully!');
catch ME
    fprintf('Error creating endpoint:\n%s\n', ME.message);    
end

%% Read data

subscriber.connect(['tcp://localhost:' num2str(free_port)]);
topic = 'IntCh.v1';      % Topic filter for TS Detection Chirp (C-struct)

% Subscribe to ALL messages (empty string means "no filter")
subscriber.subscribe(uint8(topic));

% Read data
try
    for i = 1:5

        topicFrame = subscriber.recv(0); 
        dataFrame = subscriber.recv(0); 

        if ~isempty(dataFrame)

            % Parse Header
            sv.datagram_id   = typecast(dataFrame(1:4),   'uint32');
            sv.datagram_size = typecast(dataFrame(5:8),   'uint32');
            sv.ping_number   = typecast(dataFrame(9:12),  'uint32');
            sv.ping_time     = typecast(dataFrame(13:20), 'uint64');

            ntp_epoch_offset = datetime(1601, 1, 1);
            seconds_since_epoch = double(ts_data.ping_time) / 1e7;
            sv.datetime = ntp_epoch_offset + seconds(seconds_since_epoch);

            % numTraces = typecast(dataFrame(21:22),   'uint16');
            % fprintf('numTraces = %d\n', numTraces)

            % ts_data.data_source   = char(dataFrame(21:80)); % char[60]
            sv.channel_id  = strtrim(char(dataFrame(21:80)));

            sv.status_value      = typecast(dataFrame(81:84), 'int32');
            sv.sa                = typecast(dataFrame(85:92), 'double');
            sv.distance          = typecast(dataFrame(93:100), 'double');
            sv.frequency_limits  = typecast(dataFrame(101:108), 'single'); % float32[2]
            sv.spectrum_count    = typecast(dataFrame(109:112), 'uint32');

            disp(sv)
        end
    end
catch ME
    fprintf('Stopped: %s\n', ME.message);
end

% Cleanup
subscriber.close();
context.term();

%% Delete subscriptions

% First get all subscription IDs
url = 'http://localhost:12346/api/sounder/data-output/integration-chirp-subscriptions';
options = weboptions('ContentType', 'json');
try
    subIDs = webread(url, options);
catch ME
    disp('Error:');
    disp(ME.message);
end

% Cycle through and delete each subscription ID
for i = 1:length(subIDs)

    url = ['http://localhost:12346/api/sounder/data-output/integration-chirp-subscriptions/' num2str(subIDs(i).subscription_id)];
    options = weboptions('HeaderFields', {'Accept', 'application/json'}, ...
        'RequestMethod', 'delete', ...
        'ContentType', 'json');
    try
        response = webwrite(url, options);
        fprintf('Subscription ID %d deleted\n', subIDs(i).subscription_id)
    catch ME
        disp('Error:');
        disp(ME.message);
    end
end

%% Delete communication endpoint

% First get all communication endpoint IDs
url = 'http://localhost:12346/api/sounder/data-output/communication-end-points';
options = weboptions('ContentType', 'json');
try
    commEndPointIDs = webread(url, options);
catch ME
    disp('Error:');
    disp(ME.message);
end

% Cycle through and delete each communication endpoint
for i = 1:length(commEndPointIDs)

    url = ['http://localhost:12346/api/sounder/data-output/communication-end-points/' num2str(commEndPointIDs(i).communication_end_point_id)];
    options = weboptions('HeaderFields', {'Accept', 'application/json'}, ...
        'RequestMethod', 'delete', ...
        'ContentType', 'json');
    try
        response = webwrite(url, options);
        fprintf('Endpoint ID %d deleted\n', commEndPointIDs(i).communication_end_point_id)
    catch ME
        disp('Error:');
        disp(ME.message);
    end
end