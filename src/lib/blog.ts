import type { CollectionEntry } from "astro:content";

export function slugFromEntry(entry: CollectionEntry<"blog">): string {
  return entry.data.slug ?? entry.id.replace(/^\d{4}-\d{2}-\d{2}-/, "");
}

export function tagSlug(tag: string): string {
  return tag
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "");
}

export function tagHref(tag: string): string {
  return `/blog/tags/${tagSlug(tag)}`;
}
