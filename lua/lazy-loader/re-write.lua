local M = {}

local vim = vim
----------------------------------------------------------------------
--                        lazy loader utils                         --
----------------------------------------------------------------------
local packer = require("packer")
local packer_plugins = _G.packer_plugins

----------------------------------------------------------------------
--                             Re-write                             --
----------------------------------------------------------------------
local function load_plugin(plugin)
	if packer_plugins[plugin.name] and not packer_plugins[plugin.name].enable then
		-- load the user configuration
		if plugin.before_load and plugin.before_load.config then
			plugin.before_load.config()
		end
		if plugin.del_augroup then
			vim.api.nvim_del_augroup_by_name("lazy_load_" .. plugin.name)
		end
		-- add the package this is important else you won't be able to
		-- execute the command from command line for this plugin's you lazy loaded
		vim.cmd("silent! packadd " .. plugin.name)
		packer.loader(plugin.name)
	elseif packer_plugins[plugin.name] and packer_plugins[plugin.name].enable then
		if plugin.del_augroup then
			vim.api.nvim_del_augroup_by_name("lazy_load_" .. plugin.name)
		end
	else
		return
	end

	-- load the user configuration
	if plugin.on_load and plugin.on_load.config then
		plugin.on_load.config()
	end

	-- execute event if provided in the on_load.event
	if plugin.on_load and plugin.on_load.event then
		vim.schedule(function()
			vim.cmd("silent! do " .. plugin.on_load.event)
		end)
	end

	vim.schedule(function()
		-- a little trick to trigger the reload the buffer after the plugin is loaded
		vim.cmd("silent! do BufEnter")
	end)
end

local api = vim.api
local events = { "BufRead", "BufWinEnter", "BufNewFile" }

local function register_event(plugin)
	-- pattern for the autocmd if provided
	local pattern = nil
	if plugin.ft then
		-- filetype as a pattern
		pattern = plugin.ft
	elseif plugin.ft_ext then
		-- filetype extension can also be used as a pattern
		pattern = "*." .. plugin.ft_ext
	end

	api.nvim_create_autocmd(plugin.events or plugin.event or events, {
		group = api.nvim_create_augroup("lazy_load_" .. plugin.name, { clear = true }),
		pattern = pattern,
		callback = function()
			if plugin.autocmd.keymap then
				-- TODO: plugin keymap loader
			else
				load_plugin(plugin)
			end
		end,
	})
end

-- TODO: add a autocmd for BufEnter so that if the autocmd.ft_ext is provided
-- only add mapping to the buffer files with this pattern
-- to add the mappings

local function set_key(key, plugin)
	vim.keymap.set(key.mode, key.bind, function()
		-- Important: need to delete this map before the plugin loading because now the mappings
		-- for plugin will be loaded
		vim.keymap.del(key.mode, key.bind)

		load_plugin(plugin)
		if plugin.on_load.cmd then
			-- need to schedule_wrap this else some cmds will be executed before even the
			-- plugin is loaded properly
			vim.schedule_wrap(function()
				vim.cmd(plugin.on_load.cmd)
			end)
		end

		local extra = ""
		while true do
			local c = vim.fn.getchar(0)
			if c == 0 then
				break
			end
			extra = extra .. vim.fn.nr2char(c)
		end

		local prefix = vim.v.count ~= 0 and vim.v.count or ""
		prefix = prefix .. "\"" .. vim.v.register
		if vim.fn.mode("full") == "no" then
			if vim.v.operator == "c" then
				prefix = "" .. prefix
			end
			prefix = prefix .. vim.v.operator
		end

		vim.fn.feedkeys(prefix, "n")

		local escaped_keys = vim.api.nvim_replace_termcodes(key.bind .. extra, true, true, true)
		vim.api.nvim_feedkeys(escaped_keys, "m", true)
	end, key.opts or { noremap = true, silent = true })
end

-- TODO: if the attach_on_event is true then add an autocmd which with
-- the event name of the plugin then register an event with the same name
-- with this plugin name in callback function of the autocmd for this
-- plugin autocmd register

-- TODO: add something like keys_on_event so that the mappings should be added
-- after a certain event like on filetype

----------------------------------------------------------------------
--                         Autocmd Register                         --
----------------------------------------------------------------------
function M.autocmd_register(tbl)
	local autocmd = tbl.autocmd
	-- to provide the name of the plugin in the register_event function
	autocmd.name = tbl.name
	-- to provide the file type if provided by the plugin
	if tbl.ft then
		autocmd.ft = tbl.ft
	elseif tbl.ft_ext then
		autocmd.ft_ext = tbl.ft_ext
	end
	-- register the event
	register_event(autocmd)
end

----------------------------------------------------------------------
--                          Keymap Loader                           --
----------------------------------------------------------------------
function M.keymap_register(tbl)
	local keymap = tbl.keymap
	-- tbl needed for keymap register
	local plugin = {
		name = tbl.name,
		del_augroup = tbl.del_augroup,
		on_load = tbl.on_load,
		before_load = tbl.before_load,
		keys = keymap.keys,
	}

	if keymap and keymap.keys then
		local keys = keymap.keys
		for _, k in pairs(keys) do
			local mode = "n"
			local bind = k
			if type(k) == "table" then
				mode = k[1]
				bind = k[2]
			end
			local keybind = { mode = mode, bind = bind, opts = { noremap = true, silent = true } }
			set_key(keybind, plugin)
		end
	end
end

return M
