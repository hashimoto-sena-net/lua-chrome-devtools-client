require("chrome-devtools-client")
require("postgresql-client")

local connect_ip = "localhost"
local connect_port = "9222"

local client = Client:new()
client:connect(connect_ip, connect_port)
xml = client:convert_html_to_xml(arg[2])
client:close()

local pgclient = PGClient:new()
pgclient:save_xml(arg[1], xml, arg[2])
