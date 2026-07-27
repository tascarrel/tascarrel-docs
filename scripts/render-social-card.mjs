import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";

process.env.FONTCONFIG_FILE = fileURLToPath(
  new URL("./fontconfig.xml", import.meta.url),
);

const { default: sharp } = await import("sharp");

const socialCardSourcePath = new URL(
  "../public/img/tascarrel-social-card.svg",
  import.meta.url,
);
const socialCardOutputPath = new URL(
  "../public/img/tascarrel-social-card.png",
  import.meta.url,
);
const workbenchScreenshotPath = new URL(
  "../public/img/tascarrel-workbench.png",
  import.meta.url,
);
const screenshotPlacement = {
  left: 416,
  top: 103,
  width: 753,
  height: 424,
};

await renderSocialCard();

async function renderSocialCard() {
  const socialCardSource = await readFile(socialCardSourcePath, "utf8");
  const vectorLayer = socialCardSource.replace(
    /\s*<!-- render:screenshot:start -->[\s\S]*?<!-- render:screenshot:end -->/,
    "",
  );
  const [renderedVectorLayer, workbenchScreenshot] = await Promise.all([
    sharp(Buffer.from(vectorLayer)).png().toBuffer(),
    sharp(fileURLToPath(workbenchScreenshotPath))
      .resize({ width: screenshotPlacement.width })
      .png()
      .toBuffer(),
  ]);

  await sharp(renderedVectorLayer)
    .composite([
      {
        input: workbenchScreenshot,
        left: screenshotPlacement.left,
        top: screenshotPlacement.top,
      },
    ])
    .png({ compressionLevel: 9, adaptiveFiltering: true })
    .toFile(fileURLToPath(socialCardOutputPath));

  await verifyEmbeddedScreenshot(workbenchScreenshot);
}

async function verifyEmbeddedScreenshot(workbenchScreenshot) {
  const [expectedPixels, embeddedPixels] = await Promise.all([
    sharp(workbenchScreenshot).ensureAlpha().raw().toBuffer(),
    sharp(fileURLToPath(socialCardOutputPath))
      .extract(screenshotPlacement)
      .ensureAlpha()
      .raw()
      .toBuffer(),
  ]);
  if (!expectedPixels.equals(embeddedPixels)) {
    throw new Error("Rendered social card modified the workbench screenshot.");
  }
}
