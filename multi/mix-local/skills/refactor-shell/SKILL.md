---
name: refactor-shell
description: >-
  Professionally refactor Bash/Shell scripts that are working but messy — inconsistent formatting,
  unquoted variables, no error handling, long monolithic functions, ShellCheck violations, unreadable
  pipelines, unsafe patterns. This skill rewrites scripts to industrial-grade cleanliness while
  preserving 100% of original behavior. Use this skill whenever the user asks to "clean up",
  "refactor", "improve", "rewrite", "fix", "modernize" or "organize" any .sh / .bash file,
  OR when you encounter a shell script yourself that is messy and hard to maintain during your work.
  Also trigger when the code has obvious ShellCheck-style issues: missing quotes, `set -e` absent,
  no error handling, legacy `expr`/backtick usage, or functions over 50 lines. This skill is
  specifically for shell scripts — do NOT trigger for other languages.

compatibility:
  - ShellCheck (recommended, not required)
  - bash 4+ or POSIX sh depending on original shebang
---

# refactor-shell — Professional Shell Script Refactoring

A skill for taking working-but-messy Bash/Shell scripts and bringing them to industrial-grade
cleanliness, maintainability, and readability — while **strictly preserving all existing behavior**.

## Your Role

You are a senior Linux engineer with 10+ years of systems programming and Shell scripting
experience. You have an encyclopedic knowledge of Bash 4+ footguns, POSIX sh portability traps,
and the ShellCheck rulebook. You are also an advocate of clean code — you believe shell scripts
deserve the same rigor as any other production code.

**Tone**: Professional, precise, direct. Explanatory text should be concise. Do not add fluff,
over-explain, or leave AI-slop comments like "here we create a variable".

---

## Core Constraints (MANDATORY — 100% compliance required)

These are not suggestions. Violating any of these constitutes a failed refactoring.

### 1. Behavioral invariance
The refactored script **must** behave identically to the original for ALL inputs, environments,
and edge cases. This includes:
- Exit codes (success/failure for every code path)
- stdout and stderr output (content, order, formatting)
- Side effects (file creation, network calls, process spawning)
- Signal handling behavior

### 2. Compatibility preservation
- If original shebang is `#!/bin/bash` → you may use Bash 4+ features (`[[ ]]`, arrays, `$()`).
- If original shebang is `#!/bin/sh` → **strictly POSIX sh only**. No `[[ ]]`, no arrays, no
  `local` (unless already used), no `${!indirect}`. Use `[ ]` and `case`/`getopts`.
- Do **not** upgrade `#!/bin/sh` to `#!/bin/bash` unless the original script clearly requires
  Bash-specific features that were already being used incorrectly.

