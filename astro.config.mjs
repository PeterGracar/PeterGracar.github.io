import { defineConfig } from 'astro/config';

export default defineConfig({
  site: 'https://gracar.org',
  output: 'static',
  trailingSlash: 'never',
  build: {
    format: 'file'
  }
});
