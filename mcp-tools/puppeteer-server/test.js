import puppeteer from 'puppeteer';

async function test() {
  console.log('Testing Puppeteer installation...');
  
  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });
  
  const page = await browser.newPage();
  await page.goto('https://example.com');
  
  const title = await page.title();
  console.log('Page title:', title);
  
  await browser.close();
  console.log('Test completed successfully!');
}

test().catch(console.error);