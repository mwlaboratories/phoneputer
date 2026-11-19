# Neovim (`nvim`), set up with Nixvim: https://nix-community.github.io/nixvim/
# Stylix gives it the phone's colours.

{ ... }:

{
  programs.nixvim = {
    enable = true;
    defaultEditor = true;

    plugins = {
      lualine.enable = true;     # status line
      lazygit.enable = true;     # :LazyGit
      noice.enable = true;       # nicer command line and messages
      neoscroll.enable = true;   # smooth scrolling
      web-devicons.enable = true;
      telescope = {              # fuzzy finder
        enable = true;
        keymaps."<C-p>" = "git_files"; # Ctrl-P: files in this git repo
      };
      harpoon.enable = true;     # pin files and jump between them
    };

    keymaps = [
      {
        # Ctrl-A: add this file to harpoon
        mode = "n";
        key = "<C-a>";
        action.__raw = "function() require'harpoon':list():add() end";
      }
      {
        # Ctrl-;: harpoon's list of files
        mode = "n";
        key = "<C-;>";
        action.__raw = "function() require'harpoon'.ui:toggle_quick_menu(require'harpoon':list()) end";
      }
    ];

    # Copy and paste through the system clipboard (Wayland)
    clipboard = {
      register = "unnamedplus";
      providers.wl-copy.enable = true;
    };

    opts = {
      number = true;        # line numbers
      incsearch = true;     # search while typing
      wrap = false;         # no word wrap
      autoread = true;      # reload files changed outside nvim
      # Draw the cursor in nvim's own colours, so it stays visible on the
      # dark background.
      termguicolors = true;
      guicursor = "n-v-c-sm:block-Cursor,i-ci-ve:ver25-Cursor,r-cr-o:hor20-Cursor,t:block-blinkon500-blinkoff500-TermCursor";
    };

    extraConfigLua = ''
      -- Check for changes made outside nvim every 500 ms
      local timer = vim.uv.new_timer()
      timer:start(500, 500, vim.schedule_wrap(function()
        if vim.fn.getcmdwintype() == "" then
          vim.cmd("checktime")
        end
      end))

      -- Smooth half-page scrolling with PageUp/PageDown
      local neoscroll = require('neoscroll')
      vim.keymap.set({'n', 'v', 'x'}, '<PageUp>', function() neoscroll.ctrl_u({ duration = 150 }) end)
      vim.keymap.set({'n', 'v', 'x'}, '<PageDown>', function() neoscroll.ctrl_d({ duration = 150 }) end)
    '';
  };
}
