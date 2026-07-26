import type { APIRoute } from "astro";
import installer from "../../install.sh?raw";

export const prerender = true;

export const GET: APIRoute = () => {
  return new Response(installer, {
    headers: {
      "Content-Type": "text/x-shellscript; charset=utf-8",
    },
  });
};
