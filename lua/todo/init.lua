local M = {}

M.max_win_height = math.floor(vim.o.lines * 0.8)

local function create_floating_window(buf, config)
	config = config or {
    -- relative = "win",
    relative = "editor",
    width = math.floor(vim.o.columns * 0.8),
    height = math.floor(vim.o.lines * 0.8),
    col = math.floor(vim.o.columns * 0.1),
    row = math.floor(vim.o.lines * 0.1),
		-- bufpos = {5,5},
		border = "rounded"
  }

	if not buf then
		buf = vim.api.nvim_create_buf(false, true) -- No file, scratch buffer
	end
  local win = vim.api.nvim_open_win(buf, true, config)

  return {buf = buf, win = win}
end

local save = function ()
	local content = ""
	for _, page in ipairs(M.pages) do
		content = content .. "#" .. page.title .. "\n"
		for _, line in ipairs(page.content) do
			content = content .. line .. "\n"
		end
		content = content .. "---" .. "\n"
	end
	local file = io.open(M.note_path, "w")
	file:write(content)
	file:close()
end

---@param self string
function string:split(delimiter)
    local result = {}
    local from = 1
    local delim_from, delim_to = string.find(self, delimiter, from)
    while delim_from do
        table.insert(result, string.sub(self, from, delim_from - 1))
        from = delim_to + 1
        delim_from, delim_to = string.find(self, delimiter, from)
    end
    table.insert(result, string.sub(self, from))
    return result
end

local get_pages = function (blob)
	local pages = {}
	local current_page = {}
	local current_title = ""
	local cp_line_count = 0
	local total_pages = 0
	for line in blob:gmatch("[^\r\n]+") do
		if "---" == line then
			table.insert(pages, {title = current_title, content = current_page, len = cp_line_count})
			current_page = {}
			cp_line_count = 0
			total_pages = total_pages + 1
		else
			local heading_detected = string.find(line, "#") == 1
			if cp_line_count ==  0 then
				if heading_detected then
					line = line:gsub("^#", "")
					current_title = line
					cp_line_count = 1
				else
					current_title = string.format("Page %d", total_pages+1)
					cp_line_count = 1
				end
			end
			-- table.insert(current_page, line)
			-- cp_line_count = cp_line_count + 1
			if not heading_detected then
				table.insert(current_page, line)
				cp_line_count = cp_line_count + 1
			end
		end
	end
	if cp_line_count > 0 then
		table.insert(pages, {title = current_title, content = current_page, len = cp_line_count})
		total_pages = total_pages + 1
	end
	return {pages = pages, count = total_pages}
end

---@param write_to_file boolean
local set_content = function (write_to_file)
	local win_height = M.pages[M.current_page].len
	if win_height < 3 then
		win_height = 3
	elseif win_height > M.max_win_height then
		win_height = M.max_win_height
	end
	vim.api.nvim_buf_set_option(M.bufnr, "modifiable", true)
	vim.api.nvim_buf_set_lines(M.bufnr, 0, -1, false, M.pages[M.current_page].content)
	vim.api.nvim_buf_set_option(M.bufnr, "modifiable", false)
	vim.api.nvim_win_set_config(M.win, { height = 2 + win_height, title = "  " .. M.pages[M.current_page].title , footer = string.format(" %d of %d  -- todo list  ", M.current_page, M.total_pages), footer_pos = "right" })
	vim.bo[M.bufnr].filetype = "markdown"
	if save then
		save()
	end
end

---@param num integer
M.jump_to_page = function (num)
	if num > M.total_pages then
		vim.print("Toal number pages availble are ", M.total_pages, " got input to open page number ", num)
		return
	end
	M.current_page = num
	set_content(false)
end

---@param file_content string
M.open = function (file_content)
	-- local file_content = data:split("\n")
	local pages = get_pages(file_content)
	M.pages = pages.pages
	local x = create_floating_window(M.bufnr)
	M.bufnr, M.win = x.buf, x.win
	vim.bo[M.bufnr].swapfile = false
	M.total_pages = pages.count
	set_content(false)
	M.todo_open = true
	-- vim.api.nvim_create_autocmd("BufLeave", {
	--    buffer = M.bufnr,
	--    callback = function()
	-- 		vim.print(vim.api.nvim_buf_get_lines(M.bufnr, 0, -1, false))
	--    end,
	--  })
end

M.remove_task = function ()
	local row, _ = unpack(vim.api.nvim_win_get_cursor(M.win))
	table.remove(M.pages[M.current_page].content, row)
	M.pages[M.current_page].len = M.pages[M.current_page].len - 1
	set_content(true)
end

