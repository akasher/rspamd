--[[
Copyright (c) 2017, Veselin Iordanov
Copyright (c) 2018, Vsevolod Stakhov <vsevolod@highsecure.ru>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
]]--

local rspamd_logger = require 'rspamd_logger'
local rspamd_http = require "rspamd_http"
local rspamd_lua_utils = require "lua_util"
local util = require "rspamd_util"
local ucl = require "ucl"
local hash = require "rspamd_cryptobox_hash"
local rspamd_redis = require "lua_redis"
local upstream_list = require "rspamd_upstream_list"

if confighelp then
  return
end

local rows = {}
local nrows = 0
local elastic_template
local redis_params
local N = "elastic"
local E = {}
local connect_prefix = 'http://'
local enabled = true
local settings = {
  limit = 10,
  index_pattern = 'rspamd-%Y.%m.%d',
  template_file = rspamd_paths['PLUGINSDIR'] .. '/elastic/rspamd_template.json',
  kibana_file = rspamd_paths['PLUGINSDIR'] ..'/elastic/kibana.json',
  key_prefix = 'elastic-',
  expire = 3600,
  failover = false,
  import_kibana = false,
  use_https = false,
}

local function read_file(path)
    local file = io.open(path, "rb")
    if not file then return nil end
    local content = file:read "*a"
    file:close()
    return content
end

local function elastic_send_data(task)
  local es_index = os.date(settings['index_pattern'])
  local tbl = {}
  for _,value in pairs(rows) do
    table.insert(tbl, '{ "index" : { "_index" : "'..es_index..
        '", "_type" : "logs" ,"pipeline": "rspamd-geoip"} }')
    table.insert(tbl, ucl.to_format(value, 'json-compact'))
  end

  local upstream = settings.upstream:get_upstream_round_robin()
  local ip_addr = upstream:get_addr():to_string(true)

  local push_url = connect_prefix .. ip_addr .. '/'..es_index..'/_bulk'
  local bulk_json = table.concat(tbl, "\n")
  local function http_index_data_callback(_, code, body, _)
    -- todo error handling we may store the rows it into redis and send it again late
    rspamd_logger.debugm(N, task, "After create data %1", body)
    if code ~= 200 then
      if settings['failover'] then
        local h = hash.create()
        h:update(bulk_json)
        local key = settings['key_prefix'] ..es_index..":".. h:base32():sub(1, 20)
        local data = util.zstd_compress(bulk_json)
        local function redis_set_cb(err)
          if err ~=nil then
            rspamd_logger.errx(task, 'redis_set_cb received error: %1', err)
          end
        end
        rspamd_redis.make_request(task,
          redis_params, -- connect params
          key, -- hash key
          true, -- is write
          redis_set_cb, --callback
          'SETEX', -- command
          {key, tostring(settings['expire']), data} -- arguments
        )
      end
    end
  end
  rspamd_http.request({
    url = push_url,
    headers = {
      ['Content-Type'] = 'application/x-ndjson',
    },
    body = bulk_json,
    task = task,
    method = 'post',
    callback = http_index_data_callback
  })

