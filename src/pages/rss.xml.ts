import rss from "@astrojs/rss";
import { getCollection } from "astro:content";
import { rssItemsFromArticles } from "@silitics/astro-theme";

import { brand } from "../site.ts";

export async function GET(context: { site?: URL }) {
  const posts = await getCollection("blog");
  return rss({
    title: `${brand.name} Blog`,
    description:
      "Engineering articles about isolated development environments, coding agents, and Tascarrel.",
    site: context.site?.toString() ?? "https://tascarrel.dev",
    items: rssItemsFromArticles(posts, "/blog"),
  });
}
