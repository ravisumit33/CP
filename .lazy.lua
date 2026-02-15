local dap = require("dap")

-- Define a custom function to compile and debug cpp file
local function compile_and_debug()
	local filedir = vim.fn.expand("%:p:h")
	local filename = vim.fn.expand("%:t:r")
	local escaped_filename = filename:gsub("'", "'\\''")
	local filepath = vim.fn.expand("%:p")
	local escaped_filepath = filepath:gsub("'", "'\\''")

	local outname = filedir .. "/" .. filename
	local escaped_outname = filedir .. "/" .. escaped_filename

	-- Compile the current C++ file with debug symbols
	local compile_cmd = "g++-14 -Wall -Wextra -g -std=c++23 -DDEBUG_ENV -I . '"
		.. escaped_filepath
		.. "' -o '"
		.. escaped_outname
		.. "'"

	local compile_args = {
		"-Wall",
		"-Wextra",
		"-g",
		"-std=c++23",
		"-DDEBUG_ENV",
		"-I",
		".",
		escaped_filepath,
		"-o",
		escaped_outname,
	}

	local build_msg_id = "cpp_build_" .. escaped_filename

	-- 1. Create a notification handle
	local notification =
		vim.notify("Building " .. escaped_filename .. "with command: " .. compile_cmd, vim.log.levels.INFO, {
			title = "C++ Build",
			id = build_msg_id,
			keep = function()
				return true
			end, -- Keeps it visible until replaced
		})

	-- Execute the compilation command
	vim.system({ "g++-14", unpack(compile_args) }, { text = true }, function(obj)
		vim.schedule(function()
			if obj.code ~= 0 then
				-- Update notification to Error
				vim.notify("Compilation failed!\n" .. (obj.stderr or ""), vim.log.levels.ERROR, {
					title = "C++ Build",
					id = build_msg_id,
				})
				return
			end

			-- Update notification to Success
			vim.notify("Build successful. Starting debugger...", vim.log.levels.INFO, {
				title = "C++ Build",
				id = build_msg_id,
				timeout = 2000,
			})

			-- Terminate any existing debugging session
			local current_session = dap.session()
			if current_session then
				dap.terminate()
				-- Wait for the session to terminate
				vim.wait(1000, function()
					return not dap.session()
				end)
			end

			-- 4. Launch DAP
			dap.run({
				name = "Debug " .. filename,
				type = "codelldb",
				request = "launch",
				program = outname,
				cwd = filedir,
				stopOnEntry = false,
				setupCommands = {
					{
						text = "-enable-pretty-printing",
						description = "Enable pretty printing",
						ignoreFailures = false,
					},
				},
			})
		end)
	end)
end

-- Create a command that runs the function
vim.api.nvim_create_user_command("BuildAndDebug", compile_and_debug, {})
-- Define the key mapping for BuildAndDebug
vim.api.nvim_set_keymap("n", "<leader>cpd", ":BuildAndDebug<CR>", { noremap = true, silent = true })
-- Define the key mapping for running sample test cases
vim.api.nvim_set_keymap("n", "<leader>cpt", ":CompetiTest run<CR>", { noremap = true, silent = true })
-- Define the key mapping for receiving contest
vim.api.nvim_set_keymap("n", "<leader>cpr", ":CompetiTest receive contest<CR>", { noremap = true, silent = true })
-- Define the key mapping for finding cpp files
vim.api.nvim_set_keymap(
	"n",
	"<leader>cpf",
	"<cmd>lua Snacks.picker.files({ pattern = 'file:cpp$ ' })<CR>",
	{ noremap = true, silent = true }
)

return {
	{
		"xeluxee/competitest.nvim",
		dependencies = "MunifTanjim/nui.nvim",
		config = function()
			require("competitest").setup({
				compile_command = {
					cpp = {
						exec = "g++-14",
						args = {
							"-Wall",
							"-Wextra",
							"-g",
							"-std=c++23",
							"$(FNAME)",
							"-o",
							"$(FNOEXT)",
						},
					},
				},
				template_file = "template.$(FEXT)",
				evaluate_template_modifiers = true,
				received_contests_directory = "$(CWD)/$(JUDGE)",
				received_contests_prompt_directory = false,
				received_contests_prompt_extension = false,
				open_received_contests = false,
				received_problems_path = "$(CWD)/$(JUDGE)/$(PROBLEM).$(FEXT)",
				received_problems_prompt_path = false,
				view_output_diff = true,
			})
		end,
	},
	{
		"rcarriga/nvim-dap-ui",
		config = function(_, opts)
			local dapui = require("dapui")
			dapui.setup(opts)
			dap.listeners.after.event_initialized["dapui_config"] = function()
				dapui.open({})
			end
			dap.listeners.before.event_terminated["dapui_config"] = nil
			dap.listeners.before.event_exited["dapui_config"] = nil
		end,
	},
}
