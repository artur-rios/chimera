import { expect, test } from '@playwright/test';

async function enableFlutterSemantics(page) {
  const placeholder = page.locator('flt-semantics-placeholder');
  if (await placeholder.count()) {
    await placeholder.evaluate((element) => element.click());
    await placeholder.waitFor({ state: 'detached' });
  }
}

async function fillFlutterTextBox(textBox, value) {
  await textBox.click();
  await textBox.fill(value);
  await expect(textBox).toHaveValue(value);
  await textBox.press('Tab');
}

test('compiled Chimera shell loads without page errors', async ({ page }) => {
  const pageErrors = [];
  page.on('pageerror', (error) => pageErrors.push(error.message));

  const response = await page.goto('/');

  expect(response?.ok()).toBe(true);
  await expect(page).toHaveTitle('Chimera');
  expect(pageErrors).toEqual([]);
});

test('cron flow calculates locally without external requests', async ({ page }) => {
  const externalRequests = [];
  page.on('request', (request) => {
    const url = new URL(request.url());
    if (url.hostname !== '127.0.0.1') {
      externalRequests.push(request.url());
    }
  });

  await page.goto('/');
  await expect(page).toHaveTitle('Chimera');
  await enableFlutterSemantics(page);
  await page.getByRole('button', { name: 'Parse a cron expression' }).click();
  await expect(page.getByText('Parse cron expression')).toBeVisible();

  await fillFlutterTextBox(
    page.getByRole('textbox', { name: 'Cron expression' }),
    '0 9 * * MON-FRI',
  );
  await fillFlutterTextBox(
    page.getByRole('textbox', { name: 'Time zone' }),
    'UTC',
  );
  await fillFlutterTextBox(
    page.getByRole('textbox', { name: 'Occurrence count' }),
    '1',
  );
  await fillFlutterTextBox(
    page.getByRole('textbox', { name: /Reference instant/ }),
    '2026-01-05T12:00:00Z',
  );
  await page.getByRole('button', { name: 'Calculate occurrences' }).click();

  await expect(page.getByText('Cron schedule: 0 9 * * 1-5').last()).toBeVisible();
  await expect(
    page.getByText(/Next: 2026-01-06T09:00:00.000\+00:00/).last(),
  ).toBeVisible();
  expect(externalRequests).toEqual([]);
});

test('date flow converts locally without external requests', async ({ page }) => {
  const externalRequests = [];
  page.on('request', (request) => {
    const url = new URL(request.url());
    if (url.hostname !== '127.0.0.1') {
      externalRequests.push(request.url());
    }
  });

  await page.goto('/');
  await expect(page).toHaveTitle('Chimera');
  await enableFlutterSemantics(page);
  await page.getByRole('button', { name: 'Convert a date' }).click();
  await expect(page.getByText('Convert date').first()).toBeVisible();

  await fillFlutterTextBox(
    page.getByRole('textbox', { name: 'Date value' }),
    '2026-01-15T12:30:45Z',
  );
  await fillFlutterTextBox(
    page.getByRole('textbox', { name: 'Target time zone' }),
    'America/Sao_Paulo',
  );
  await page.getByRole('button', { name: 'Convert date' }).click();

  await expect(
    page.getByText('Converted value: 2026-01-15T09:30:45.000-03:00').last(),
  ).toBeVisible();
  expect(externalRequests).toEqual([]);
});

test('number base flow converts arbitrary precision locally without external requests', async ({ page }) => {
  const externalRequests = [];
  page.on('request', (request) => {
    const url = new URL(request.url());
    if (url.hostname !== '127.0.0.1') {
      externalRequests.push(request.url());
    }
  });

  await page.goto('/');
  await expect(page).toHaveTitle('Chimera');
  await enableFlutterSemantics(page);
  await page.getByRole('button', { name: 'Convert a number base' }).click();
  await expect(page.getByText('Convert number base').first()).toBeVisible();

  await fillFlutterTextBox(
    page.getByRole('textbox', { name: 'Number value' }),
    '184467440737095516160',
  );
  await page.getByRole('button', { name: 'Convert number' }).click();

  await expect(
    page.getByRole('group', {
      name: 'Converted value a0000000000000000',
    }),
  ).toBeVisible();
  expect(externalRequests).toEqual([]);
});

