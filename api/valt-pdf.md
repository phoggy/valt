---
layout: default
title: "valt/pdf"
parent: "Paper Keys"
grand_parent: API Reference
nav_order: 7
---

# valt/pdf

PDF generation from HTML.

## Functions

### generatePdf()

Generates a PDF from an HTML file via a Node.js Puppeteer script.


*args*

| | |
|---|---|
| `htmlFile` *(string)* | Path to the input HTML file. |
| `outputFile` *(string)* | Path where the generated PDF will be written. |
| `[footerTemplate]` *(string)* | HTML string used as the PDF footer template. |
{: .args-table}

