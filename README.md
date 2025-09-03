# SourceAtlas

A CLI tool for creating lightweight code indexes that help AI agents quickly locate code in large codebases.

## Overview

SourceAtlas generates JSONL indexes with file metadata, symbols, imports, and roles to enable efficient code navigation without requiring full AST parsing. It's designed to be language-agnostic and dependency-light, using POSIX tools and optional Universal Ctags + ripgrep for enhanced symbol extraction.

## Features

- **Language-agnostic design** with regex-based symbol extraction
- **Zero/near-zero dependencies** using POSIX tools (find, grep, sed, awk)
- **Progressive retrieval** with configurable limits
- **Sharding for large codebases** (≤2MB compressed, ≤10k records per shard)
- **Universal Ctags + ripgrep** support when available
- **Incremental updates** with delta indexing

## Supported Languages

- **Primary**: Swift, Kotlin, Objective-C
- **Secondary**: Ruby, Shell, Python
- **Config files**: JSON, YAML, Gradle, plist

## Installation

```bash
# Clone the repository
git clone <repository-url>
cd sourcealtas

# Make CLI executable
chmod +x bin/satlas bin/sourceatlas

# Make globally accessible (choose one method)

# Method 1: Add to PATH in your shell profile
echo 'export PATH="$PATH:'$(pwd)'/bin"' >> ~/.bashrc
# or for zsh users:
echo 'export PATH="$PATH:'$(pwd)'/bin"' >> ~/.zshrc

# Method 2: Create symlinks in /usr/local/bin
sudo ln -sf $(pwd)/bin/satlas /usr/local/bin/satlas
sudo ln -sf $(pwd)/bin/sourceatlas /usr/local/bin/sourceatlas

# Method 3: Copy to /usr/local/bin
sudo cp bin/satlas bin/sourceatlas /usr/local/bin/
```

After installation, reload your shell or run `source ~/.bashrc` (or `~/.zshrc`) to use the commands from anywhere.

## Usage

### Quick Start

```bash
# 1. Navigate to your codebase
cd /path/to/your/project

# 2. Initialize SourceAtlas (creates config files)
satlas init

# 3. Generate the complete index
satlas run

# 4. Start querying your code
satlas query "MyClass"
```

### Basic Commands

```bash
# Generate complete index (recommended for first-time use)
satlas run

# Initialize default config
satlas init

# Generate main index only
satlas scan

# Query by symbol/role/path
satlas query <search_term>

# Export to low-token DSL format
satlas export-dsl

# Incremental updates
satlas delta

# Show statistics
satlas stats

# Clean output directory
satlas clean
```

### Query Examples

#### Symbol Search (Classes, Functions, Methods)
```bash
# Find classes containing "User"
satlas query --type symbol "User"
# Output:
# Found 3 matches for pattern: User
# ./src/models/User.swift:15
# ./src/services/UserService.kt:8
# ./tests/UserTests.swift:12
# Search completed in 0.025s

# Case-insensitive symbol search
satlas query --type symbol --ignore-case "appdelegate"

# Regular expression search
satlas query --type symbol --regex "test.*Login"
```

#### Content Search (Text within files)
```bash
# Find files containing "TODO"
satlas query "TODO"

# Search for specific patterns
satlas query --ignore-case "deprecated"
```

#### Path Search (File and directory names)
```bash
# Find files in specific directories
satlas query --type path "ios/"

# Find specific file types
satlas query --type path "*.swift"
```

#### Advanced Query Options
```bash
# Verbose output with file details
satlas query --type symbol --verbose "ViewController"
# Output:
# ./ios/LoginViewController.swift:25 - LoginViewController (class)
#   Language: swift, Lines: 156, Role: general
# 
# ./ios/ProfileViewController.swift:18 - ProfileViewController (class)  
#   Language: swift, Lines: 89, Role: general
# 
# Search completed in 0.018s

# JSON output for scripting
satlas query --type symbol --format json "User" | jq '.results[0].path'

# Limit results
satlas query --limit 10 "function"
```

### Real-World Workflow Examples

#### Exploring a New Codebase
```bash
# 1. Set up SourceAtlas
cd /path/to/new/project
satlas init
satlas run

# 2. Get overview statistics  
satlas stats
# Output: Generated statistics for 1003 files
#         Total lines of code: 45892
#         Total symbols: 2816

# 3. Find main entry points
satlas query --type symbol "main\|AppDelegate\|Application"

# 4. Explore specific features
satlas query --type symbol "Login"
satlas query --type path "test"
```

#### Code Navigation During Development
```bash
# Find all test files
satlas query --type path "*Test*"

# Find specific API endpoints
satlas query --type symbol "api.*endpoint"

# Search for error handling patterns
satlas query "catch\|error\|exception"

# Find configuration files
satlas query --type path "*.config\|*.yml\|*.json"
```