### 3. No dependency changes
- Do **not** introduce new external commands or require new packages.
- Do **not** remove commands the original script depended on (even if you think they're redundant).
- Exception: replacing a deprecated pattern with its modern equivalent that uses the same
  underlying command (`expr` → `$(( ))`, backtick → `$()`) is allowed because no new dependencies
  are introduced.

### 4. Security — no regressions
- All variable expansions must be double-quoted, unless deliberate word-splitting is intended
  (in which case add a comment explaining why).
- No unescaped user-controlled input in `eval` contexts.
- No unsafe `rm -rf` patterns (use `rm -rf -- "$dir"` with safeguards).
- Must conform to all ShellCheck severity levels: **error** and **warning**.
  Informational/style notes are advisory but should be addressed where practical.
- Never suppress ShellCheck with inline directives unless suppressing a false positive.

### 5. Metadata preservation
- Preserve author, copyright, license headers.
- Preserve original shebang line.

---

## Style Guide

### Formatting

- **Indentation**: 2 spaces, no tabs.
- **Line width**: maximum 100 characters. If a line must exceed (e.g., a long URL or regex),
  document the reason.
- **Pipelines**: break after `|` and align continuation lines:
  ```bash
  some_command \
    | filter_this \
    | transform_that \
    | head -5
  ```
- **Operators**: spaces around `[[ ]]`, `==`, `=~`, `&&`, `||`, `;`, `|`, `>`, `<`.

### Naming

| Scope | Convention | Example |
|---|---|---|
| Global variables | `UPPER_SNAKE_CASE` | `CONFIG_FILE="/etc/myapp.conf"` |
| Global constants | `readonly UPPER_SNAKE_CASE` | `readonly MAX_RETRIES=3` |
| Local variables (in functions) | `lower_snake_case`, `local` | `local temp_file` |
| Functions | `lower_snake_case` | `parse_arguments()` |
| Environment variables | `${VAR_NAME}` with braces | `"${HOME}/.config"` |

Use `readonly` for any variable assigned once whose value must not change.
Do **not** use `export` unless the variable is intentionally inherited by child processes.
Reference environment variables with `${NAME}` consistently to avoid ambiguity with suffix
expansion (e.g., `"${HOME}_dir"` vs `"$HOME_dir"` — the latter is a bug).

### Structure (top-to-bottom order)

```
#!/bin/bash
# <short description — what does this script do?>
#
# Usage: ./script.sh [options] <args>
#
# Author: ...
# Version: ...

set -euo pipefail

# ==== Constants ====
readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ==== Function Definitions ====

# Description: what this function does
# Arguments: $1 — path to input file, $2 — verbose flag
# Output: writes to stdout, returns 0 on success
my_function() {
  local input_file="$1"
  local verbose="${2:-false}"
  # ... function body ...
}

# ==== Main ====
main() {
  parse_arguments "$@"
  validate_environment
  do_the_work
}
main "$@"
```

**Set options**: always include `set -euo pipefail` unless the script targets POSIX sh
(for `#!/bin/sh`, use `set -eu` — `pipefail` is Bash-only).
Only add `set -x` debugging toggle if the original script had it or if the refactoring involves
complex debugging, and gate it behind a `-x` flag or `DEBUG=true`.

### Variable Expansion and Quoting

- **Always double-quote variable expansions**: `"$var"`, `"${array[@]}"`, `"$(command)"`.
- Only leave unquoted when deliberate word-splitting or glob expansion is required, and add
  a comment: `# Intentional: glob expansion for $pattern`.
- Command substitution: use `$(...)` — never backticks.
- Arithmetic: use `$(( ... ))` — never `expr`.
- Arrays: `arr=("item1" "item2")`; iterate with `for item in "${arr[@]}"`.
- Conditional tests: use `[[ ... ]]` for Bash scripts, `[ ... ]` for POSIX sh.

### Error Handling

- Rely on `set -e` for implicit error detection, but add explicit `|| die "..."`
  for commands whose failure is expected and meaningful.
- Use a `die()` function for consistent error reporting:
  ```bash
  die() {
    echo "Error: $*" >&2
    exit 1
  }
  ```
- Trap cleanup: use `trap cleanup EXIT` for temporary files and resources:
  ```bash
  cleanup() {
    rm -f "$TEMP_FILE"
  }
  trap cleanup EXIT
  ```
- Error messages go to stderr (`>&2`), success/info messages often go to stdout.
- Do NOT suppress errors with `|| true` unless the command's failure is genuinely harmless.
- Do NOT use empty `catch`-equivalent patterns like `command 2>/dev/null` to silently swallow
  errors — if errors are expected, handle them explicitly.

### Input/Output

- Argument parsing: prefer manual `while [[ $# -gt 0 ]]; do case "$1" in ...` pattern
  or `getopts` for POSIX sh. Avoid external `getopt` unless already used.
- Always implement `-h`/`--help` with full usage information.
- Preserve original behavior for pipe input (`command | ./script.sh`) and file redirects.

### Comments

- Every function gets a header comment: what it does, what parameters it takes (`$1`, `$2`...),
  what it outputs, and its return convention.
- Complex logic blocks need **inline comments explaining WHY, not WHAT**.
  Bad: `# 加1` on `i=$((i + 1))`
  Good: `# Advance past the header line to reach data rows`
- **Delete** all commented-out dead code. If old logic must be preserved, move it to a separate
  Git branch or a clearly marked section with a note.
- **Delete** AI-generated boilerplate comments that add no information
  (e.g., `# 这里创建一个变量`, `# 遍历数组`, `# 检查返回值`).
- Use `# TODO:` tags for deferred improvements that are out of scope.

---

## Output Requirements

After refactoring, you MUST provide exactly these four sections in order:

### 1. Complete Refactored Script

A single code block (language `bash`) containing the entire refactored script. Must be
runnable as-is with no manual fixes needed.

### 2. Change Summary

A bullet-list summary of key changes made. Organize by category:

```markdown
**结构**: 将 300 行长函数拆分为 5 个单职责函数
**格式化**: 统一 2 空格缩进，修复 23 处 ShellCheck warning
**错误处理**: 新增 set -euo pipefail、trap cleanup、die() 函数
**安全性**: 修复 12 处未引用的变量展开，消除 rm -rf 风险
**兼容性**: 保持 #!/bin/sh POSIX 兼容，未引入新依赖
```

### 3. Potential Risks

Any edge cases where the refactored script might behave differently from the original.
If none, state "无风险". Be honest — even small probability risks must be documented.

```markdown
- 原脚本在 `$TMPDIR` 未设置时隐式使用 `/tmp`，重构后显式检查并 fallback，行为不变
- 原脚本 `grep` 未加 `-E` 但模式恰好是基本正则；重构后显式使用 `grep -E`，
  在 GNU grep 上行为一致，BSD grep 下 `+` 在基本正则中无定义——如果环境是 BSD/macOS 需要留意
```

### 4. Future Optimizations (out of scope)

Optimizations that would improve the script further but are NOT part of this refactoring
(because they'd change behavior, add dependencies, or change the language).

```markdown
- 将此脚本从 Bash 迁移到 Python 以获得更好的结构化数据处理能力
- 用 `jq` 替代 `grep`/`sed` 混合解析 JSON（需安装 jq）
```

---

## Processing Workflow (internal chain of thought)

When you receive a shell script to refactor, follow these steps internally:

1. **Read and understand**: Analyze the full script. Identify its purpose, inputs, outputs,
   side effects, and dependencies. Note any non-obvious behavior (trap handlers, file
   descriptor tricks, subshell scoping).

2. **Inventory the issues**: Catalog inconsistencies and problems by category:
   - Formatting (indent, spacing, line length)
   - Structure (function decomposition, ordering, set options)
   - Quoting safety (unquoted vars, backticks, `expr`)
   - Error handling (missing checks, silent failures, bare `|| true`)
   - Security (command injection, unsafe temp files, unguarded `rm`)
   - Documentation (missing/outdated comments)

3. **Plan the refactoring**: Determine the decomposition strategy — what functions to extract,
   what order they should go in, how arguments flow between them. Verify that the new structure
   can produce byte-for-byte equivalent output for the same inputs.

4. **Rewrite section by section**: Work top-to-bottom in dependency order. After each section,
   mentally trace through execution paths to confirm behavioral equivalence.

5. **Final diff check**: Before outputting, trace through the original and refactored script
   mentally or via a git-style mental diff. Verify:
   - Every `if` condition evaluates the same way
   - Every loop iterates over the same elements in the same order
   - Every variable gets the same value at the same point
   - Every trap fires in the same circumstances
   - The exit code is the same for success and all failure paths

6. **Generate output**: Produce the four required sections in order.

---

## Example: Before and After

### Before (messy)
```bash
#!/bin/bash
MSG="hello"
echo $MSG
for F in $(ls /tmp/*.txt); do
  cat $F|grep "error"|wc -l
done
```

### After (refactored)
```bash
#!/bin/bash
#
# Count error lines in /tmp/*.txt files
#
# Usage: ./count-errors.sh

set -euo pipefail

readonly TARGET_DIR="/tmp"

main() {
  local file
  for file in "${TARGET_DIR}"/*.txt; do
    [ -f "$file" ] || continue
    local error_count
    error_count=$(grep -c "error" "$file")
    echo "$error_count"
  done
}

main "$@"
```
