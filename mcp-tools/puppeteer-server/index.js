#!/usr/bin/env node
import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import puppeteer from 'puppeteer';

const server = new Server(
  {
    name: 'puppeteer-server',
    version: '1.0.0',
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

let browser = null;

// Tool to render a webpage and take a screenshot
server.setRequestHandler('tools/call', async (request) => {
  if (request.params.name === 'screenshot') {
    const { url, fullPage = true } = request.params.arguments;
    
    if (!browser) {
      browser = await puppeteer.launch({
        headless: 'new',
        args: ['--no-sandbox', '--disable-setuid-sandbox']
      });
    }
    
    const page = await browser.newPage();
    await page.goto(url, { waitUntil: 'networkidle2' });
    
    const screenshot = await page.screenshot({
      fullPage,
      encoding: 'base64'
    });
    
    await page.close();
    
    return {
      content: [
        {
          type: 'text',
          text: `Screenshot of ${url} taken successfully. Base64 data length: ${screenshot.length}`
        },
        {
          type: 'image',
          data: screenshot,
          mimeType: 'image/png'
        }
      ]
    };
  }
  
  if (request.params.name === 'get_html') {
    const { url } = request.params.arguments;
    
    if (!browser) {
      browser = await puppeteer.launch({
        headless: 'new',
        args: ['--no-sandbox', '--disable-setuid-sandbox']
      });
    }
    
    const page = await browser.newPage();
    await page.goto(url, { waitUntil: 'networkidle2' });
    
    const html = await page.content();
    await page.close();
    
    return {
      content: [
        {
          type: 'text',
          text: html
        }
      ]
    };
  }
  
  if (request.params.name === 'compare_pages') {
    const { url1, url2 } = request.params.arguments;
    
    if (!browser) {
      browser = await puppeteer.launch({
        headless: 'new',
        args: ['--no-sandbox', '--disable-setuid-sandbox']
      });
    }
    
    const page1 = await browser.newPage();
    const page2 = await browser.newPage();
    
    await page1.goto(url1, { waitUntil: 'networkidle2' });
    await page2.goto(url2, { waitUntil: 'networkidle2' });
    
    const screenshot1 = await page1.screenshot({ fullPage: true, encoding: 'base64' });
    const screenshot2 = await page2.screenshot({ fullPage: true, encoding: 'base64' });
    
    await page1.close();
    await page2.close();
    
    return {
      content: [
        {
          type: 'text',
          text: `Comparison of ${url1} and ${url2}`
        },
        {
          type: 'text',
          text: 'Page 1:'
        },
        {
          type: 'image',
          data: screenshot1,
          mimeType: 'image/png'
        },
        {
          type: 'text',
          text: 'Page 2:'
        },
        {
          type: 'image',
          data: screenshot2,
          mimeType: 'image/png'
        }
      ]
    };
  }
  
  throw new Error(`Unknown tool: ${request.params.name}`);
});

// List available tools
server.setRequestHandler('tools/list', async () => {
  return {
    tools: [
      {
        name: 'screenshot',
        description: 'Take a screenshot of a webpage',
        inputSchema: {
          type: 'object',
          properties: {
            url: {
              type: 'string',
              description: 'URL of the webpage to screenshot'
            },
            fullPage: {
              type: 'boolean',
              description: 'Whether to take a full page screenshot',
              default: true
            }
          },
          required: ['url']
        }
      },
      {
        name: 'get_html',
        description: 'Get the rendered HTML of a webpage',
        inputSchema: {
          type: 'object',
          properties: {
            url: {
              type: 'string',
              description: 'URL of the webpage'
            }
          },
          required: ['url']
        }
      },
      {
        name: 'compare_pages',
        description: 'Compare two webpages visually',
        inputSchema: {
          type: 'object',
          properties: {
            url1: {
              type: 'string',
              description: 'First URL to compare'
            },
            url2: {
              type: 'string',
              description: 'Second URL to compare'
            }
          },
          required: ['url1', 'url2']
        }
      }
    ]
  };
});

// Cleanup on exit
process.on('SIGINT', async () => {
  if (browser) {
    await browser.close();
  }
  process.exit(0);
});

const transport = new StdioServerTransport();
server.connect(transport);
console.error('Puppeteer MCP server started');