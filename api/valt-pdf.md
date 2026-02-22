---
layout: default
title: "valt/pdf"
parent: API Reference
nav_order: 5
---

# valt/pdf

## Functions

### generatePdf

**Library:** `valt/pdf`

Library to generate PDF files from HTML.
Intended for use via: require 'valt/pdf'
Generate a PDF file from an HTML file using Puppeteer (Node.js).
Args: htmlFile outputFile [footerTemplate]
  htmlFile       - path to the input HTML file
  outputFile     - path where the generated PDF will be written
  footerTemplate - optional HTML string used as the PDF footer template

```bash
generatePdf() {
```