test('text escape flow escapes Unicode locally without external requests', async ({ page }) => {
  const externalRequests = [];
  page.on('request', (request) => {
    const url = new URL(request.url());
    if (url.hostname !== '127.0.0.1') {
      externalRequests.push(request.url());
    }
  });

  await page.goto('/');
  await expect(page).toHaveTitle('Chimera');
  await enableFlutterSemantics(page);
  await page
    .getByRole('button', { name: /^Escape text$/ })
    .click();
  await expect(page.getByText('Escape text').first()).toBeVisible();

  await fillFlutterTextBox(
    page.getByRole('textbox', { name: 'Input text' }),
    'A"\\\né',
  );
  await page.getByRole('button', { name: /^Escape text$/ }).click();

  await expect(
    page.getByRole('group', {
      name: /Escaped text A.*é/,
    }),
  ).toBeVisible();
  expect(externalRequests).toEqual([]);
});

test('text unescape flow decodes Unicode locally without external requests', async ({ page }) => {
  const externalRequests = [];
  page.on('request', (request) => {
    const url = new URL(request.url());
    if (url.hostname !== '127.0.0.1') {
      externalRequests.push(request.url());
    }
  });

  await page.goto('/');
  await expect(page).toHaveTitle('Chimera');
  await enableFlutterSemantics(page);
  await page
    .getByRole('button', { name: /^Unescape text$/ })
    .click();
  await expect(page.getByText('Unescape text').first()).toBeVisible();

  await fillFlutterTextBox(
    page.getByRole('textbox', { name: 'Escaped input text' }),
    String.raw`A\"\\\né\u0021`,
  );
  await page.getByRole('button', { name: /^Unescape text$/ }).click();

  await expect(
    page.getByRole('group', {
      name: /Unescaped text A.*é!/,
    }),
  ).toBeVisible();
  expect(externalRequests).toEqual([]);
});

test('list comparison flow compares locally without external requests', async ({ page }) => {
  const externalRequests = [];
  page.on('request', (request) => {
    const url = new URL(request.url());
    if (url.hostname !== '127.0.0.1') {
      externalRequests.push(request.url());
    }
  });

  await page.goto('/');
  await expect(page).toHaveTitle('Chimera');
  await enableFlutterSemantics(page);
  await page.getByRole('button', { name: 'Compare lists' }).click();
  await expect(page.getByText('Compare lists').first()).toBeVisible();

  await fillFlutterTextBox(
    page.getByRole('textbox', { name: 'Left list' }),
    'alpha\nleft\n',
  );
  await fillFlutterTextBox(
    page.getByRole('textbox', { name: 'Right list' }),
    'alpha\nright',
  );
  await page.getByRole('button', { name: 'Compare lists' }).click();

  await expect(
    page.getByRole('region', { name: /Left only Items: 2 left/ }),
  ).toBeVisible();
  await expect(
    page.getByRole('region', { name: /Right only Items: 1 right/ }),
  ).toBeVisible();
  await expect(
    page.getByRole('region', { name: /Intersection Items: 1 alpha/ }),
  ).toBeVisible();
  await expect(page.getByText('Equal: no').last()).toBeVisible();
  expect(externalRequests).toEqual([]);
});

test('JSON array flow renders locally without external requests', async ({ page }) => {
  const externalRequests = [];
  page.on('request', (request) => {
    const url = new URL(request.url());
    if (url.hostname !== '127.0.0.1') {
      externalRequests.push(request.url());
    }
  });

  await page.goto('/');
  await expect(page).toHaveTitle('Chimera');
  await enableFlutterSemantics(page);
  await page
    .getByRole('button', { name: 'Convert a JSON array to a table' })
    .click();
  await expect(page.getByText('Convert JSON array to table').first()).toBeVisible();

  await fillFlutterTextBox(
    page.getByRole('textbox', { name: 'JSON array' }),
    '[{"name":"Ada","meta":{"x":1}}]',
  );
  await page.getByRole('button', { name: 'Create table' }).click();

  await expect(page.getByText('Ada').last()).toBeVisible();
  await expect(page.getByText('{"x":1}').last()).toBeVisible();
  expect(externalRequests).toEqual([]);
});

