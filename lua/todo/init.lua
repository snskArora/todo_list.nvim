local M = {}

local line_test1 = {
	"dfccasdfcwdf",
	"---",
	"dfawdsfc",
	"sdfsd",
	"---",
}

local line_test2 = {
	"dfccasdfcwdf",
	"---",
	"dfawdsfc",
	"sdfsd",
	"---",
	"SDFSD",
}

local function create_floating_window(config, enter)
  if enter == nil then
    enter = false
  end

	local width = math.min(math.floor(vim.o.columns * 0.8), 64)
  local height = math.floor(vim.o.lines * 0.8)

	config = config or {
    relative = "editor",
    width = width,
    height = height,
    col = (vim.o.columns - width)/2,
    row = (vim.o.lines - height)/2,
  }

  local buf = vim.api.nvim_create_buf(false, true) -- No file, scratch buffer
  local win = vim.api.nvim_open_win(buf, enter or false, config)

  return { buf = buf, win = win }
end

local get_pages = function (blob)
	local pages = {}
	local current_page = {}
	local cp_line_count = 0
	for _, line in ipairs(blob) do
		if "---" == line then
			table.insert(pages, current_page)
			current_page = {}
			cp_line_count = 0
		else
			table.insert(current_page, line)
			cp_line_count = cp_line_count + 1
		end
	end
	if cp_line_count > 0 then
		table.insert(pages, current_page)
	end
	return pages
end

M.open = function (file_content)
	local pages = get_pages(file_content)
	local float_win = create_floating_window()
	vim.api.nvim_buf_set_lines(float_win.buf, 0, -1, false, pages[1])
end

M.setup = function(opts)
	opts = opts or {}
	M.note_path = opts.path or vim.fn.stdpath('data') .. "/todo"
	M.todo_file_path = M.note_path .. "/todo.md"
end

M.first = function()
	print("one")
	M.setup({path = "/media/sunny/int_drive/github/nvim_todo/dev"})
	M.open(line_test2)
	-- vim.print(get_pages(line_test1))
	-- vim.print(get_pages(line_test2))
end

return M