M.mark_undone = function ()
	local row, _ = unpack(vim.api.nvim_win_get_cursor(M.win))
	M.pages[M.current_page].content[row] =	M.pages[M.current_page].content[row]:gsub("%- %[x%]", "- [ ]", 1)
	set_content(true)
end

M.mark_done = function ()
	local row, _ = unpack(vim.api.nvim_win_get_cursor(M.win))
	M.pages[M.current_page].content[row] =	M.pages[M.current_page].content[row]:gsub("%- %[ %]", "- [x]", 1)
	set_content(true)
end

M.close = function ()
	vim.api.nvim_win_close(M.win, true)
	M.win = nil
	M.todo_open = false
	save()
end

---@param placeholder string|nil
---@param win_cfg table|nil
---@param on_confirm function | nil
---@param args table|nil
local get_input = function (placeholder, win_cfg, on_confirm, args)
	local c = win_cfg or {
    relative = "editor",
    width = math.floor(vim.o.columns * 0.5),
    height = 1,
    col = math.floor(vim.o.columns * 0.25),
    row = math.floor(vim.o.lines * 0.5),
		style = "minimal",
		border = "rounded"
	}
	local x = create_floating_window(nil, c)

	vim.api.nvim_buf_set_option(x.buf, "modifiable", true)
	if placeholder then
		vim.api.nvim_buf_set_lines(x.buf, 0, -1, false, {placeholder})
	end
	vim.api.nvim_buf_set_keymap(x.buf, "i", "<CR>", "", {
    nowait = true,
    noremap = true,
    silent = true,
    callback = function()
      local lines = vim.api.nvim_buf_get_lines(x.buf, 0, -1, false)
      local input = table.concat(lines, "\n")
      vim.api.nvim_win_close(x.win, true)
      vim.api.nvim_buf_delete(x.buf, {force = true})
			if on_confirm then
        on_confirm(input, args)
      end
			vim.cmd("stopinsert")
    end,
  })
	vim.api.nvim_set_current_win(x.win)
	vim.cmd("startinsert!")
end

M.update_page_name = function ()
	get_input(nil, nil, function(input)
    if input and input ~= "" then
      M.pages[M.current_page].title = input
      set_content()
    end
  end)
end

M.add_task = function ()
	local row, col = unpack(vim.api.nvim_win_get_cursor(M.win))
	vim.print(row, col)
	local c = {
    relative = "win",
    width = math.floor(vim.o.columns * 0.5),
    height = 1,
    col = col + 2,
    row = row,
		style = "minimal",
		border = "rounded",
		title = "type out the new task"
	}
	local line_content = M.pages[M.current_page].content[row]
	local _, fe = string.find(line_content, "^%s*%- %[.%] ")
	local prefix = ""
	if fe then
		prefix = string.sub(line_content, 1, fe)
	else
		prefix = "- [ ] "
	end
	local vars = {row = row, prefix = prefix}
	get_input(nil, c, function(input, args)
		if input and input ~= "" then
			table.insert(M.pages[M.current_page].content, args.row+1 ,args.prefix .. input)
			M.pages[M.current_page].len = M.pages[M.current_page].len + 1
			set_content(true)
		end
	end, vars)
end

M.update_task = function ()
	local row, _ = unpack(vim.api.nvim_win_get_cursor(M.win))
	local line_content = M.pages[M.current_page].content[row]
	local _, fe = string.find(line_content, "^%s*%- %[.%] ")
	local prefix = ""
	if fe then
		prefix = string.sub(line_content, 1, fe)
	end
	local vars = {row_num = row, prefix = prefix}
	get_input(string.sub(line_content, fe+1), nil, function(input, args)
    if input and input ~= "" then
      M.pages[M.current_page].content[args.row_num] = args.prefix .. input
      set_content(true)
    end
  end, vars)
end

M.next_page = function ()
	if M.todo_open ~= true then
		vim.print("TODO page not open")
		return
	end
	if M.current_page >= M.total_pages then
		M.current_page = 1
	else
		M.current_page = M.current_page + 1
	end
	set_content(false)
end

M.prev_page = function ()
	if M.todo_open ~= true then
		vim.print("TODO page not open")
		return
	end
	if M.current_page <= 1 then
		M.current_page = M.total_pages
	else
		M.current_page = M.current_page - 1
	end
	set_content(false)
end

M.setup = function(opts)
	opts = opts or {}
	M.note_path = opts.path .. "/todo.md" or vim.fn.stdpath('data') .. "/todo/todo.md"
	M.current_page = 1
	M.todo_file_path = M.note_path .. "/todo.md"
end

M.first = function()
	M.setup({path = "/media/sunny/int_drive/github/nvim_todo/dev"})
	local file = io.open(M.note_path, "r")
	local content = ""
	if file then
		content = file:read("*aL")
		file:close()
	else
		content = ""
	end
 	M.open(content)
end

return M
