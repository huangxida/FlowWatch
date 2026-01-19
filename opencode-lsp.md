# LSP 服务器

OpenCode 与你的 LSP 服务器集成。

OpenCode 与你的 Language Server Protocol (LSP) 集成，帮助 LLM 与你的代码库交互。它使用诊断信息向 LLM 提供反馈。

## 内置

OpenCode 内置多种流行语言的 LSP 服务器：

| LSP 服务器 | 扩展 | 需求 |
|-----------|------|------|
| astro | .astro | Astro 项目自动安装 |
| bash | .sh, .bash, .zsh, .ksh | 自动安装 bash-language-server |
| clangd | .c, .cpp, .cc, .cxx, .c++, .h, .hpp, .hh, .hxx, .h++ | 自动安装适用于 C/C++ 项目的 |
| csharp | .cs | .NET SDK 已安装 |
| clojure-lsp | .clj, .cljs, .cljc, .edn | clojure-lsp 命令可用 |
| dart | .dart | dart 命令可用 |
| deno | .ts, .tsx, .js, .jsx, .mjs | deno 命令可用（自动检测 deno.json/deno.jsonc） |
| elixir-ls | .ex, .exs | elixir 命令可用 |
| eslint | .ts, .tsx, .js, .jsx, .mjs, .cjs, .mts, .cts, .vue | eslint 在项目中的依赖 |
| fsharp | .fs, .fsi, .fsx, .fsscript | .NET SDK 已安装 |
| gleam | .gleam | gleam 命令可用 |
| gopls | .go | go 命令可用 |
| jdtls | .java | Java SDK（版本 21+） 已安装 |
| kotlin-ls | .kt, .kts | Kotlin 项目自动安装 |
| lua-ls | .lua | Lua 项目自动安装 |
| nixd | .nix | nixd 命令可用 |
| ocaml-lsp | .ml, .mli | ocamllsp 命令可用 |
| oxlint | .ts, .tsx, .js, .jsx, .mjs, .cjs, .mts, .cts, .vue, .astro, .svelte | oxlint 依赖项在项目中 |
| php intelephense | .php | 为 PHP 项目自动安装 |
| prisma | .prisma | prisma 命令可用 |
| pyright | .py, .pyi | pyright 依赖已安装 |
| ruby-lsp (rubocop) | .rb, .rake, .gemspec, .ru | ruby 和 gem 命令可用 |
| rust | .rs | rust-analyzer 命令可用 |
| sourcekit-lsp | .swift, .objc, .objcpp | swift 已安装（xcode 在 macOS 上） |
| svelte | .svelte | 适用于 Svelte 项目的自动安装 |
| terraform | .tf, .tfvars | 自动从 GitHub 发布中安装 |
| tinymist | .typ, .typc | 从 GitHub 发行版自动安装 |
| typescript | .ts、.tsx、.js、.jsx、.mjs、.cjs、.mts、.cts | typescript 在项目中的依赖关系 |
| vue | .vue | Vue 项目自动安装 |
| yaml-ls | .yaml, .yml | 自动安装 Red Hat yaml-language-server |
| zls | .zig, .zon | zig 命令可用 |

当检测到上述其中一个文件扩展名且满足要求时，LSP 服务器会自动启用。

> **Note**
>
> You can disable automatic LSP server downloads by setting the `OPENCODE_DISABLE_LSP_DOWNLOAD` environment variable to `true`.

## 工作原理

当 opencode 打开一个文件时，它：

1. 检查文件扩展名与所有已启用的 LSP 服务器进行匹配。
2. 如未在运行中则启动相应的 LSP 服务器。

## 配置

您可以通过 opencode 配置中的 lsp 部分自定义 LSP 服务器。

```json
{
  "$schema": "https://opencode.ai/config.json",
  "lsp": {}
}
```

每个 LSP 服务器支持以下内容：

| 属性 | 类型 | 描述 |
|------|------|------|
| disabled | 布尔值 | 把它设为 true 以禁用 LSP 服务器 |
| command | 字符串数组 | 启动 LSP 服务器的命令 |
| extensions | string[] | 此 LSP 服务器应处理的文件扩展名 |
| env | 对象 | 在启动服务器时要设置的环境变量 |
| initialization | 对象 | 要发送给 LSP 服务器的初始化选项 |

让我们看一些例子。

### 禁用 LSP 服务器

要全局禁用所有 LSP 服务器，请将 lsp 设置为 false：

```json
{
  "$schema": "https://opencode.ai/config.json",
  "lsp": false
}
```

要禁用一个特定的 LSP 服务器，请将 `disabled` 设置为 `true`：

```json
{
  "$schema": "https://opencode.ai/config.json",
  "lsp": {
    "typescript": {
      "disabled": true
    }
  }
}
```

### 自定义 LSP 服务器

你可以通过指定命令和文件扩展名来添加自定义的 LSP 服务器：

```json
{
  "$schema": "https://opencode.ai/config.json",
  "lsp": {
    "custom-lsp": {
      "command": ["custom-lsp-server", "--stdio"],
      "extensions": [".custom"]
    }
  }
}
```

## 附加信息

### PHP Intelephense

PHP Intelephense 通过许可证密钥提供高级功能。您可以将密钥放在文本文件中（仅限密钥），文件路径为：

- **在 macOS/Linux**：`$HOME/intelephense/licence.txt`
- **在 Windows 上**：`%USERPROFILE%/intelephense/licence.txt`

该文件应仅包含许可密钥，不应有其他内容。
