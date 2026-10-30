import { expect, test } from "@playwright/test";
import { readFileSync } from "node:fs";
import {
  fillFlutterTextInput,
  observeFlutterTextInput,
} from "./flutter_text_input.mjs";
import { unexpectedHttpRequests } from "./network_policy.mjs";

const source = readFileSync(
  new URL("./person_browser.js", import.meta.url),
  "utf8",
);
const saveSource = readFileSync(
  new URL("./gzip_save_observer.js", import.meta.url),
  "utf8",
);
const syntheticLabel =
  "Synthetic person test data - not a real identity or proof of issuance";

async function probe(page, action, value) {
  return page.evaluate(
    ({ source, action, value }) =>
      new Function(
        `${source}\nreturn personProbe(arguments[0], arguments[1]);`,
      )(action, value),
    { source, action, value },
  );
}

function visibleText(page, text) {
  const escaped = text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  return page.locator("span", { hasText: new RegExp(`^${escaped}$`) });
}

async function openPerson(page) {
  await observeFlutterTextInput(page);
  await page.goto("/");
  const placeholder = page.locator("flt-semantics-placeholder");
  await placeholder.waitFor({ state: "attached" });
  await placeholder.evaluate((node) => node.click());
  await page
    .getByRole("button", { name: "Generate Synthetic People", exact: true })
    .click();
  await expect(
    page.getByRole("textbox", { name: "Positive integer count", exact: true }),
  ).toBeVisible();
  // Minimum age autofocuses; let it land before a test focuses another field.
  await expect(
    page.getByRole("textbox", { name: "Minimum age (0-130)", exact: true }),
  ).toBeFocused();
  await page.context().setOffline(true);
  await probe(page, "setup");
}

async function select(page, field, option) {
  await expect.poll(() => probe(page, "openSelect", field)).toBe(true);
  await expect.poll(() => probe(page, "option", option)).toBe(true);
}

test("GivenDefaults_WhenGeneratedCopiedSavedOffline_ThenLabeledSyntheticTransfer", async ({
  page,
}) => {
  const requests = [];
  await page.addInitScript(`${saveSource}\nobserveGzipSaves();`);
  await openPerson(page);
  page.on("request", (request) => {
    if (/^https?:/.test(request.url())) requests.push(request.url());
  });
  await fillFlutterTextInput(
    page.getByRole("textbox", { name: "Positive integer count", exact: true }),
    "2",
  );
  await page
    .getByRole("button", { name: "Generate synthetic people", exact: true })
    .click();
  await expect.poll(() => probe(page, "result")).not.toBeNull();
  const result = await probe(page, "result");
  expect(result).toContain(syntheticLabel);
  expect(result).toContain("Person 1 Name:");
  expect(result).toContain("Person 2 Name:");
  expect(result).toContain("@example.com");
  expect(result).toContain("SSN:");
  await expect.poll(() => probe(page, "copy")).toBe(true);
  await expect.poll(() => probe(page, "copied")).not.toBeNull();
  const transferred = await probe(page, "copied");
  expect(transferred).toContain(`${syntheticLabel}\nPerson 1`);
  const downloaded = page.waitForEvent("download");
  await page
    .getByRole("button", { name: "Save labeled person data", exact: true })
    .press("Enter");
  const download = await downloaded;
  expect(download.suggestedFilename()).toBe("chimera-synthetic-people.txt");
  const chunks = [];
  for await (const chunk of await download.createReadStream())
    chunks.push(chunk);
  expect(Buffer.concat(chunks)).toEqual(Buffer.from(transferred));
  await expect
    .poll(() => probe(page, "saved", [...Buffer.from(transferred)]))
    .toBe(true);
  await fillFlutterTextInput(
    page.getByRole("textbox", { name: "Positive integer count", exact: true }),
    "3",
  );
  await expect.poll(() => probe(page, "noResult")).toBe(true);
  expect(unexpectedHttpRequests(requests, page.url(), true)).toEqual([]);
});

test("GivenBrazilAndAgeRange_WhenGeneratedOffline_ThenLocaleConsistentPersonReturns", async ({
  page,
}) => {
  await openPerson(page);
  await select(page, "Country or locale", "Brazil");
  await fillFlutterTextInput(
    page.getByRole("textbox", { name: "Minimum age (0-130)", exact: true }),
    "21",
  );
  await fillFlutterTextInput(
    page.getByRole("textbox", { name: "Maximum age (0-130)", exact: true }),
    "40",
  );
  await expect
    .poll(() => probe(page, "button", "Generate synthetic people"))
    .toBe(true);
  const result = await expect.poll(() => probe(page, "result")).not.toBeNull();
  const text = await probe(page, "result");
  expect(text).toContain("+55 (");
  expect(text).toContain("CPF:");
  expect(text).toContain("CIN:");
  expect(text).toContain("@example.com");
});

for (const failure of ["validation", "processing", "copy", "save"]) {
  test(`Given${failure}Failure_WhenActionRunsOffline_ThenVisibleErrorWithoutPartialValue`, async ({
    page,
  }) => {
    const requests = [];
    await openPerson(page);
    page.on("request", (request) => {
      if (/^https?:/.test(request.url())) requests.push(request.url());
    });
    if (failure === "validation")
      await fillFlutterTextInput(
        page.getByRole("textbox", {
          name: "Positive integer count",
          exact: true,
        }),
        "0",
      );
    if (failure === "processing") await probe(page, "entropyFailure");
    await page
      .getByRole("button", { name: "Generate synthetic people", exact: true })
      .click();
    if (failure === "copy" || failure === "save") {
      await expect.poll(() => probe(page, "result")).not.toBeNull();
      await probe(page, `${failure}Failure`);
      await page
        .getByRole("button", {
          name:
            failure === "copy"
              ? "Copy labeled person data"
              : "Save labeled person data",
          exact: true,
        })
        .evaluate((node) => node.click());
    }
    const message = {
      validation:
        "Choose a supported locale, ages from 0 through 130 in ascending order, and a positive integer count.",
      processing:
        "Synthetic person generation failed. No partial people were produced.",
      copy: "The synthetic person result could not be copied.",
      save: "The synthetic person result could not be written.",
    }[failure];
    await expect(visibleText(page, message)).toBeVisible();
    await expect.poll(() => probe(page, "noResult")).toBe(true);
    expect(unexpectedHttpRequests(requests, page.url(), true)).toEqual([]);
  });
}