#### Performance-Optimized Usage
```bash
# First symbol search automatically generates symbol table (one-time ~30s)
satlas query --type symbol "DCAppNodeView"
# Output:
# Symbol table not found, generating it for faster searches...
# Processing 1003 files for symbols...
# Generated 2816 symbols
# Search completed in 34.800s

# Subsequent symbol searches are extremely fast
satlas query --type symbol "UserService" 
# Output:
# Using symbol table: sourceatlas.symbols.tsv
# Found 2 matches for pattern: UserService
# Search completed in 0.035s  # 994x faster!
```

### Code Segment Extraction

Extract specific parts of files for detailed analysis:

```bash
# Extract lines 10-30 from a specific file
satlas segment src/User.swift 10 30

# Extract with padding and line numbers
satlas segment --pad 5 --line-numbers src/User.swift 25 35
# Output:
# 20:     private var name: String
# 21:     private var email: String
# 22:     
# 23:     init(name: String, email: String) {
# 24:         self.name = name
# 25:         self.email = email  # ← Target lines
# 26:         setupValidation()
# 27:     }
# 28:     
# 29:     func validate() -> Bool {
# 30:         return !name.isEmpty && email.contains("@")
# 31:     }

# JSON output for programmatic use
satlas segment --format json src/User.swift 1 20
```

### CLI Aliases

- `satlas` - Short alias for the main command
- `sourceatlas` - Full command name

## Output Structure

SourceAtlas creates a `.sourceatlas/` directory in your target codebase containing:

- **Index files**: JSONL format with one record per source file
- **Symbol table**: TSV format for reverse symbol lookups  
- **Manifest**: JSON file tracking shards and versions
- **Shards**: Split indexes for large codebases

## Configuration

Generate a default configuration file:

```bash
satlas init
```

This creates language-specific rules and settings in the `configs/` directory.

## Performance

- **Index generation**: ≤10 min for medium projects on 4C/8G
- **Coverage**: ≥95% of readable files indexed
- **Query accuracy**: Hit@5 ≥80% for common queries

## Development

### Testing

```bash
# Run all E2E tests
bats tests/e2e/

# Test specific functionality
bats tests/e2e/test_cli.bats
```

### Project Structure

```text
bin/         - CLI executables (satlas, sourceatlas)
lib/         - Core libraries and parsers
configs/     - Language rules and settings  
tests/       - Test code and fixtures
docs/        - Documentation
```

## License

[Add your license here]

## AI Agent Integration

### Recommended Prompt for AI Agents

Include this in your AI agent prompts to enable effective SourceAtlas usage:

```markdown
You have access to SourceAtlas CLI (`satlas`) for code exploration and navigation. Use these commands:

**Code Discovery:**
- `satlas query --type symbol "ClassName"` - Find classes, functions, methods
- `satlas query "search_term"` - Search file contents  
- `satlas query --type path "directory/"` - Find files/directories
- `satlas stats` - Get codebase overview (files, LOC, symbols)

**Code Analysis:**
- `satlas segment path/file.ext START END` - Extract code segments
- `satlas segment --line-numbers --pad 3 path/file.ext START END` - Extract with context

**Performance Tips:**
- First symbol search auto-generates symbol table (~30s), subsequent searches are instant
- Use `--verbose` for detailed file information
- Use `--format json` for structured data

**Example Workflow:**
1. Get overview: `satlas stats`
2. Find relevant code: `satlas query --type symbol "UserService"`
3. Extract context: `satlas segment src/UserService.kt 45 65 --pad 5`

Always use SourceAtlas before making code changes to understand the codebase structure.
```

### Example AI Agent Prompts

#### Code Navigation Task
```markdown
Help me understand this codebase. Use `satlas stats` to get an overview, then find the main application entry point using `satlas query --type symbol "main|AppDelegate|Application"`. For any classes you find, use `satlas segment` to show me their implementation.
```

#### Bug Investigation
```markdown
I'm getting an error related to "UserAuthentication". Use SourceAtlas to:
1. Find all code related to authentication: `satlas query --type symbol --ignore-case "auth"`
2. Search for error handling: `satlas query "error|exception|catch"`
3. Show me the relevant code segments with `satlas segment`
```

#### Feature Development
```markdown
I want to add a new payment feature. Use SourceAtlas to explore the codebase:
1. Find existing payment-related code: `satlas query --type symbol "payment|billing"`
2. Look for similar features: `satlas query --type path "*payment*"`
3. Show me the code structure with `satlas segment` for the files you find
```

## Tips for Better Results

### Symbol Search Performance
- First symbol search generates a symbol table (~30s for 1000 files)
- Subsequent symbol searches are extremely fast (~0.03s)
- Use `satlas symbols` to pre-generate the table before heavy symbol usage

### Search Strategies
- **Exact matches**: Use quotes for precise results: `satlas query "ExactClassName"`
- **Partial matches**: Search without quotes: `satlas query User` (finds UserService, UserModel, etc.)
- **Case-insensitive**: Add `--ignore-case` for broader matching
- **Regular expressions**: Use `--regex` for complex patterns

### Large Codebase Optimization
- Run `satlas clean && satlas run` if index seems outdated
- Use `satlas delta` for incremental updates after changes
- Check `satlas stats` to verify index coverage

## Contributing

[Add contributing guidelines here]