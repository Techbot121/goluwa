if CLIENT then
	if not ZEROBRANE then
		message.AddListener("print", function(line)
			logn("server >> ", line)
		end)
	end
end

if SERVER then
	event.AddListener("ReplPrint", "epoe", function(line)
		-- THIS is bad
		line = line:gsub("\n", "")

		-- don't network chat
		if line:find("%d%d:%d%d") then return end

		message.Broadcast("print", line)
	end)
end