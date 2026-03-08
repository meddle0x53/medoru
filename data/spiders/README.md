# Scrapy Spiders (Optional)

This directory is for [Scrapy](https://scrapy.org/) spiders if needed for more complex crawling tasks.

For most data sources, the built-in spiders in `src/medoru_data/spiders/` using `requests` and `beautifulsoup4` are sufficient.

## When to use Scrapy

- Complex multi-page crawling with pagination
- JavaScript-rendered pages (use Scrapy + Playwright/Splash)
- Rate limiting and retry logic requirements
- Distributed crawling across multiple domains

## Quick Start

```bash
pip install scrapy
scrapy startproject medoru_scrapy .
```

Then create spiders in `spiders/medoru_scrapy/spiders/`.