test('JSON CSV flow serializes locally without external requests', async ({ page }) => {
  const externalRequests = [];
  page.on('request', (request) => {
    const url = new URL(request.url());
    if (url.hostname !== '127.0.0.1') {
      externalRequests.push(request.url());
    }
  });

  await page.goto('/');
  await expect(page).toHaveTitle('Chimera');
  await enableFlutterSemantics(page);
  await page
    .getByRole('button', { name: 'Convert a JSON array to CSV' })
    .click();
  await expect(page.getByText('Convert JSON array to CSV').first()).toBeVisible();

  await fillFlutterTextBox(
    page.getByRole('textbox', { name: 'JSON array' }),
    '[{"name":"Ada","meta":{"x":1}}]',
  );
  await page.getByRole('button', { name: 'Create CSV' }).click();

  await expect(
    page.getByRole('group', {
      name: 'CSV result name,meta Ada,"{""x"":1}"',
    }),
  ).toBeVisible();
  expect(externalRequests).toEqual([]);
});

test('JSON YAML flow serializes locally without external requests', async ({ page }) => {
  const externalRequests = [];
  page.on('request', (request) => {
    const url = new URL(request.url());
    if (url.hostname !== '127.0.0.1') {
      externalRequests.push(request.url());
    }
  });

  await page.goto('/');
  await expect(page).toHaveTitle('Chimera');
  await enableFlutterSemantics(page);
  await page.getByRole('button', { name: 'Convert JSON to YAML' }).click();
  await expect(page.getByText('Convert JSON to YAML').first()).toBeVisible();

  await fillFlutterTextBox(
    page.getByRole('textbox', { name: 'JSON value' }),
    '{"name":"Ada","meta":{"x":1}}',
  );
  await page.getByRole('button', { name: 'Create YAML' }).click();

  await expect(
    page.getByRole('group', {
      name: 'YAML result name: Ada meta: x: 1',
    }),
  ).toBeVisible();
  expect(externalRequests).toEqual([]);
});

test('JSON format flow formats locally without external requests', async ({ page }) => {
  const externalRequests = [];
  page.on('request', (request) => {
    const url = new URL(request.url());
    if (url.hostname !== '127.0.0.1') {
      externalRequests.push(request.url());
    }
  });

  await page.goto('/');
  await expect(page).toHaveTitle('Chimera');
  await enableFlutterSemantics(page);
  await page.getByRole('button', { name: 'Format JSON' }).click();
  await expect(page.getByText('Format JSON').first()).toBeVisible();

  await fillFlutterTextBox(
    page.getByRole('textbox', { name: 'JSON value' }),
    '{"name":"Ada","meta":{"x":1},"large":9007199254740993,"underflow":1e-400}',
  );
  await page.getByRole('button', { name: 'Format JSON' }).click();

  await expect(
    page.getByRole('group', {
      name: /Formatted JSON result.*"name": "Ada".*"x": 1.*"large": 9007199254740993.*"underflow": 1e-400/,
    }),
  ).toBeVisible();
  expect(externalRequests).toEqual([]);
});

test('SQL format flow formats locally without external requests', async ({ page }) => {
  const externalRequests = [];
  page.on('request', (request) => {
    const url = new URL(request.url());
    if (url.hostname !== '127.0.0.1') {
      externalRequests.push(request.url());
    }
  });

  await page.goto('/');
  await expect(page).toHaveTitle('Chimera');
  await enableFlutterSemantics(page);
  await page.getByRole('button', { name: 'Format SQL' }).click();
  await expect(page.getByText('Format SQL').first()).toBeVisible();

  await fillFlutterTextBox(
    page.getByRole('textbox', { name: 'SQL statement' }),
    'select id,name from users where active=true',
  );
  await page.getByRole('button', { name: 'Format SQL' }).click();

  await expect(
    page.getByRole('group', {
      name: /Formatted SQL result.*SELECT.*id.*name.*FROM users.*WHERE active = TRUE/,
    }),
  ).toBeVisible();
  expect(externalRequests).toEqual([]);
});

test('XML format flow formats locally without external requests', async ({ page }) => {
  const externalRequests = [];
  page.on('request', (request) => {
    const url = new URL(request.url());
    if (url.hostname !== '127.0.0.1') {
      externalRequests.push(request.url());
    }
  });

  await page.goto('/');
  await expect(page).toHaveTitle('Chimera');
  await enableFlutterSemantics(page);
  await page.getByRole('button', { name: 'Format XML' }).click();
  await expect(page.getByText('Format XML').first()).toBeVisible();

  await fillFlutterTextBox(
    page.getByRole('textbox', { name: 'XML document' }),
    '<root><developer name="Ada"/></root>',
  );
  await page.getByRole('button', { name: 'Format XML' }).click();

  await expect(
    page.getByRole('group', {
      name: /Formatted XML result.*root.*developer name="Ada"/,
    }),
  ).toBeVisible();
  expect(externalRequests).toEqual([]);
});
