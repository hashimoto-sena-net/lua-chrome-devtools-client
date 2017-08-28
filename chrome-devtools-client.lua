local chrome_devtools = {}

local http = require ("socket.http")
local ltn12 = require("ltn12")
local json = require("cjson")
local websocket = require("http.websocket")
local url = require("socket.url")

-- Client Class
Client = {}
function Client.http_connect(url)
  local http_response = {}
  local response,response_code,response_header =
    http.request{
      url = url,
      sink = ltn12.sink.table(http_response),
    }
  return http_response
end

function Client.get_ws_url(connect_ip, connect_port, http_response)
  local ws_url =
    json.decode(http_response[1])[1]["webSocketDebuggerUrl"]
  if string.match(ws_url, connect_ip..":"..connect_port) == nil then
    ws_url = string.gsub(ws_url, connect_ip, connect_ip..":"..connect_port)
  end
  return ws_url
end

function Client.ws_connect(ws_url)
  local ws = websocket.new_from_uri(ws_url)
  assert(ws:connect())
  return ws
end

function Client.connect(self, connect_ip, connect_port)
  if connect_port == nil then
    connect_port = 9222
  end
  local http_response =
    self.http_connect("http://"..connect_ip..":"..connect_port.."/json")
  local ws_url = self.get_ws_url(connect_ip, connect_port, http_response)
  local ws_connection = self.ws_connect(ws_url)
  self.connection = ws_connection
  self.connect_ip = connect_ip
  self.connect_port = connect_port
end

function Client.convert_html_to_xml(self, html_url)
  local reconnect_ip = self.connect_ip
  local reconnect_port = self.connect_port

  html_url = "file://"..html_url
  self:page_navigate(html_url)
  self:close()
  self:connect(reconnect_ip, reconnect_port)

  local command = {
    id = 0,
    method = "Runtime.evaluate",
    params = {
      expression =
        "new XMLSerializer().serializeToString(document)"
    }
  }
  local response =
    self.send_command(self.connection, command)
  xml = response.result.result.value
  return xml
end

function Client.page_navigate(self, page_url)
  local command = {
      id = 0,
      method = "Page.enable"
  }
  self.send_command(self.connection, command)

  command = {
    id = 0,
    method = "Page.navigate",
    params = {
      url = page_url
    }
  }
  self.send_command(self.connection, command)
  socket.sleep(1)
end

function Client.send_command(ws, command)
  command = json.encode(command)
  assert(ws:send(command))
  local response = assert(ws:receive())
  return json.decode(response)
end

function Client.close(self)
  assert(self.connection:close())
end

function Client.new(self)
  local object = {}
  setmetatable(object, object)
  object.__index = self
  object.connection = nil
  object.connect_ip = nil
  object.connect_port = nil
  return object
end
