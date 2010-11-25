% ========================================================================
%> @brief LABJACK Connects and manages a LabJack U3-HV
%>
%> Connects and manages a LabJack U3-HV
%>
% ========================================================================
classdef labJack < handle
	
	properties
		name='LabJack'
		%> silentMode allows one to call methods without needing a labJack
		silentMode = 0
		%> header needed by loadlib
		header = '/usr/local/include/labjackusb.h'
		%> the library itself
		library = '/usr/local/lib/liblabjackusb'
		%> how much detail to show 
		verbosity = 1
		%> allows the constructor to run the open method immediately
		openNow = 1 
	end
	
	properties (SetAccess = private, GetAccess = public)
		deviceID = 3
		functions
		version
		devCount
		handle = []
		isOpen = 0
		inp = []
		fio4 = 0
		fio5 = 0
	end
	
	properties (SetAccess = private, GetAccess = private)
		fio4High = hex2dec(['1d'; 'f8'; '03'; '00'; '20'; '01'; '00'; '0d'; '84'; '0b'; '84'; '00'])';
		fio5High = hex2dec(['1f'; 'f8'; '03'; '00'; '22'; '01'; '00'; '0d'; '85'; '0b'; '85'; '00'])';
		fio4Low  = hex2dec(['9c'; 'f8'; '03'; '00'; 'a0'; '00'; '00'; '0d'; '84'; '0b'; '04'; '00'])';
		fio5Low  = hex2dec(['9e'; 'f8'; '03'; '00'; 'a2'; '00'; '00'; '0d'; '85'; '0b'; '05'; '00'])';
		ledIsON  = hex2dec(['05'; 'f8'; '02'; '00'; '0a'; '00'; '00'; '09'; '01'; '00']);
		ledIsOFF = hex2dec(['04'; 'f8'; '02'; '00'; '09'; '00'; '00'; '09'; '00'; '00']);
		vHandle = 0
		allowedPropertiesBase='^(name|silentMode|verbosity|openNow|header|library)$'
	end
	
	%=======================================================================
	methods %------------------PUBLIC METHODS
	%=======================================================================
	
		% ===================================================================
		%> @brief Class constructor
		%>
		%> More detailed description of what the constructor does.
		%>
		%> @param args are passed as a structure of properties which is
		%> parsed.
		%> @return instance of labJack class.
		% ===================================================================
		function obj = labJack(args)
			if nargin>0 && isstruct(args)
				if nargin>0 && isstruct(args)
					fnames = fieldnames(args); %find our argument names
					for i=1:length(fnames);
						if regexp(fnames{i},obj.allowedPropertiesBase) %only set if allowed property
							obj.salutation(fnames{i},'Configuring property in LabJack constructor');
							obj.(fnames{i})=args.(fnames{i}); %we set up the properies from the arguments as a structure
						end
					end
				end
			end
			if regexp(obj.name,'null') %we were deliberately passed null, means go into silent mode
				obj.silentMode = 1;
			end
			if obj.openNow==1
				obj.open
			end
		end
		
		% ===================================================================
		%> @brief Open the LabJack device
		%>
		%> Open the LabJack device
		% ===================================================================
		function open(obj)
			if obj.silentMode==0
				if ~libisloaded('liblabjackusb')
					loadlibrary(obj.library,obj.header);
				end
				obj.functions = libfunctions('liblabjackusb', '-full');
				obj.version =  calllib('liblabjackusb','LJUSB_GetLibraryVersion');
				obj.devCount = calllib('liblabjackusb','LJUSB_GetDevCount',obj.deviceID);
				obj.handle = calllib('liblabjackusb','LJUSB_OpenDevice',1,0,obj.deviceID);
				obj.validHandle;
				if obj.vHandle
					obj.isOpen = 1;
					obj.salutation('open method','LabJack succesfully opened...');
					obj.setFIO4(0);
					obj.setFIO5(0);
				else
					obj.salutation('open method','LabJack open failed, going into silent mode');
					obj.isOpen = 0;
					obj.handle = [];
					obj.silentMode = 1; %we switch into silent mode just in case someone tries to use the object
				end
			else
				obj.isOpen = 0;
				obj.handle = [];
				obj.vHandle = 0;
				obj.silentMode = 1; %double make sure it is set to 1 exactly
			end
		end
		
		% ===================================================================
		%> @brief Close the LabJack device
		%>	void LJUSB_CloseDevice(HANDLE hDevice);
		%>	//Closes the handle of a LabJack USB device.
		% ===================================================================
		function close(obj)
			if ~isempty(obj.handle) && obj.silentMode==0
				obj.validHandle; %double-check we still have valid handle
				if obj.vHandle && ~isempty(obj.handle)
					calllib('liblabjackusb','LJUSB_CloseDevice',obj.handle);
				end
				%obj.validHandle;
				obj.isOpen = 0;
				obj.handle=[];
				obj.vHandle = 0;
				obj.salutation('close method',['Closed handle: ' num2str(obj.vHandle)]);
			else
				obj.salutation('close method',['No handle to close: ' num2str(obj.vHandle)]);
			end
		end
		
		% ===================================================================
		%> @brief Is Handle Valid?
		%>	bool LJUSB_IsHandleValid(HANDLE hDevice);
		%>	//Is handle valid.
		% ===================================================================
		function validHandle(obj)
			if obj.silentMode == 0
				if ~isempty(obj.handle)
					obj.vHandle = calllib('liblabjackusb','LJUSB_IsHandleValid',obj.handle);
					if obj.vHandle
						obj.salutation('validHandle Method','VALID Handle');
					else
						obj.salutation('validHandle Method','INVALID Handle');
					end
				else
					obj.vHandle = 0;
					obj.isOpen = 0;
					obj.handle = [];
					obj.salutation('validHandle Method','INVALID Handle');
				end
			end
		end
		
		% ===================================================================
		%> @brief Write formatted command string to LabJack
		%> 		unsigned long LJUSB_Write(HANDLE hDevice, BYTE *pBuff, unsigned long count);
		%> 		// Writes to a device. Returns the number of bytes written, or -1 on error.
		%> 		// hDevice = The handle for your device
		%> 		// pBuff = The buffer to be written to the device.
		%> 		// count = The number of bytes to write.
		%> 		// This function replaces the deprecated LJUSB_BulkWrite, which required the endpoint
		%>
		%> @param byte The raw hex encoded command packet to send
		% ===================================================================
		function out = rawWrite(obj,byte)
			out = calllib('liblabjackusb', 'LJUSB_Write', obj.handle, byte, length(byte));
		end
		
		% ===================================================================
		%> @brief Write formatted command string to LabJack
		%> 		unsigned long LJUSB_Read(HANDLE hDevice, BYTE *pBuff, unsigned long count);
		%> 		// Reads from a device. Returns the number of bytes read, or -1 on error.
		%> 		// hDevice = The handle for your device
		%> 		// pBuff = The buffer to filled in with bytes from the device.
		%> 		// count = The number of bytes expected to be read.
		%> 		// This function replaces the deprecated LJUSB_BulkRead, which required the endpoint
		%>
		%> @param bytein
		%> @param count
		% ===================================================================
		function in = rawRead(obj,bytein,count)
			if ~exist('count','var')
				count = length(bytein);
			end
			in =  calllib('liblabjackusb', 'LJUSB_Read', obj.handle, bytein, count);
		end
		
		%===============LED ON================%
		function ledON(obj)
			if obj.silentMode == 0 && obj.vHandle == 1
				out = obj.rawWrite(obj.ledIsON);
				in  = obj.rawRead(obj.inp);
			end
		end
			
		%===============LED OFF================%
		function ledOFF(obj)
			if obj.silentMode == 0 && obj.vHandle == 1
				out = obj.rawWrite(obj.ledIsOFF);
				in  = obj.rawRead(obj.inp);
			end
		end
		
		%===============STROBE WORD================%
		function strobeWord(obj,val)
			
		end
		%===============SET FIO4================%
		function setFIO4(obj,val)
			if obj.silentMode == 0 && obj.vHandle == 1
				if ~exist('val','var')
					val = abs(obj.fio4-1);
				end
				if val == 1
					out = obj.rawWrite(obj.fio4High);
					in  = obj.rawRead(obj.inp);
					obj.fio4 = 1;
					obj.salutation('SETFIO4','FIO4 is HIGH')
				else
					out = obj.rawWrite(obj.fio4Low);
					in  = obj.rawRead(obj.inp);
					obj.fio4 = 0;
					obj.salutation('SETFIO4','FIO4 is LOW')
				end
			end
		end
		
		%===============Toggle FIO4======================%
		function toggleFIO4(obj)
			if obj.silentMode == 0 && obj.vHandle == 1
				obj.fio4=abs(obj.fio4-1);
				obj.setFIO4(obj.fio4);
			end
		end
		
		%===============SET FIO5================%
		function setFIO5(obj,val)
			if obj.silentMode == 0 && obj.vHandle == 1
				if ~exist('val','var')
					val = abs(obj.fio5-1);
				end
				if val == 1
					out = calllib('liblabjackusb', 'LJUSB_Write', obj.handle, obj.fio5High, 12);
					in =  calllib('liblabjackusb', 'LJUSB_Read', obj.handle, obj.inp, 10);
					obj.fio5 = 1;
					obj.salutation('SETFIO5','FIO5 is HIGH')
				else
					out = calllib('liblabjackusb', 'LJUSB_Write', obj.handle, obj.fio5Low, 12);
					in =  calllib('liblabjackusb', 'LJUSB_Read', obj.handle, obj.inp, 10);
					obj.fio5 = 0;
					obj.salutation('SETFIO5','FIO5 is LOW')
				end
			end
		end
		
		%===============Toggle FIO5======================%
		function toggleFIO5(obj)
			if obj.silentMode == 0 && obj.vHandle == 1
				obj.fio5=abs(obj.fio5-1);
				obj.setFIO5(obj.fio5);
			end
		end
		
		%===============RESET======================%
		function reset(obj,resetType)
			if ~exist('resetType','var')
				resetType = 0;
			end
			cmd(1) = 0;
			cmd(2) = hex2dec('99'); %command code
			if resetType == 0 %soft reset
				cmd(3) = bin2dec('01');
			else
				cmd(3) = bin2dec('10');
			end
			cmd(4) = 0;
			
			cmd(1) = obj.checksum8(cmd(2:end));
			cmd
		end
		
	end
	
	methods ( Static )
		
		function chk = checksum8(in)
			if ischar(in) %hex input
				in = hex2dec(in);
				hexMode = 1;
			end
			in = sum(uint16(in));
			quo = floor(in/2^8);
			remd = rem(in,2^8);
			in = quo+remd;
			quo = floor(in/2^8);
			remd = rem(in,2^8);
			chk = quo + remd;
			if exist('hexMode','var')
				chk = dec2hex(chk);
			end
		end
		
		function [lsb,msb] = checksum16(in)
			if ischar(in) %hex input
				in = hex2dec(in);
				hexMode = 1;
			end
			in = sum(uint16(in));
			lsb=bitand(in,255);
			msb=bitshift(in,-8);
			if exist('hexMode','var')
				lsb = dec2hex(lsb);
				msb = dec2hex(msb);
			end
		end
		
	end
	
	methods ( Access = private ) %----------PRIVATE METHODS---------%
		
		%===============Destructor======================%
		function delete(obj)
			obj.salutation('DELETE Method','Cleaning up...')
			obj.close;
		end
		
		%===========Salutation==========%
		function salutation(obj,in,message)
			if obj.verbosity > 0
				if ~exist('in','var')
					in = 'General Message';
				end
				if exist('message','var')
					fprintf([message ' | ' in '\n']);
				else
					fprintf(['\nHello from ' obj.name ' | labJack\n\n']);
				end
			end
		end
	end
end