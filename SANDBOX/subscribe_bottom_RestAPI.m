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
endpoint = '/api/sounder/data-output/bottom-detection-subscriptions';
full_url = [sub_url endpoint];

options = weboptions(...
    'ContentType', 'json', ...               % Tells MATLAB to expect JSON response
    'MediaType', 'application/json', ...     % Tells it we're sending JSON
    'HeaderFields', {...
        'Accept', 'application/json'; ...
        'Content-Type', 'application/json' ...
    });

fprintf('Subscribing to channel %s...', channelIDs{3})

% Bottom detection settings
json_body = [ ...
    '{', newline, ...
    '   "channel-id": "' channelIDs{3} '",', newline, ...
    '   "settings": {', newline, ...
    '     "upper-detector-limit": 5,', newline, ...
    '     "lower-detector-limit": 15,', newline, ...
    '     "bottom-back-step": -50', newline, ...
    '   },', newline, ...
    '   "subscription-name": "MyBottomSub",', newline, ...
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
    
    disp('Communication endpoint created successfully!');
    disp('Server response:');
    disp(response);    
catch ME
    fprintf('Error creating endpoint:\n%s\n', ME.message);    
end

%% Read data

subscriber.connect(['tcp://localhost:' num2str(free_port)]);
topic = 'Bot.v1';      % Topic filter for TS Detection Chirp (C-struct)

% Subscribe to ALL messages (empty string means "no filter")
subscriber.subscribe(uint8(topic));

% Read data
try
    for i = 1:5

        topicFrame = subscriber.recv(0); 
        dataFrame = subscriber.recv(0); 

        if ~isempty(dataFrame)

            % Parse Header
            bottom.datagram_id   = typecast(dataFrame(1:4),   'uint32');
            bottom.datagram_size = typecast(dataFrame(5:8),   'uint32');
            bottom.ping_number   = typecast(dataFrame(9:12),  'uint32');
            bottom.ping_time     = typecast(dataFrame(13:20), 'uint64');

            ntp_epoch_offset = datetime(1601, 1, 1);
            seconds_since_epoch = double(ts_data.ping_time) / 1e7;
            bottom.datetime = ntp_epoch_offset + seconds(seconds_since_epoch);

            % numTraces = typecast(dataFrame(21:22),   'uint16');
            % fprintf('numTraces = %d\n', numTraces)

            % ts_data.data_source   = char(dataFrame(21:80)); % char[60]
            bottom.channel_id  = strtrim(char(dataFrame(21:80)));

            bottom.depth = typecast(dataFrame(81:88), 'double');
            fprintf('Depth = %.2f\n', bottom.depth)
            disp(bottom)

            % ts_data.num_targets = num_targets;
            % 
            % % --- PARSING Tsdc.v1 (C-STRUCT) ---
            % % At this point, dataFrame is a uint8 array.
            % % You must map this to the structure defined in 'sounder_datagrams.h'
            % % Example: If the first 4 bytes are an integer 'ping_number'
            % ping_number = typecast(dataFrame(1:4), 'int32');
            % 
            % % To find the TS values, you'll need the exact byte offset 
            % % for the 'target_data' array within the Tsdc.v1 struct.
            % fprintf('Received TS Chirp Data | Ping: %d | Total Bytes: %d\n', ...
            %     ping_number, length(dataFrame));
        end
    end
catch ME
    fprintf('Stopped: %s\n', ME.message);
end



% host = 'localhost';  % Or '127.0.0.1'
% port = free_port;        % Match your configuration
% 
% % Create TCP server (listener) – requires R2019b+
% client = tcpclient(host, port, 'Timeout', 10);
% disp(['Listening on TCP port ' num2str(port) '... Press Ctrl+C to stop.']);
% 
% try
%     while true
%         if client.NumBytesAvailable > 0
%             % Read length prefix (assume first 4 bytes = datagram size as uint32)
%             size_bytes = read(client, 4, 'uint8');
%             if ~isempty(size_bytes)
%                 dg_size = typecast(size_bytes, 'uint32');
% 
%                 % Read the full datagram
%                 data_bytes = read(client, dg_size, 'uint8');
% 
%                 % Unpack binary c-struct (adjust format from sounder_datagrams.h)
%                 % Example placeholder: < (little-endian), i (int32), Q (uint64), 60s (60-char string), d (double)
%                 unpack_format = '<iiiQ60sddddi';  % Customize: e.g., datagram_id, size, ping_number, ping_time, channel_id, target_strength, range, etc.
%                 unpacked = num2cell(typecast(data_bytes, 'single'));  % Typecast to match format, then unpack
% 
%                 % Map to struct (adjust fields based on actual struct definition)
%                 datagram = struct(...
%                     'datagram_id', unpacked{1}, ...
%                     'datagram_size', unpacked{2}, ...
%                     'ping_number', unpacked{3}, ...
%                     'ping_time', unpacked{4}, ...
%                     'channel_id', char(unpacked{5}), ...
%                     'target_strength', unpacked{6}, ...  % Example TS field
%                     'range', unpacked{7}, ...
%                     'transducer_depth', unpacked{8}, ...
%                     'quality_flag', unpacked{9} ...
%                 );
% 
%                 disp('Received TS Chirp Datagram:');
%                 disp(datagram);
% 
%                 % Optional: Save to file or process further
%                 % save('ts_data.mat', 'datagram', '-append');
%             end
%         end
%         pause(0.1);  % Avoid tight CPU loop
%     end
% catch ME
%     disp('Error during reception:');
%     disp(ME.message);
% end

% Cleanup
subscriber.close();
context.term();

% % Cleanup
% clear client;
% disp('Disconnected.');

%% Delete subscriptions

% First get all subscription IDs
url = 'http://localhost:12346/api/sounder/data-output/ts-detection-chirp-subscriptions';
% url = 'http://localhost:12346/api/sounder/data-output/ts-detection-subscriptions';
options = weboptions('ContentType', 'json');
try
    subIDs = webread(url, options);
catch ME
    disp('Error:');
    disp(ME.message);
end

% Cycle through and delete each subscription ID
for i = 1:length(subIDs)

    url = ['http://localhost:12346/api/sounder/data-output/ts-detection-chirp-subscriptions/' num2str(subIDs(i).subscription_id)];
    % url = ['http://localhost:12346/api/sounder/data-output/ts-detection-subscriptions/' num2str(subIDs(i).subscription_id)];
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