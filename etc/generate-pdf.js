const puppeteer = require('puppeteer');
const fs = require('fs');
const path = require('path');

async function generatePDF(htmlFile, outputFile, footerTemplate) {
    // Convert to absolute paths
    const absoluteHtmlFile = path.resolve(htmlFile);
    const absoluteOutputFile = path.resolve(outputFile);

    if (!fs.existsSync(absoluteHtmlFile)) {
        console.error(`HTML file not found: ${absoluteHtmlFile}`);
        process.exit(1);
    }

    const browser = await puppeteer.launch({
        headless: true,
        args: [
            '--no-sandbox',
            '--disable-setuid-sandbox',
            '--disable-notifications',
            '--disable-extensions',
            '--disable-gpu',
            '--disable-dev-shm-usage',
            '--disable-background-timer-throttling',
            '--disable-backgrounding-occluded-windows',
            '--disable-renderer-backgrounding',
            '--disable-features=TranslateUI',
            '--disable-default-apps',
            '--no-default-browser-check',
            '--no-first-run',
            '--disable-popup-blocking',
            '--disable-prompt-on-repost',
            '--disable-hang-monitor',
            '--disable-sync',
            '--metrics-recording-only',
            '--no-crash-upload',
            '--disable-crash-reporter',
            '--disable-component-update'
        ]
    });

    const page = await browser.newPage();
    await page.goto(`file://${absoluteHtmlFile}`, { waitUntil: 'networkidle0' });

    const pdfOptions = {
        path: absoluteOutputFile,
        format: 'Letter',
        printBackground: true,
        displayHeaderFooter: false
    };

    if (footerTemplate) {
        pdfOptions.displayHeaderFooter = true;
        pdfOptions.headerTemplate = '<div></div>'; // Empty header template
        pdfOptions.footerTemplate = footerTemplate;
        pdfOptions.margin = {
            top: '1cm',
            right: '1cm',
            bottom: '2cm',
            left: '1cm'
        };
    }

    await page.pdf(pdfOptions);
    await browser.close();
    console.log(`PDF generated: ${absoluteOutputFile}`);
}

// Get command line arguments
const htmlFile = process.argv[2];
const outputFile = process.argv[3];
const footerTemplate = process.argv[4];

if (!htmlFile || !outputFile) {
    console.error('Usage: node generate-pdf.js <html-file> <output-file>');
    process.exit(1);
}

generatePDF(htmlFile, outputFile, footerTemplate).catch(console.error);


