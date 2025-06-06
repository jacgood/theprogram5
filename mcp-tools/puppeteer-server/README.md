# Puppeteer MCP Server

This MCP server provides Puppeteer functionality for Claude to render and compare webpages.

## Setup

1. Install dependencies:
```bash
cd mcp-tools/puppeteer-server
npm install
```

2. Add to your Claude Desktop configuration (`claude_desktop_config.json`):

### For macOS:
Location: `~/Library/Application Support/Claude/claude_desktop_config.json`

### For Windows:
Location: `%APPDATA%\Claude\claude_desktop_config.json`

### For Linux:
Location: `~/.config/Claude/claude_desktop_config.json`

Add this to your config:
```json
{
  "mcpServers": {
    "puppeteer": {
      "command": "node",
      "args": ["/home/jacobgood/theprogram5/mcp-tools/puppeteer-server/index.js"],
      "env": {}
    }
  }
}
```

## Available Tools

1. **screenshot** - Take a screenshot of a webpage
   - `url`: The webpage URL
   - `fullPage`: Whether to capture the full page (default: true)

2. **get_html** - Get the rendered HTML of a webpage
   - `url`: The webpage URL

3. **compare_pages** - Compare two webpages visually
   - `url1`: First webpage URL
   - `url2`: Second webpage URL

## Usage in Claude

Once configured, Claude will have access to these tools to:
- Take screenshots of webpages
- Compare visual differences between sites
- Get rendered HTML content

## Troubleshooting

If you encounter issues:
1. Make sure Node.js is installed (v18 or higher)
2. Check that all dependencies are installed
3. Verify the path in claude_desktop_config.json is correct
4. Restart Claude Desktop after configuration changes