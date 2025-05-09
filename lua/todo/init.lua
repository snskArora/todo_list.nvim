local M = {}

local function create_floating_window(config)
	local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)

	config = config or {
    relative = "win",
    -- relative = "editor",
    width = width,
    height = height,
    col = (vim.o.columns - width)/2,
    row = (vim.o.lines - height)/2,
		border = "rounded"
  }

  local buf = vim.api.nvim_create_buf(false, true) -- No file, scratch buffer
  local win = vim.api.nvim_open_win(buf, true, config)

  return { buf = buf, win = win }
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
	for _, line in ipairs(blob) do
		if "---" == line then
			table.insert(pages, {title = current_title, content = current_page})
			current_page = {}
			cp_line_count = 0
			total_pages = total_pages + 1
		else
			local heading_detected = string.find(line, "#") == 1
			if cp_line_count ==  0 then
				if heading_detected then
					line:gsub("^#+", "")
					current_title = line
				else
					current_title = string.format("Page %d", total_pages+1)
				end
			end
			table.insert(current_page, line)
			cp_line_count = cp_line_count + 1
	end
end
if cp_line_count > 0 then
	table.insert(pages, current_page)
	total_pages = total_pages + 1
end
return {pages = pages, count = total_pages}
end

local set_content = function ()
	vim.api.nvim_buf_set_option(M.bufnr, "modifiable", true)
	vim.api.nvim_buf_set_lines(M.bufnr, 0, -1, false, M.pages[M.current_page].content)
	vim.api.nvim_win_set_config(M.win, { title = "  " .. M.pages[M.current_page].title , footer = string.format(" %d of %d  -- todo list  ", M.current_page, M.total_pages), footer_pos = "right" })
	vim.bo[M.bufnr].filetype = "markdown"
	vim.api.nvim_buf_set_option(M.bufnr, "modifiable", false)
end

---@param num integer
M.jump_to_page = function (num)
	if num > M.total_pages then
		vim.print("Toal number pages availble are ", M.total_pages, " got input to open page number ", num)
		return
	end
	M.current_page = num
	set_content()
end

---@param data string
M.open = function (data)
	local file_content = data:split("\n")
	local pages = get_pages(file_content)
	M.pages = pages.pages
	local float_win = create_floating_window()
	M.bufnr = float_win.buf
	M.win = float_win.win
	vim.bo[M.bufnr].swapfile = false
	M.total_pages = pages.count
	set_content()
	M.todo_open = true
	-- vim.api.nvim_create_autocmd("BufLeave", {
	--    buffer = M.bufnr,
	--    callback = function()
	-- 		vim.print(vim.api.nvim_buf_get_lines(M.bufnr, 0, -1, false))
	--    end,
	--  })
end

M.t = function ()
	local row, _ = unpack(vim.api.nvim_win_get_cursor(M.win))
	vim.print("current line ", row)
end

M.close = function ()

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
	set_content()
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
	set_content()
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
	else
		content = ""
	end
 	M.open(content)
end

return M
