```lua
--[[
The OSC library is useful and exists in the built-in libraries on the Core.
All that the OSC library does is decode and encode messages doing the needed null value packing, 
but it does it in a specific format that's kind of annoying to work with.
These functions hopefully help make it easier to use.

The basic OSC library works around an array that might look like:
{ "/oscpath/whatever/you/need", "s", "a string value", "i", 6, "f", 30.5, "s", "more strings"}
which corresponds to an OSC message of:
/oscpath/whatever/you/need "a string value" 6 30.5 "more strings"

With these functions you'd instead do something like:
OSCDevice:send("/oscpath/whatever/you/need", "a string value", 6, 30.5, "more strings")
(Obviously rework as you'd need)

And on receiving an OSC message through the built in decode function, it'll make an object that's a little more useful that might look like this:
osc.addr = "/oscpath/whatever/you/need"
osc.vals = {"a string value", 6, 30.5, "more strings"}


]] --


-- You need the osc library
require("osc")
Core = {}
Core.ip = "192.168.19.201"

-- A handy function to print to console the contents of a table, it's not used here but it helped me troubleshoot a LOT --
function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

-- This translates an incoming OSC message into a table of values --
function translate_osc(packet) 
  local osc_msg = {}

  -- The OSC message is divided into the address (the /whatever/string part) and the values following it
  osc_msg.addr = osc.get_addr_from_data(packet.Data)
  osc_msg.vals = {}
  
  -- The osc.decode_message function is the one in the library that we're feeding
  local decode_Message = osc.decode_message(packet.Data)
  local i = 1
  while i < #decode_Message  do
    -- The decode_message function creates a table of values that list a value type and then the value, here I'm turning that into a more useful table and forcing the number or string types --
    if(decode_Message[i] == "i" || decode_Message[i] == "f") then
      table.insert(osc_msg.vals, tonumber(decode_Message[i+1]))
    elseif (decode_Message[i] == "s") then
      table.insert(osc_msg.vals, tostring(decode_Message[i+1]))
    end
    i = i+2
  end

  -- The return of this function is osc_msg, which has osc_msg.addr, which is just the string of the address, and osc_msg.vals, which is an array of the values, in order
  return osc_msg
end

-- Create a class for the ZoomOSC object (note that for this demo I've removed most of the functions for clarity and brevity) --
OSCDevice = {ip = "127.0.0.1", txport = 9090, rxport = 1234}

-- Creation class that sets default variables and also lets me instate the object more than once if I need to control multiple devices
function OSCDevice:new (o, ip, txport, rxport) 
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  self.ip = ip or "127.0.0.1"
  self.txport = txport or 9090
  self.rxport = rxport or 1234
  self:connect()
  return o
end

-- Do the actual UDP socket connection required for OSC to work --
function OSCDevice:connect()
print("Connecting to ", self.ip, self.txport, self.rxport)
  self.connection = UdpSocket.New();
  -- When you call Open, you pass it the IP of the Core, then the port that the Core will listen back on
  self.connection:Open(Core.ip, self.rxport)

  -- When data is received, handle it. Here I'm translating using the helper function above, then if the address matches a particular one, sending the values into a function built to handle that.
  self.connection.Data = function(udp, packet)
    local osc_data = translate_osc(packet)
    print("Received values for" .. osc_data.addr)
    if osc_data.addr == "/zoomosc/user/videoOn" then
      -- Do something here with the address you're matching
    end
  end
end

-- Send OSC data. This function should be called with the first argument being a string for the address, and then adding the other values as arguments after that.
function OSCDevice:send(...)
  local temp_table = {}
  args = table.pack(...)

  -- This fills out the table that the osc.encode function from the library needs to send --
  for i, j in ipairs(args) do
    if(i == 1) then
      table.insert(temp_table, args[1])
    else
    if (type(j) == "number" and math.floor(j) == j) then
      table.insert(temp_table, "i")
      table.insert(temp_table, j)
    elseif (type(j) == "number") then
      table.insert(temp_table, "f")
      table.insert(temp_table, j)
    else
      table.insert(temp_table, "s")
      table.insert(temp_table, j)
    end
    
  end 
  end

  -- This does the actual encoding --
  local encoded = osc.encode(temp_table)
  print("Sending: "..encoded)

  -- This sends the data down the connection we made earlier --
  self.connection:Send(self.ip, self.txport, encoded)
end


--[Actually start working, this instates the ZoomOSC object and gives it the IPs and ports needed]--
device = OSCDevice:new(nil, "192.168.19.5", 9090, 1234)

-- Syntax for sending a message.
device:send("/zoom/subscribe", 2)

