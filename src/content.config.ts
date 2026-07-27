import { defineCollection, z } from "astro:content";
import { glob } from "astro/loaders";
import { articleSchema } from "@silitics/astro-theme/content";

const docsSchema = z.object({
  title: z.string().optional(),
  description: z.string().optional(),
  order: z.number().optional(),
  draft: z.boolean().optional(),
});

const docs = defineCollection({
  loader: glob({
    pattern: "**/*.{md,mdx}",
    base: "./src/content/docs",
  }),
  schema: docsSchema,
});

const blog = defineCollection({
  loader: glob({
    pattern: "**/*.{md,mdx}",
    base: "./src/content/blog",
  }),
  // `description` renders in full on the blog index, tag pages, RSS, and as the
  // article standfirst. `summary` holds a short form for the meta description,
  // but nothing consumes it yet: `ArticleLayout` derives both the standfirst
  // and the meta tag from `description` and exposes no way to separate them.
  schema: articleSchema().extend({ summary: z.string().optional() }),
});

export const collections = { blog, docs };
