import { defineCollection, z } from "astro:content";
import { glob } from "astro/loaders";

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

export const collections = { docs };
