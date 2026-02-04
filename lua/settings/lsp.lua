vim.lsp.config["lua_ls"] = {
	cmd = { "lua-language-server" },
	filetypes = { "lua" },
	root_markers = { ".git" },
}

vim.lsp.enable("lua_ls")

vim.lsp.config["intelephense"] = {
  cmd = { "intelephense", "--stdio" },
  filetypes = { "php" },
  root_markers = { ".git", "composer.json" },
}

vim.lsp.enable("intelephense")

local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities.textDocument.completion.completionItem.snippetSupport = true

vim.lsp.config["cssls"] = {
  capabilities = capabilities,
  cmd = { "vscode-css-language-server", "--stdio" },
  filetypes = { "css", "scss", "less" },
  init_options = { provideFormatter = true },
  settings = {
    css = { validate = true },
    less = { validate = true },
    scss = { validate = true },
  },
}

vim.lsp.enable("cssls")

vim.lsp.config["ts_ls"] = {
  cmd = { "typescript-language-server", "--stdio" },
  commands = {
    ['editor.action.showReferences'] = function(command, ctx)
      local client = assert(vim.lsp.get_client_by_id(ctx.client_id))
      local file_uri, position, references = unpack(command.arguments)

      local quickfix_items = vim.lsp.util.locations_to_items(references --[[@as any]], client.offset_encoding)
      vim.fn.setqflist({}, ' ', {
        title = command.title,
        items = quickfix_items,
        context = {
          command = command,
          bufnr = ctx.bufnr,
        },
      })

      vim.lsp.util.show_document({
        uri = file_uri --[[@as string]],
        range = {
          start = position --[[@as lsp.Position]],
          ['end'] = position --[[@as lsp.Position]],
        },
      }, client.offset_encoding)
      ---@diagnostic enable: assign-type-mismatch

      vim.cmd('botright copen')
    end,
  },
  filetypes = {
    "javascript",
    "javascriptreact",
    "javascript.jsx",
    "typescript",
    "typescriptreact",
    "typescript.tsx",
  },
  handlers = {
    -- handle rename request for certain code actions like extracting functions / types
    ['_typescript.rename'] = function(_, result, ctx)
      local client = assert(vim.lsp.get_client_by_id(ctx.client_id))
      vim.lsp.util.show_document({
        uri = result.textDocument.uri,
        range = {
          start = result.position,
          ['end'] = result.position,
        },
      }, client.offset_encoding)
      vim.lsp.buf.rename()
      return vim.NIL
    end,
  },
  init_options = { hostInfo = "neovim" },
  on_attach = function(client, bufnr)
    -- ts_ls provides `source.*` code actions that apply to the whole file. These only appear in
    -- `vim.lsp.buf.code_action()` if specified in `context.only`.
    vim.api.nvim_buf_create_user_command(bufnr, 'LspTypescriptSourceAction', function()
      local source_actions = vim.tbl_filter(function(action)
        return vim.startswith(action, 'source.')
      end, client.server_capabilities.codeActionProvider.codeActionKinds)

      vim.lsp.buf.code_action({
        context = {
          only = source_actions,
          diagnostics = {},
        },
      })
    end, {})

    -- Go to source definition command
    vim.api.nvim_buf_create_user_command(bufnr, 'LspTypescriptGoToSourceDefinition', function()
      local win = vim.api.nvim_get_current_win()
      local params = vim.lsp.util.make_position_params(win, client.offset_encoding)
      client:exec_cmd({
        command = '_typescript.goToSourceDefinition',
        title = 'Go to source definition',
        arguments = { params.textDocument.uri, params.position },
      }, { bufnr = bufnr }, function(err, result)
        if err then
          vim.notify('Go to source definition failed: ' .. err.message, vim.log.levels.ERROR)
          return
        end
        if not result or vim.tbl_isempty(result) then
          vim.notify('No source definition found', vim.log.levels.INFO)
          return
        end
        vim.lsp.util.show_document(result[1], client.offset_encoding, { focus = true })
      end)
    end, { desc = 'Go to source definition' })
  end,
  root_dir = function(bufnr, on_dir)
    -- The project root is where the LSP can be started from
    -- As stated in the documentation above, this LSP supports monorepos and simple projects.
    -- We select then from the project root, which is identified by the presence of a package
    -- manager lock file.
    local root_markers = { 'package-lock.json', 'yarn.lock', 'pnpm-lock.yaml', 'bun.lockb', 'bun.lock', '.git' }
    -- exclude deno
    local deno_path = vim.fs.root(bufnr, { 'deno.json', 'deno.jsonc', 'deno.lock' })
    local project_root = vim.fs.root(bufnr, root_markers)
    if deno_path and (not project_root or #deno_path >= #project_root) then
      return
    end
    -- We fallback to the current working directory if no project root is found
    on_dir(project_root or vim.fn.getcwd())
  end,
}

vim.lsp.enable("ts_ls")

vim.lsp.config["twiggy_language_server"] = {
  cmd = { "twiggy-language-server", "--stdio" },
  filetypes = { "twig" },
  root_markers = { "composer.json", ".git" },
}

vim.lsp.enable("twiggy_language_server")

vim.lsp.config["svelte"] = {
  cmd = { "svelteserver", "--stdio" },
  filetypes = { "svelte" },
  root_dir = function(bufnr, on_dir)
    local fname = vim.api.nvim_buf_get_name(bufnr)
    -- Svelte LSP only supports file:// schema. https://github.com/sveltejs/language-tools/issues/2777
    if vim.uv.fs_stat(fname) ~= nil then
      local root_markers = { 'package-lock.json', 'yarn.lock', 'pnpm-lock.yaml', 'bun.lockb', 'bun.lock', 'deno.lock' }
      root_markers = vim.fn.has('nvim-0.11.3') == 1 and { root_markers, { '.git' } }
        or vim.list_extend(root_markers, { '.git' })
      -- We fallback to the current working directory if no project root is found
      local project_root = vim.fs.root(bufnr, root_markers) or vim.fn.getcwd()
      on_dir(project_root)
    end
  end,
  on_attach = function(client, bufnr)
    -- Workaround to trigger reloading JS/TS files
    -- See https://github.com/sveltejs/language-tools/issues/2008
    vim.api.nvim_create_autocmd('BufWritePost', {
      pattern = { '*.js', '*.ts' },
      group = vim.api.nvim_create_augroup('lspconfig.svelte', {}),
      callback = function(ctx)
        -- internal API to sync changes that have not yet been saved to the file system
        ---@diagnostic disable-next-line: param-type-mismatch
        client:notify('$/onDidChangeTsOrJsFile', { uri = ctx.match })
      end,
    })
    vim.api.nvim_buf_create_user_command(bufnr, 'LspMigrateToSvelte5', function()
      client:exec_cmd({
        title = 'Migrate Component to Svelte 5 Syntax',
        command = 'migrate_to_svelte_5',
        arguments = { vim.uri_from_bufnr(bufnr) },
      })
    end, { desc = 'Migrate Component to Svelte 5 Syntax' })
  end,
}

vim.lsp.enable("svelte")
