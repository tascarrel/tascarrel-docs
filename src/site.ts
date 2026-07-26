import "./styles/site.css";

import { getCollection } from "astro:content";
import type {
  Brand,
  FooterColumn,
  NavItem,
  SocialLink,
} from "@silitics/astro-theme";
import type { DocsConfig, DocsNavGroup } from "@silitics/astro-docs";
import { buildNav, memoizeDocsConfig } from "@silitics/astro-docs";
import { faGithub } from "@fortawesome/free-brands-svg-icons";

export const brand: Brand = {
  name: "Tascarrel",
  logo: "/img/logo.svg",
  href: "/",
  tagline:
    "An agentic development workbench where agents work safely without babysitting.",
  ogImage: {
    src: "/img/tascarrel-social-card.png",
    width: 1200,
    height: 630,
    alt: "Tascarrel workbench with the headline “Let Agents Work Safely Without Babysitting”",
  },
  locale: "en",
  themeColor: { dark: "#0b0d12", light: "#fafafa" },
  titleTemplate: "%s — Tascarrel",
  plausible: { domain: "tascarrel.dev" },
};

export const nav: NavItem[] = [];

export const headerActions: NavItem[] = [
  {
    label: "GitHub",
    href: "https://github.com/tascarrel/tascarrel",
    external: true,
    icon: faGithub,
  },
  {
    label: "Docs",
    href: "/docs",
    primary: true,
  },
];

export const footerColumns: FooterColumn[] = [
  {
    title: "Documentation",
    links: [
      { label: "Overview", href: "/docs" },
      {
        label: "Getting Started",
        href: "/docs/getting-started/installation",
      },
      {
        label: "Choose a Boundary",
        href: "/docs/getting-started/choose-the-right-boundary",
      },
      { label: "CLI Reference", href: "/docs/reference/tascarrel-cli" },
    ],
  },
  {
    title: "Project",
    links: [
      {
        label: "GitHub",
        href: "https://github.com/tascarrel/tascarrel",
        external: true,
      },
      {
        label: "Issue Tracker",
        href: "https://github.com/tascarrel/tascarrel/issues",
        external: true,
      },
      {
        label: "Security",
        href: "/docs/reference/security-policy",
      },
    ],
  },
  {
    title: "Silitics",
    links: [
      {
        label: "About",
        href: "https://silitics.com",
        external: true,
      },
      {
        label: "Privacy Policy",
        href: "https://silitics.com/privacy-policy",
        external: true,
      },
      {
        label: "Imprint",
        href: "https://silitics.com/impressum",
        external: true,
      },
    ],
  },
];

export const socials: SocialLink[] = [
  {
    label: "GitHub",
    href: "https://github.com/tascarrel/tascarrel",
    icon: faGithub,
  },
];

export const getDocsConfig = memoizeDocsConfig(
  async (): Promise<DocsConfig> => {
    const entries = await getCollection("docs");
    const docsNav = rewriteDocsIndex(
      buildNav(entries, {
        rootGroupTitle: "Introduction",
        groupTitles: {
          "getting-started": "Getting Started",
          guides: "Using Tascarrel",
          operations: "Operations",
          reference: "Reference",
        },
        groupOrder: [
          "",
          "getting-started",
          "guides",
          "operations",
          "reference",
        ],
      }),
    );

    return {
      versions: [
        {
          slug: "latest",
          label: "Latest",
          status: "current",
          default: true,
          pathPrefix: "/docs/",
          nav: docsNav,
          editBaseUrl:
            "https://github.com/tascarrel/tascarrel-docs/edit/main/src/content/docs",
        },
      ],
    };
  },
);

function rewriteDocsIndex(groups: DocsNavGroup[]): DocsNavGroup[] {
  for (const group of groups) {
    for (const link of group.links) {
      if (link.slug === "index") {
        link.slug = "";
        link.href = "/docs";
      }
    }
  }
  return groups;
}