end
local function get_general_metadata(task)
  local r = {}
  local ip_addr = task:get_ip()
  r.ip = tostring(ip_addr) or 'unknown'
  r.webmail = false
  if ip_addr  then
    r.is_local = ip_addr:is_local()
    local origin = task:get_header('X-Originating-IP')
    if origin then
        r.webmail = true
        r.ip = origin
    end
  end
  r.direction = "Inbound"
  r.user = task:get_user() or 'unknown'
  r.qid = task:get_queue_id() or 'unknown'
  r.action = task:get_metric_action('default')
  if r.user ~= 'unknown' then
      r.direction = "Outbound"
  end
  local s = task:get_metric_score('default')[1]
  r.score =  s

  local rcpt = task:get_recipients('smtp')
  if rcpt then
    local l = {}
    for _, a in ipairs(rcpt) do
      table.insert(l, a['addr'])
    end
      r.rcpt = l
  else
    r.rcpt = 'unknown'
  end
  local from = task:get_from('smtp')
  if ((from or E)[1] or E).addr then
    r.from = from[1].addr
  else
    r.from = 'unknown'
  end
  local syminf = task:get_symbols_all()
  r.symbols = syminf
  r.asn = {}
  local pool = task:get_mempool()
  r.asn.country = pool:get_variable("country") or 'unknown'
  r.asn.asn   = pool:get_variable("asn") or 0
  r.asn.ipnet = pool:get_variable("ipnet") or 'unknown'
  local function process_header(name)
    local hdr = task:get_header_full(name)
    if hdr then
      local l = {}
      for _, h in ipairs(hdr) do
        table.insert(l, h.decoded)
      end
      return l
    else
      return 'unknown'
    end
  end
  r.header_from = process_header('from')
  r.header_to = process_header('to')
  r.header_subject = process_header('subject')
  r.header_date = process_header('date')
  r.message_id = task:get_message_id()
  return r
end

local function elastic_collect(task)
  if not enabled then return end
  if rspamd_lua_utils.is_rspamc_or_controller(task) then return end
  local row = {['rspam_meta'] = get_general_metadata(task),
    ['@timestamp'] = tostring(util.get_time() * 1000)}
  table.insert(rows, row)
  nrows = nrows + 1
  if nrows > settings['limit'] then
    elastic_send_data(task)
    nrows = 0
    rows = {}
  end
end


local opts = rspamd_config:get_all_opt('elastic')

local function check_elastic_server(cfg, ev_base, _)
  local upstream = settings.upstream:get_upstream_round_robin()
  local ip_addr = upstream:get_addr():to_string(true)

  local plugins_url = connect_prefix .. ip_addr .. '/_nodes/plugins'
  local function http_callback(_, _, body, _)
    local parser = ucl.parser()
    local res,err = parser:parse_string(body)
    if not res then
        rspamd_logger.infox(rspamd_config, 'failed to parse reply from %s: %s',
          plugins_url, err)
        enabled = false;
        return
    end
    local obj = parser:get_object()
    for node,value in pairs(obj['nodes']) do
      local plugin_found = false
      for _,plugin in pairs(value['plugins']) do
        if plugin['name'] == 'ingest-geoip' then
          plugin_found = true
        end
      end
      if not plugin_found then
        rspamd_logger.infox(rspamd_config,
          'Unable to find ingest-geoip on %1 node, disabling module', node)
        enabled = false
        return
      end
    end
  end
  rspamd_http.request({
    url = plugins_url,
    ev_base = ev_base,
    config = cfg,
    method = 'get',
    callback = http_callback
  })
end

