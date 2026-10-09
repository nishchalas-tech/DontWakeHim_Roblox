--[[
	AnalyticsService.luau
	Telemetry and event tracking foundation.
--]]

local AnalyticsService = {}
local eventLog = {}

function AnalyticsService.TrackEvent(eventName: string, data: table?)
	local record = {
		Event = eventName,
		Timestamp = os.time(),
		Data = data or {},
	}
	table.insert(eventLog, record)
	print("[ANALYTICS]", eventName, data and game:GetService("HttpService"):JSONEncode(data) or "")
end

function AnalyticsService.GetLogs()
	return eventLog
end

return AnalyticsService
