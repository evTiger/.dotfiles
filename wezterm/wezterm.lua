local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- Windowsのホームディレクトリパスとユーザー名を動的に取得
local win_home = wezterm.home_dir
local win_user = win_home:match("[^\\]+$") or "default"

config.automatically_reload_config = true
config.default_domain = 'WSL:Ubuntu'
config.launch_menu = {
    -- PowerShell (通常)
    {
        label = "PowerShell",
        args = { "pwsh.exe" },
        domain = { DomainName = "local" },
    },

    -- JAVA演習
    {
        label = "Java26 BYOD",
        args = {
            [[C:\oit\java26-byod\PortableGit-2.55.0.3-64\usr\bin\bash.exe]],
            "--login",
            "-i",
        },
        domain = { DomainName = "local" },
	cwd = [[C:\Users\81806\oithomes\java\kadai\java26]],
    },

    -- Windows Terminal PowerShell (管理者)
    {
        label = "Windows Terminal PowerShell (Admin)",
        args = {
            "powershell.exe",
            "-NoLogo",
            "-Command",
            "Start-Process wt.exe -Verb RunAs -ArgumentList 'new-tab pwsh.exe'"
        },
        domain = { DomainName = "local" },
    },

    -- Command Prompt (通常)
    {
        label = "Command Prompt",
        args = { "cmd.exe" },
        domain = { DomainName = "local" },
    },

    -- Windows Terminal CMD (管理者)
    {
        label = "Windows Terminal CMD (Admin)",
        args = {
            "powershell.exe",
            "-NoLogo",
            "-Command",
            "Start-Process wt.exe -Verb RunAs -ArgumentList 'new-tab cmd.exe'"
        },
        domain = { DomainName = "local" },
    },
}

config.font_size = 17.0
config.use_ime = true

config.color_scheme = 'Gruvbox dark, medium (base16)' -- Dracula+
config.font = wezterm.font('Cica')

config.window_background_opacity = 0.8
-- config.win32_system_backdrop = 'Acrylic'

config.window_decorations = "INTEGRATED_BUTTONS|RESIZE"
config.window_frame = {
    inactive_titlebar_bg = "none",
    active_titlebar_bg = "none",
    font_size = 11.0,
}

config.inactive_pane_hsb = {
    saturation = 1.0,
    brightness = 0.6,
}

config.window_background_gradient = {
    colors = { "#222222" },
}

----------- タブバーの見た目設定 -----------
config.show_new_tab_button_in_tab_bar = false
config.show_close_tab_button_in_tabs = false
-- config.show_tabs_in_tab_bar = false
config.tab_max_width = 100

config.colors = {
    tab_bar = {
        inactive_tab_edge = "none",
    },
    split = '#282828',
}

local SOLID_LEFT_ARROW = wezterm.nerdfonts.ple_lower_right_triangle
local SOLID_RIGHT_ARROW = wezterm.nerdfonts.ple_upper_left_triangle


-- WSLパスから.gitを遡って検索する関数
local function find_git_root_wsl(wsl_path)
    local current = wsl_path
    while current and current ~= "/" and current ~= "" do
        local win_path
        if current:find("^/mnt/c/") then
            win_path = "C:" .. current:sub(7):gsub("/", "\\")
        else
            win_path = "\\\\wsl.localhost\\Ubuntu" .. current:gsub("/", "\\")
        end

        local f = io.open(win_path .. "\\.git\\HEAD", "r")
        if f then
            f:close()
            return current
        end
        local parent = current:match("(.*)/[^/]+$")
        if parent == "" then parent = "/" end
        if parent == current then break end
        current = parent
    end
    return nil
end