-- import ingest pipeline and kibana dashboard/visualization
local function initial_setup(cfg, ev_base, worker)
  if not (worker:get_name() == 'controller' and worker:get_index() == 0) then return end

  local upstream = settings.upstream:get_upstream_round_robin()
  local ip_addr = upstream:get_addr():to_string(true)
  if enabled then
    -- create ingest pipeline
    local geoip_url = connect_prefix .. ip_addr ..'/_ingest/pipeline/rspamd-geoip'
    local function geoip_cb(_, code, _, _)
      if code ~= 200 then
        rspamd_logger.errx('cannot get data from %s: %s', geoip_url, code)
        enabled = false
      end
    end
    rspamd_http.request({
      url = geoip_url,
      ev_base = ev_base,
      config = cfg,
      callback = geoip_cb,
      body = '{"description" : "Add geoip info for rspamd","processors" : [{"geoip" : {"field" : "rspam_meta.ip","target_field": "rspam_meta.geoip"}}]}',
      method = 'put',
    })
    -- create template mappings if not exist
    local template_url = connect_prefix .. ip_addr ..'/_ingest/pipeline/rspamd-geoip'
    local function http_template_put_callback(_, code, _, _)
      if code ~= 200 then
        rspamd_logger.errx('cannot put template to %s: %s', template_url, code)
        enabled = false
      end
    end
    local function http_template_exist_callback(_, code, _, _)
      if code ~= 200 then
        rspamd_http.request({
          url = template_url,
          ev_base = ev_base,
          config = cfg,
          body = elastic_template,
          method = 'put',
          callback = http_template_put_callback,
        })
      end
    end

    rspamd_http.request({
      url = template_url,
      ev_base = ev_base,
      config = cfg,
      method = 'head',
      callback = http_template_exist_callback
    })
    -- add kibana dashboard and visualizations
    if enabled and settings['import_kibana'] then
        local kibana_mappings = read_file(settings['kibana_file'])
        if kibana_mappings then
          local parser = ucl.parser()
          local res,err = parser:parse_string(kibana_mappings)
          if not res then
            rspamd_logger.infox(rspamd_config, 'kibana template cannot be parsed: %s',
              err)
            enabled = false

            return
          end
          local obj = parser:get_object()
          local tbl = {}
          for _,item in ipairs(obj) do
            table.insert(tbl, '{ "index" : { "_index" : ".kibana", "_type" : "'..
                item["_type"]..'" ,"_id": "'..
                item["_id"]..'"} }')
            table.insert(tbl, ucl.to_format(item['_source'], 'json-compact'))
          end

          local kibana_url = connect_prefix .. ip_addr ..'/.kibana/_bulk'
          local function kibana_template_callback(_, code, _, _)
            if code ~= 200 then
              rspamd_logger.errx('cannot put template to %s: %s', kibana_url, code)
              enabled = false
            end
          end
          rspamd_http.request({
            url = kibana_url,
            ev_base = ev_base,
            config = cfg,
            headers = {
              ['Content-Type'] = 'application/x-ndjson',
            },
            body = table.concat(tbl, "\n"),
            method = 'post',
            callback = kibana_template_callback
          })
        else
          rspamd_logger.infox(rspamd_config, 'kibana templatefile not found')
        end
    end
  end
end

redis_params = rspamd_redis.parse_redis_server('elastic')

if redis_params and opts then
  for k,v in pairs(opts) do
    settings[k] = v
  end

  if not settings['server'] and not settings['servers'] then
    rspamd_logger.infox(rspamd_config, 'no servers are specified, disabling module')
    rspamd_lua_utils.disable_module(N, "config")
  else
    if settings.use_https then
      connect_prefix = 'https://'
    end

    settings.upstream = upstream_list.create(rspamd_config,
      settings['server'] or settings['servers'], 9200)

    if not settings.upstream then
      rspamd_logger.errx('cannot parse elastic address: %s',
        settings['server'] or settings['servers'])
      rspamd_lua_utils.disable_module(N, "config")
      return
    end
    if not settings['template_file'] then
      rspamd_logger.infox(rspamd_config, 'elastic template_file is required, disabling module')
      rspamd_lua_utils.disable_module(N, "config")
      return
    end

    elastic_template = read_file(settings['template_file']);
    if not elastic_template then
      rspamd_logger.infox(rspamd_config, 'elastic unable to read %s, disabling module',
        settings['template_file'])
      rspamd_lua_utils.disable_module(N, "config")
      return
    end

    rspamd_config:register_symbol({
      name = 'ELASTIC_COLLECT',
      type = 'idempotent',
      callback = elastic_collect,
      priority = 10
    })

    rspamd_config:add_on_load(function(cfg, ev_base,worker)
      if worker:is_scanner() then
        check_elastic_server(cfg, ev_base, worker) -- check for elasticsearch requirements
        initial_setup(cfg, ev_base, worker) -- import mappings pipeline and visualizations
      end
    end)
  end

end
