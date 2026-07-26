module("luci.controller.mhxy_block", package.seeall)

function index()
	local fs = require "nixio.fs"

	if not fs.access("/etc/config/mhxy_block") then
		return
	end

	entry(
		{"admin", "services", "appfilter", "mhxy_block"},
		cbi("appfilter/mhxy_block"),
		_("梦幻西游拦截（测试）"),
		28
	).leaf = true
end
