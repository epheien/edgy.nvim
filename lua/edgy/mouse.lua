local Config = require("edgy.config")

local M = {}

---@class Edgy.Mouse.Opts
---@field enabled? boolean

local namespace = vim.api.nvim_create_namespace("edgy_mouse")
local keycodes = {
  press = vim.api.nvim_replace_termcodes("<LeftMouse>", true, false, true),
  drag = vim.api.nvim_replace_termcodes("<LeftDrag>", true, false, true),
  release = vim.api.nvim_replace_termcodes("<LeftRelease>", true, false, true),
}

---@class Edgy.Mouse.Drag
---@field edgebar Edgy.Edgebar
---@field tab tabpage
---@field last_col integer
---@field size integer
---@field started boolean

---@type Edgy.Mouse.Drag?
local drag

---@param edgebar Edgy.Edgebar
---@param row integer
---@param col integer
local function on_edge(edgebar, row, col)
  for _, win in ipairs(edgebar.wins) do
    if win:is_valid() then
      local info = vim.fn.getwininfo(win.win)[1]
      if info then
        local boundary = edgebar.pos == "left" and info.wincol + info.width or info.wincol - 1
        local bottom = info.winrow + info.winbar + info.height
        if col == boundary and row >= info.winrow and row < bottom then
          return true
        end
      end
    end
  end
  return false
end

---@param mouse table
---@return Edgy.Edgebar?
local function get_edgebar(mouse)
  -- On a statusline or separator, getmousepos() reports line and column as 0.
  if mouse.line ~= 0 or mouse.column ~= 0 then
    return
  end
  for _, pos in ipairs({ "left", "right" }) do
    local edgebar = Config.layout[pos]
    if edgebar and on_edge(edgebar, mouse.screenrow, mouse.screencol) then
      return edgebar
    end
  end
end

---@param edgebar Edgy.Edgebar
---@return integer?
local function get_width(edgebar)
  for _, win in ipairs(edgebar.wins) do
    if win:is_valid() then
      return vim.api.nvim_win_get_width(win.win)
    end
  end
end

---@param edgebar Edgy.Edgebar
local function clear_window_sizes(edgebar)
  for _, win in ipairs(edgebar.wins) do
    if win:is_valid() then
      vim.w[win.win].edgy_width = nil
    end
  end
end

---@param key string
local function on_key(key)
  if key == keycodes.press then
    local mouse = vim.fn.getmousepos()
    local edgebar = get_edgebar(mouse)
    local size = edgebar and get_width(edgebar) or nil
    drag = size
        and {
          edgebar = edgebar,
          tab = vim.api.nvim_get_current_tabpage(),
          last_col = mouse.screencol,
          size = size,
          started = false,
        }
      or nil
  elseif key == keycodes.drag and drag then
    local edgebar = drag.edgebar
    if Config.layout[edgebar.pos] ~= edgebar or vim.api.nvim_get_current_tabpage() ~= drag.tab then
      drag = nil
      return
    end

    local col = vim.fn.getmousepos().screencol
    local delta = col - drag.last_col
    drag.last_col = col
    if delta == 0 then
      return
    end

    if not drag.started then
      clear_window_sizes(edgebar)
      edgebar:set_user_size(drag.size, drag.tab)
      drag.started = true
    end
    if edgebar.pos == "right" then
      delta = -delta
    end
    local size = edgebar:get_user_size(drag.tab) or drag.size
    edgebar:set_user_size(math.max(size + delta, 1), drag.tab)
  elseif key == keycodes.release and drag then
    drag = nil
  end
end

---@param opts? Edgy.Mouse.Opts
function M.setup(opts)
  opts = opts or {}
  drag = nil
  vim.on_key(nil, namespace)
  if opts.enabled ~= false then
    vim.on_key(on_key, namespace)
  end
end

return M
