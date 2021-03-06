classdef sendSerial < optickaCore
	%SENDSERIAL Connects and manages Serial port communication
	%   Connects and manages Serial port communication
	properties
		port					= ''
		board					= ''
		silentMode		= false %this allows us to be called even if no serial port is attached
		verbose				= true
	end
	properties (SetAccess = private, GetAccess = public)
		device
		deviceID
		availablePins
	end
	properties (SetAccess = private, GetAccess = private)
		allowedProperties='silentMode|verbose'
	end
	methods%------------------PUBLIC METHODS--------------%
		
		%==============CONSTRUCTOR============%
		function obj = sendSerial(varargin)
			if nargin>0
				obj.parseArgs(varargin,obj.allowedProperties);
			end
		end
		
		%===============OPEN DEVICE================%
		function open(obj)
			if obj.silentMode==0 && ~isa(obj.device,'arduino')
				try
					if ~isempty(obj.port)
						obj.device = arduino(obj.port);
					else
						obj.device = arduino;
					end
					obj.deviceID = obj.device.Port;
					obj.availablePins = obj.device.AvailablePins;
					
					for i = 2:13
						configurePin(obj.device,['D' num2str(i)],'unset')
						writeDigitalPin(obj.device,['D' num2str(i)],0);
					end
				catch ME
					fprintf('\n\nCouldn''t open Arduino, try a valid name')
					rethrow(ME)
				end
			end
		end
		
		%===============SEND================%
		function sendTTL(obj, line, time)
			if obj.silentMode==0
				writeDigitalPin(obj.device,['D' num2str(line)],1);
				WaitSecs(time);
				writeDigitalPin(obj.device,['D' num2str(line)],0);
			end
		end
		
		%===============CLOSE PORT================%
		function close(obj)
			if isa(obj.device,'arduino')
				obj.device = [];
				obj.deviceID = '';
				obj.availablePins = '';
			end
		end
		
	end
	
	
	methods ( Access = private ) %----------PRIVATE METHODS---------%
		%===========Delete Method==========%
		function delete(obj)
			fprintf('sendSerial Delete method will automagically close connection if open...\n');
			obj.close;
		end
		
	end
	
end