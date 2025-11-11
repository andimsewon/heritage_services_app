# C99 CLI File Explorer

## Build Instructions

```bash
gcc -std=c99 -Wall -Wextra -Werror -o 202413153_explorer explorer.c
```

## Run Instructions

```bash
# Start in current directory
./202413153_explorer

# Start in specified directory
./202413153_explorer /path/to/directory

# Start with normalized path (will normalize /tmp/../tmp/./foo to /tmp/foo)
./202413153_explorer /tmp/../tmp/./foo
```

## Features

### Commands

- `ls` - List all entries in current directory (names only)
- `ls -d` - List directories only (names only)
- `quit` - Exit the program

### Path Normalization Strategy

The implementation uses a two-step approach for path normalization:

1. **For existing paths**: Uses `realpath()` to get the absolute canonical path, which automatically resolves `.`, `..`, and redundant slashes.

2. **For non-existent paths or when realpath fails**: Implements a custom normalization function that:
   - Tokenizes the path by `/`
   - Removes `.` components
   - Resolves `..` by removing the previous component
   - Reconstructs the path with proper separators
   - Handles both absolute and relative paths

The normalization ensures that:
- All paths displayed in the prompt are absolute and normalized
- No `.` or `..` components appear in the prompt
- Redundant slashes are collapsed

### Error Handling

- Invalid commands: Prints "Error: unknown command"
- Invalid options: Prints "Error: invalid option"
- Path/access errors: Uses `perror()` with the offending path
- All errors return to prompt (no crash, no exit)

### Implementation Details

- Uses `lstat()` for directory detection (doesn't follow symlinks)
- Falls back to `stat()` when `d_type == DT_UNKNOWN` (for macOS compatibility)
- Skips `.` and `..` entries in all listings
- Handles EOF gracefully (exits cleanly)
- Tolerates multiple spaces/tabs between tokens
- Empty input lines are ignored

## Testing

The implementation should pass all acceptance tests:

1. ✅ Launch defaults - shows normalized absolute path
2. ✅ Launch with path - normalizes paths like `/tmp/../tmp/./foo`
3. ✅ REPL persistence - doesn't exit until `quit`
4. ✅ Basic ls - lists files in directory order
5. ✅ ls -d - lists directories only
6. ✅ Invalid option - handles `ls -x` correctly
7. ✅ Invalid command - handles unknown commands
8. ✅ No extra info - names only, no metadata
9. ✅ Skip dot entries - never shows `.` or `..`