-- 要件に基づいたディレクトリタイトルを生成する関数
local function get_display_title(wsl_path)
    local path = wsl_path:gsub("/+$", "")
    if path == "" then return "/" end

    -- 【動的抽出】WSLのパスからユーザー名を自動で抜き出す (/home/xxx/ の xxx 部分)
    local wsl_user = path:match("^/home/([^/]+)")
    local wsl_home_path = wsl_user and ("/home/" .. wsl_user) or nil
    local win_home_wsl_path = "/mnt/c/Users/" .. win_user

    -- WSL側ホームディレクトリ自体の場合は「~」を返す
    if path == wsl_home_path then
        return "~"
    end

    -- Windows側ホームディレクトリ自体の場合はユーザー名をそのまま返す
    if path == win_home_wsl_path then
        return win_user
    end

    local git_root = find_git_root_wsl(path)
    local title_result = ""
    
    if git_root then
        local parent = git_root:match("(.*)/[^/]+$") or ""
        if parent ~= "" then
            title_result = path:sub(#parent + 2)
        else
            title_result = path:sub(2)
        end
    else
        local current_name = path:match("[^/]+$") or "/"
        local parent = path:match("(.*)/[^/]+$") or ""
        local parent_name = parent:match("[^/]+$") or "/"
        if parent == "" then
            title_result = current_name
        else
            title_result = parent_name .. "/" .. current_name
        end
    end

    -- WSLのユーザー名のみ「~/」に置換（Windows側は「~/」に置換しない）
    if wsl_user then
        title_result = title_result:gsub("^" .. wsl_user .. "/", "~/")
    end
    
    return title_result
end

wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
    local background = "#5c6d74"
    local foreground = "#FFFFFF"
    local edge_background = "none"
    if tab.is_active then
        background = "#ae8b2d"
        foreground = "#FFFFFF"
    end

    local edge_foreground = background

    local pane_id = tab.active_pane.pane_id
    local current_working_dir = tab.active_pane.current_working_dir

    if current_working_dir then
        local wsl_path = current_working_dir.path
        local path_key = "snc_path_" .. tostring(pane_id)
        local title_key = "snc_title_" .. tostring(pane_id)

        if wsl_path and wsl_path ~= wezterm.GLOBAL[path_key] then
            wezterm.GLOBAL[path_key] = wsl_path
            wezterm.GLOBAL[title_key] = get_display_title(wsl_path)
        end
    end

    -- フラットな文字列キーからタイトルを取得（SNC関連のアイコン記述は削除）
    local title_key = "snc_title_" .. tostring(pane_id)
    local title_text = wezterm.GLOBAL[title_key] or tab.active_pane.title

    local title = "   " .. title_text .. "   "

    return {
        { Background = { Color = edge_background } },
        { Foreground = { Color = edge_foreground } },
        { Text = SOLID_LEFT_ARROW },
        { Background = { Color = background } },
        { Foreground = { Color = foreground } },
        { Text = title },
        { Background = { Color = edge_background } },
        { Foreground = { Color = edge_foreground } },
        { Text = SOLID_RIGHT_ARROW },
    }
end)

----------- Ctrl + Shift + Z 用関数 -----------
local function apply_zoom_style(window, is_zoomed)
    if is_zoomed then
        local dims = window:get_dimensions()
        local thickness = dims.pixel_width * 0.0125

        window:set_config_overrides({
            window_frame = {
                active_titlebar_bg = 'none',
                inactive_titlebar_bg = 'none',
                border_left_width = thickness,
                border_right_width = thickness,
                border_top_height = thickness,
                border_bottom_height = thickness,
                border_left_color = 'rgba(0,0,0,0.5)',
                border_right_color = 'rgba(0,0,0,0.5)',
                border_top_color = 'rgba(0,0,0,0.5)',
                border_bottom_color = 'rgba(0,0,0,0.5)',
            },
        })
    else
        window:set_config_overrides({})
    end
end

local function is_tab_zoomed(tab)
    if not tab then return false end
    for _, p in ipairs(tab:panes_with_info()) do
        if p.is_zoomed then
            return true
        end
    end
    return false
end

-- マウス操作や定期同期イベント
wezterm.on("update-status", function(window, pane)
    local tab = window:active_tab()
    local tab_id = tab and tostring(tab:tab_id()) or "default"
    
    -- Wezterm自体のズーム、またはtmux側のズームのどちらかが有効ならパディングをつける
    local wezterm_zoomed = is_tab_zoomed(tab)
    local tmux_zoomed = wezterm.GLOBAL["tmux_zoom_" .. tab_id] == "1"

    apply_zoom_style(window, wezterm_zoomed or tmux_zoomed)
end)

-- tmux等からのOSC 1337 (SetUserVar) シーケンスを受け取るリスナー
wezterm.on("user-var-changed", function(window, pane, name, value)
    if name == "TMUX_ZOOM" then
        local tab = window:active_tab()
        if tab then
            local tab_id = tostring(tab:tab_id())
            -- タブごとにtmuxのズーム状態を記憶する
            wezterm.GLOBAL["tmux_zoom_" .. tab_id] = value
            
            -- 即座にスタイルに反映
            local wezterm_zoomed = is_tab_zoomed(tab)
            apply_zoom_style(window, wezterm_zoomed or (value == "1"))
        end
    end
end)


----------- マウス選択時に勝手にクリップボードへコピーしない設定 -----------
config.mouse_bindings = {
    -- シングル左クリック：選択のコピーはせず、リンクがあれば開くだけ
    {
        event = { Up = { streak = 1, button = 'Left' } },
        mods = 'NONE',
        action = wezterm.action.OpenLinkAtMouseCursor,
    },
    {
        event = { Up = { streak = 1, button = 'Left' } },
        mods = 'SHIFT',
        action = wezterm.action.OpenLinkAtMouseCursor,
    },
    -- ダブルクリック（単語選択）・トリプルクリック（行選択）も同様にコピーしない
    {
        event = { Up = { streak = 2, button = 'Left' } },
        mods = 'NONE',
        action = wezterm.action.Nop,
    },
    {
        event = { Up = { streak = 3, button = 'Left' } },
        mods = 'NONE',
        action = wezterm.action.Nop,
    },
}

