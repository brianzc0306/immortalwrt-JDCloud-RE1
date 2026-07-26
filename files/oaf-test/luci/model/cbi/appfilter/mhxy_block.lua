local sys = require "luci.sys"

local m = Map(
	"mhxy_block",
	translate("梦幻西游拦截（测试）"),
	translate("根据 RE-CS-07 实机抓包生成的临时 nftables 规则，与 FW4 共存。规则仅作用于目标 IPv4；服务器地址变化后可能失效，也可能影响该设备上的其他网易服务。本页不会停止 Nikki，也不会修改 HNAT、ECM 或 Flow Offloading 设置。")
)

local s = m:section(NamedSection, "main", "global", translate("拦截设置"))
s.addremove = false
s.anonymous = true

local enabled = s:option(Flag, "enabled", translate("启用拦截"))
enabled.rmempty = false

local device_ip = s:option(Value, "device_ip", translate("目标设备 IPv4"))
device_ip.datatype = "ip4addr"
device_ip.rmempty = false
device_ip.placeholder = "192.168.0.215"
device_ip.description = translate("请先在 DHCP 中为设备绑定固定地址。启用或修改后，请彻底退出并重新启动游戏，以建立受新规则控制的连接。")

local state = s:option(DummyValue, "_state", translate("运行状态"))
function state.cfgvalue()
	if sys.call("nft list table inet mhxy_block >/dev/null 2>&1") == 0 then
		return translate("已启用")
	end

	return translate("已关闭")
end

local counters = s:option(DummyValue, "_counters", translate("命中计数"))
function counters.cfgvalue()
	local output = sys.exec("nft list chain inet mhxy_block forward 2>/dev/null | sed -n 's/.*counter packets \\([0-9][0-9]*\\) bytes \\([0-9][0-9]*\\).*/\\1 包，\\2 字节/p'")
	output = (output or ""):gsub("%s+$", "")

	if output == "" then
		return translate("暂无")
	end

	return output:gsub("\n", "；")
end

function m.on_after_commit()
	sys.call("/etc/init.d/mhxy-block restart >/dev/null 2>&1")
end

return m