----------- キー割り当て -----------
config.keys = {
    -- =================================================================
    -- 1. WezTerm 本体の操作 (修飾キー: CTRL, CTRL+SHIFT)
    -- =================================================================
    -- Ctrl + C : 選択中ならコピー、未選択なら SIGINT を送信
    {
        key = 'c',
        mods = 'CTRL',
        action = wezterm.action_callback(function(window, pane)
            local selectiontext = window:get_selection_text_for_pane(pane)
            if selectiontext ~= "" then
                window:perform_action(wezterm.action.CopyTo 'Clipboard', pane)
            else
                window:perform_action(wezterm.action.SendKey { key = 'c', mods = 'CTRL' }, pane)
            end
        end),
    },

    -- Ctrl + V : クリップボードから貼り付け
    { key = 'v', mods = 'CTRL', action = wezterm.action.PasteFrom 'Clipboard' },

    -- Ctrl + Shift + P : ランチャーメニューを開く
    {
        key = 'p',
        mods = 'CTRL|SHIFT',
        action = wezterm.action.ShowLauncherArgs {
            flags = 'LAUNCH_MENU_ITEMS',
        },
    },

    -- Ctrl + Shift + | : ペインを左右に分割
    {
        key = '|',
        mods = 'CTRL|SHIFT',
        action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' },
    },

    -- Ctrl + Shift + _ : ペインを上下に分割
    {
        key = '_',
        mods = 'CTRL|SHIFT',
        action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' },
    },

    -- Ctrl + Shift + X : 現在のペインを確認付きで閉じる
    {
        key = 'x',
        mods = 'CTRL|SHIFT',
        action = wezterm.action_callback(function(window, pane)
            local pane_id = pane:pane_id()
            wezterm.GLOBAL["snc_title_" .. tostring(pane_id)] = nil
            wezterm.GLOBAL["snc_path_" .. tostring(pane_id)] = nil
            window:perform_action(wezterm.action.CloseCurrentPane { confirm = true }, pane)
        end),
    },

    -- Ctrl + Shift + Z : ペインのズーム状態を切り替え
    {
        key = 'z',
        mods = 'CTRL|SHIFT',
        action = wezterm.action_callback(function(window, pane)
            local tab = window:active_tab()
            local currently_zoomed = is_tab_zoomed(tab)
            apply_zoom_style(window, not currently_zoomed)
            window:perform_action(wezterm.action.TogglePaneZoomState, pane)
        end),
    },

    -- Ctrl + Shift + hjkl : ペイン移動
    { key = 'h', mods = 'CTRL|SHIFT', action = wezterm.action.ActivatePaneDirection 'Left' },
    { key = 'j', mods = 'CTRL|SHIFT', action = wezterm.action.ActivatePaneDirection 'Down' },
    { key = 'k', mods = 'CTRL|SHIFT', action = wezterm.action.ActivatePaneDirection 'Up' },
    { key = 'l', mods = 'CTRL|SHIFT', action = wezterm.action.ActivatePaneDirection 'Right' },

    -- Ctrl + Shift + 矢印キー : ペインのリサイズ
    { key = 'LeftArrow',  mods = 'CTRL|SHIFT', action = wezterm.action.AdjustPaneSize { 'Left', 5 } },
    { key = 'RightArrow', mods = 'CTRL|SHIFT', action = wezterm.action.AdjustPaneSize { 'Right', 5 } },
    { key = 'UpArrow',    mods = 'CTRL|SHIFT', action = wezterm.action.AdjustPaneSize { 'Up', 5 } },
    { key = 'DownArrow',  mods = 'CTRL|SHIFT', action = wezterm.action.AdjustPaneSize { 'Down', 5 } },

    -- Ctrl + Shift + { or } : ペイン入れ替え
    { key = '{', mods = 'CTRL|SHIFT', action = wezterm.action.PaneSelect { mode = 'SwapWithActive' } },
    { key = '}', mods = 'CTRL|SHIFT', action = wezterm.action.PaneSelect { mode = 'SwapWithActive' } },


    -- =================================================================
    -- 2. リモート tmux への操作委譲 (修飾キー: CTRL+ALT)
    -- =================================================================
    -- Ctrl + Alt + T : 新規ウィンドウ作成
    { key = 't', mods = 'CTRL|ALT', action = wezterm.action.SendKey { key = 't', mods = 'CTRL|ALT' } },

    -- Ctrl + Alt + D : セッションからデタッチ
    { key = 'd', mods = 'CTRL|ALT', action = wezterm.action.SendKey { key = 'd', mods = 'CTRL|ALT' } },

    -- Ctrl + Alt + | : 左右分割
    { key = '|', mods = 'CTRL|ALT', action = wezterm.action.SendKey { key = '|', mods = 'CTRL|ALT' } },

    -- Ctrl + Alt + _ : 上下分割
    { key = '-', mods = 'CTRL|ALT', action = wezterm.action.SendKey { key = '_', mods = 'CTRL|ALT' } },

    -- Ctrl + Alt + X : 現在のペインを閉じる
    { key = 'x', mods = 'CTRL|ALT', action = wezterm.action.SendKey { key = 'x', mods = 'CTRL|ALT' } },

    -- Ctrl + Alt + W : 現在のウィンドウを閉じる
    { key = 'w', mods = 'CTRL|ALT', action = wezterm.action.SendKey { key = 'w', mods = 'CTRL|ALT' } },

    -- Ctrl + Alt + S : セッション一覧を表示
    { key = 's', mods = 'CTRL|ALT', action = wezterm.action.SendKey { key = 's', mods = 'CTRL|ALT' } },

    -- Ctrl + Alt + C : コピーモードに入る
    { key = 'c', mods = 'CTRL|ALT', action = wezterm.action.SendKey { key = 'c', mods = 'CTRL|ALT' } },

    -- Ctrl + Alt + Z : ペインをズーム
    { key = 'z', mods = 'CTRL|ALT', action = wezterm.action.SendKey { key = 'z', mods = 'CTRL|ALT' } },

    -- Ctrl + Alt + A : 横に分割してAntigravity CLI (agy) を起動
    {
        key = 'a',
        mods = 'CTRL|ALT',
        action = wezterm.action.SplitHorizontal { 
            domain = 'CurrentPaneDomain',
            args = { 'zsh', '-ic', 'agy' },
        },
    },

    -- Ctrl + Alt + hjkl : ペイン移動
    { key = 'h', mods = 'CTRL|ALT', action = wezterm.action.SendKey { key = 'h', mods = 'CTRL|ALT' } },
    { key = 'j', mods = 'CTRL|ALT', action = wezterm.action.SendKey { key = 'j', mods = 'CTRL|ALT' } },
    { key = 'k', mods = 'CTRL|ALT', action = wezterm.action.SendKey { key = 'k', mods = 'CTRL|ALT' } },
    { key = 'l', mods = 'CTRL|ALT', action = wezterm.action.SendKey { key = 'l', mods = 'CTRL|ALT' } },

    -- Ctrl + Alt + 矢印キー : ペインのリサイズ
    { key = 'LeftArrow',  mods = 'CTRL|ALT', action = wezterm.action.SendKey { key = 'LeftArrow', mods = 'CTRL|ALT' } },
    { key = 'RightArrow', mods = 'CTRL|ALT', action = wezterm.action.SendKey { key = 'RightArrow', mods = 'CTRL|ALT' } },
    { key = 'UpArrow',    mods = 'CTRL|ALT', action = wezterm.action.SendKey { key = 'UpArrow', mods = 'CTRL|ALT' } },
    { key = 'DownArrow',  mods = 'CTRL|ALT', action = wezterm.action.SendKey { key = 'DownArrow', mods = 'CTRL|ALT' } },

    -- Ctrl + Alt + { or } : ペイン入れ替え
    { key = '{', mods = 'CTRL|ALT', action = wezterm.action.SendKey { key = '{', mods = 'CTRL|ALT' } },
    { key = '}', mods = 'CTRL|ALT', action = wezterm.action.SendKey { key = '}', mods = 'CTRL|ALT' } },

    -- Ctrl + Alt + 0~9 : ウィンドウのダイレクト切り替え (プレフィックス透過)
    { key = '0', mods = 'CTRL|ALT', action = wezterm.action.SendString "\x020" },
    { key = '1', mods = 'CTRL|ALT', action = wezterm.action.SendString "\x021" },
    { key = '2', mods = 'CTRL|ALT', action = wezterm.action.SendString "\x022" },
    { key = '3', mods = 'CTRL|ALT', action = wezterm.action.SendString "\x023" },   
    { key = '4', mods = 'CTRL|ALT', action = wezterm.action.SendString "\x024" },
    { key = '5', mods = 'CTRL|ALT', action = wezterm.action.SendString "\x025" },
    { key = '6', mods = 'CTRL|ALT', action = wezterm.action.SendString "\x026" },
    { key = '7', mods = 'CTRL|ALT', action = wezterm.action.SendString "\x027" },
    { key = '8', mods = 'CTRL|ALT', action = wezterm.action.SendString "\x028" },
    { key = '9', mods = 'CTRL|ALT', action = wezterm.action.SendString "\x029" },
}

return config
