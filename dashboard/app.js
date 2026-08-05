const METRIC_KEYS = [
  "impressions",
  "product_page_views",
  "clicks",
  "downloads",
  "app_opens",
  "paywall_views",
  "subscriptions",
];

const SOURCE_META = {
  app: "code: app",
  download: "code: download",
  lennard: "code: lennard",
  lm10: "code: lm10",
  reddit_ads: "AppsFlyer · reddit_ads",
  asc_search: "ASC Source Type = Search",
};

let loadToken = 0;

/** Format a Date as YYYY-MM-DD in UTC. */
function toUtcDateInput(date) {
  const y = date.getUTCFullYear();
  const m = String(date.getUTCMonth() + 1).padStart(2, "0");
  const d = String(date.getUTCDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

function utcToday() {
  const now = new Date();
  return new Date(
    Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()),
  );
}

function addUtcDays(date, days) {
  const next = new Date(date.getTime());
  next.setUTCDate(next.getUTCDate() + days);
  return next;
}

function presetRange(preset) {
  const end = utcToday();
  if (preset === "today") {
    const day = toUtcDateInput(end);
    return { from: day, to: day };
  }
  if (preset === "yesterday") {
    const day = toUtcDateInput(addUtcDays(end, -1));
    return { from: day, to: day };
  }
  if (preset === "last_month") {
    return {
      from: toUtcDateInput(addUtcDays(end, -29)),
      to: toUtcDateInput(end),
    };
  }
  return {
    from: toUtcDateInput(addUtcDays(end, -6)),
    to: toUtcDateInput(end),
  };
}

function getSelectedRange() {
  return {
    from: document.getElementById("from").value,
    to: document.getElementById("to").value,
  };
}

function setRangeInputs(from, to) {
  document.getElementById("from").value = from;
  document.getElementById("to").value = to;
}

function setActivePreset(preset) {
  document.querySelectorAll(".preset").forEach((btn) => {
    btn.classList.toggle("active", btn.dataset.preset === preset);
  });
}

function detectPreset(from, to) {
  for (const preset of ["today", "yesterday", "last_week", "last_month"]) {
    const range = presetRange(preset);
    if (from === range.from && to === range.to) return preset;
  }
  return null;
}

function formatMetric(metric) {
  if (!metric || metric.value == null || metric.status !== "ok") {
    if (metric && metric.status === "loading") {
      return { text: "", loading: true, na: false };
    }
    if (metric && metric.status === "pending_asc_api") {
      return { text: "pending", na: true };
    }
    return { text: "n/a", na: true };
  }
  return { text: Number(metric.value).toLocaleString("nl-NL"), na: false };
}

function appendMetricCell(tr, metric) {
  const td = document.createElement("td");
  const formatted = formatMetric(metric);
  if (formatted.loading) {
    td.className = "loading-cell";
    const spin = document.createElement("span");
    spin.className = "spinner";
    spin.setAttribute("aria-label", "Laden");
    td.appendChild(spin);
  } else {
    td.textContent = formatted.text;
    if (formatted.na) td.className = "na";
  }
  tr.appendChild(td);
}

const OVERALL_INPUT_STORAGE_KEY = "dashboard_overall_inputs";

const DEFAULT_OVERALL_INPUTS = {
  total: {
    trial_to_sub: "",
    monthly_price: "",
    yearly_price: "",
    split_monthly_yearly: "",
    churn_monthly: "",
    cost_per_download: "",
  },
  ios: {
    trial_to_sub: "",
    monthly_price: "",
    yearly_price: "",
    split_monthly_yearly: "",
    churn_monthly: "",
    cost_per_download: "",
  },
  android: {
    trial_to_sub: "",
    monthly_price: "",
    yearly_price: "",
    split_monthly_yearly: "",
    churn_monthly: "",
    cost_per_download: "",
  },
};

function loadOverallInputs() {
  try {
    const raw = localStorage.getItem(OVERALL_INPUT_STORAGE_KEY);
    if (!raw) return structuredClone(DEFAULT_OVERALL_INPUTS);
    const parsed = JSON.parse(raw);
    const merged = structuredClone(DEFAULT_OVERALL_INPUTS);
    for (const platformId of Object.keys(merged)) {
      const saved = parsed[platformId] || {};
      merged[platformId] = {
        ...merged[platformId],
        ...saved,
      };
      if (saved.cac != null && saved.cac !== "" && !merged[platformId].cost_per_download) {
        merged[platformId].cost_per_download = saved.cac;
      }
    }
    return merged;
  } catch {
    return structuredClone(DEFAULT_OVERALL_INPUTS);
  }
}

function saveOverallInputs(inputs) {
  localStorage.setItem(OVERALL_INPUT_STORAGE_KEY, JSON.stringify(inputs));
}

function parseOverallNumber(raw) {
  if (raw == null || String(raw).trim() === "") return null;
  const normalized = String(raw).trim().replace(",", ".");
  const value = Number(normalized);
  return Number.isFinite(value) ? value : null;
}

function formatMoneyValue(value) {
  if (value == null || Number.isNaN(Number(value))) {
    return { text: "—", na: true };
  }
  return {
    text: `$${Number(value).toLocaleString("en-US", {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    })}`,
    na: false,
  };
}

function formatProfitMargin(revenue, cost) {
  if (revenue == null || cost == null || cost === 0) {
    return { text: "—", na: true };
  }
  const ratio = Number(revenue) / Number(cost);
  return {
    text: `${ratio.toLocaleString("nl-NL", {
      maximumFractionDigits: 2,
      minimumFractionDigits: 2,
    })}:1`,
    na: false,
  };
}

function calculateCostPerTrial(costPerDownload, platformData) {
  if (costPerDownload == null) return null;

  const onboardingStarted = Number(platformData?.survey_started ?? 0);
  const trialStarted = Number(platformData?.subscriptions ?? 0);
  if (onboardingStarted <= 0 || trialStarted <= 0) return null;

  const onboardingToTrial = trialStarted / onboardingStarted;
  if (onboardingToTrial <= 0) return null;

  return costPerDownload / onboardingToTrial;
}

function calculateCostPerSub(costPerDownload, platformData, platformInputs) {
  const costPerTrial = calculateCostPerTrial(costPerDownload, platformData);
  const trialToSub = parseOverallNumber(platformInputs?.trial_to_sub);
  if (costPerTrial == null || trialToSub == null || trialToSub <= 0) return null;

  return costPerTrial / (trialToSub / 100);
}

function calculateArppc(platformInputs) {
  const monthlyPrice = parseOverallNumber(platformInputs?.monthly_price);
  const yearlyPrice = parseOverallNumber(platformInputs?.yearly_price);
  const splitMonthly = parseOverallNumber(platformInputs?.split_monthly_yearly);
  const churnMonthly = parseOverallNumber(platformInputs?.churn_monthly);

  if (
    monthlyPrice == null ||
    yearlyPrice == null ||
    splitMonthly == null ||
    churnMonthly == null ||
    churnMonthly <= 0 ||
    churnMonthly > 100
  ) {
    return null;
  }

  const monthlyShare = splitMonthly / 100;
  const yearlyShare = 1 - monthlyShare;
  const churnRate = churnMonthly / 100;

  const monthlyPlanRevenue = monthlyPrice / churnRate;
  const yearlyRenewalRate = (1 - churnRate) ** 12;
  if (yearlyRenewalRate >= 1) {
    return null;
  }
  const yearlyPlanRevenue = yearlyPrice / (1 - yearlyRenewalRate);

  return monthlyShare * monthlyPlanRevenue + yearlyShare * yearlyPlanRevenue;
}

function calculateLtvPerOnboardingStarter(platformData, platformInputs, arppc) {
  if (arppc == null) return null;

  const onboardingStarted = Number(platformData?.survey_started ?? 0);
  const trialStarted = Number(platformData?.subscriptions ?? 0);
  const trialToSub = parseOverallNumber(platformInputs?.trial_to_sub);

  if (onboardingStarted <= 0 || trialToSub == null) return null;

  const onboardingToPaying =
    (trialStarted / onboardingStarted) * (trialToSub / 100);
  return arppc * onboardingToPaying;
}

function setCalculatedCell(cell, formatted) {
  cell.textContent = formatted.text;
  cell.classList.toggle("na", formatted.na);
}

function createOverallInput(platformId, field, value, inputs, onInputChange) {
  const input = document.createElement("input");
  input.type = "number";
  input.className = "overall-input";
  input.inputMode = "decimal";
  input.step =
    field === "monthly_price" ||
    field === "yearly_price" ||
    field === "cost_per_download"
      ? "0.01"
      : "0.1";
  input.min = "0";
  if (field === "split_monthly_yearly") input.max = "100";
  input.value = value ?? "";
  input.setAttribute("aria-label", `${field} ${platformId}`);
  input.addEventListener("input", () => {
    inputs[platformId][field] = input.value;
    saveOverallInputs(inputs);
    onInputChange();
  });
  return input;
}

function appendOverallNotesCell(tr, note) {
  const td = document.createElement("td");
  td.className = "overall-notes-cell";
  td.textContent = note || "";
  tr.appendChild(td);
}

function appendOverallCalculatedRow(tbody, label, platforms, cellMap, note = "") {
  const tr = document.createElement("tr");
  tr.className = "overall-calculated-row";

  const labelTd = document.createElement("td");
  labelTd.textContent = label;
  labelTd.className = "overall-label";
  tr.appendChild(labelTd);

  for (const { id } of platforms) {
    const td = document.createElement("td");
    td.className = "overall-calculated-cell";
    cellMap.set(id, td);
    tr.appendChild(td);
  }

  appendOverallNotesCell(tr, note);
  tbody.appendChild(tr);
}

function appendOverallEditableRow(tbody, platforms, rowDef, inputs, onInputChange) {
  const tr = document.createElement("tr");
  tr.className = "overall-editable-row";

  const labelTd = document.createElement("td");
  labelTd.textContent = rowDef.label;
  labelTd.className = "overall-label";
  tr.appendChild(labelTd);

  for (const { id } of platforms) {
    const td = document.createElement("td");
    td.className = "overall-input-cell";
    const input = createOverallInput(
      id,
      rowDef.field,
      inputs[id]?.[rowDef.field] ?? "",
      inputs,
      onInputChange,
    );
    td.appendChild(input);
    if (rowDef.suffix) {
      const suffix = document.createElement("span");
      suffix.className = "overall-input-suffix";
      suffix.textContent = rowDef.suffix;
      td.appendChild(suffix);
    }
    tr.appendChild(td);
  }

  appendOverallNotesCell(tr, rowDef.note || "");
  tbody.appendChild(tr);
}

function appendOverallSpacerRow(tbody, platforms) {
  const tr = document.createElement("tr");
  tr.className = "overall-spacer-row";
  tr.setAttribute("aria-hidden", "true");

  const labelTd = document.createElement("td");
  labelTd.innerHTML = "&nbsp;";
  tr.appendChild(labelTd);

  for (const _ of platforms) {
    const td = document.createElement("td");
    td.innerHTML = "&nbsp;";
    tr.appendChild(td);
  }

  appendOverallNotesCell(tr, "");
  tbody.appendChild(tr);
}

function appendOverallEditableRows(tbody, platforms, subscriptionPlanSplit, trialMetrics) {
  const inputs = loadOverallInputs();
  const ltvCells = new Map();
  const arppcCells = new Map();
  const costPerTrialCells = new Map();
  const costPerSubCells = new Map();
  const profitCells = new Map();

  const updateCalculatedRows = () => {
    for (const { id, data } of platforms) {
      const platformInputs = inputs[id] || {};
      const arppc = calculateArppc(platformInputs);
      const ltv = calculateLtvPerOnboardingStarter(data, platformInputs, arppc);
      const costPerDownload = parseOverallNumber(platformInputs.cost_per_download);
      const costPerTrial = calculateCostPerTrial(costPerDownload, data);
      const costPerSub = calculateCostPerSub(costPerDownload, data, platformInputs);

      setCalculatedCell(ltvCells.get(id), formatMoneyValue(ltv));
      setCalculatedCell(arppcCells.get(id), formatMoneyValue(arppc));
      setCalculatedCell(costPerTrialCells.get(id), formatMoneyValue(costPerTrial));
      setCalculatedCell(costPerSubCells.get(id), formatMoneyValue(costPerSub));
      setCalculatedCell(
        profitCells.get(id),
        formatProfitMargin(arppc, costPerSub),
      );
    }
  };

  const editableRows = [
    { label: "Trial -> Sub", field: "trial_to_sub", suffix: "%" },
    { label: "Monthly price", field: "monthly_price", suffix: "$" },
    { label: "Yearly price", field: "yearly_price", suffix: "$" },
    {
      label: "Split Monthly / Yearly",
      field: "split_monthly_yearly",
      suffix: "% monthly",
    },
    { label: "Churn Monthly", field: "churn_monthly", suffix: "%" },
    { label: "Cost per download", field: "cost_per_download", suffix: "$" },
  ];

  for (const rowDef of editableRows.slice(0, 1)) {
    appendOverallEditableRow(tbody, platforms, rowDef, inputs, updateCalculatedRows);
  }

  appendOverallCurrentTrialToSubRow(tbody, platforms, trialMetrics);

  for (const rowDef of editableRows.slice(1, 4)) {
    appendOverallEditableRow(tbody, platforms, rowDef, inputs, updateCalculatedRows);
  }

  appendOverallCurrentSplitRow(tbody, platforms, subscriptionPlanSplit);

  appendOverallEditableRow(
    tbody,
    platforms,
    editableRows[4],
    inputs,
    updateCalculatedRows,
  );

  appendOverallCalculatedRow(
    tbody,
    "LTV",
    platforms,
    ltvCells,
    "ARPPC × (Trial Started / survey started) × (Trial -> Sub / 100)",
  );
  appendOverallCalculatedRow(
    tbody,
    "ARPPC",
    platforms,
    arppcCells,
    "(Split/100 × monthly price / (Churn Monthly/100)) + ((100-Split)/100 × yearly price / (1 - (1 - Churn Monthly/100)^12))",
  );

  appendOverallEditableRow(
    tbody,
    platforms,
    editableRows[5],
    inputs,
    updateCalculatedRows,
  );

  appendOverallCalculatedRow(
    tbody,
    "Cost per Trial",
    platforms,
    costPerTrialCells,
    "Cost per download / (Trial Started / survey started)",
  );
  appendOverallCalculatedRow(
    tbody,
    "Cost per Sub",
    platforms,
    costPerSubCells,
    "Cost per Trial / (Trial -> Sub / 100)",
  );

  appendOverallCalculatedRow(
    tbody,
    "Profit Margin (ARPPC / Cost per Sub)",
    platforms,
    profitCells,
    "ARPPC : Cost per Sub",
  );

  updateCalculatedRows();
}

const OVERALL_STEPS = [
  ["survey_started", "survey started"],
  ["paywall_views", "paywall views"],
  ["plan_selected", "plan selected"],
  ["subscriptions", "Trial Started"],
];

function formatConversionPct(numerator, denominator) {
  if (numerator == null || denominator == null || Number(denominator) === 0) {
    return { text: "—", na: true };
  }
  const pct = (Number(numerator) / Number(denominator)) * 100;
  return {
    text: `${pct.toLocaleString("nl-NL", {
      maximumFractionDigits: 1,
      minimumFractionDigits: 1,
    })}%`,
    na: false,
  };
}

function formatPctValue(value) {
  if (value == null || Number.isNaN(Number(value))) {
    return { text: "—", na: true };
  }
  return {
    text: `${Number(value).toLocaleString("nl-NL", {
      maximumFractionDigits: 1,
      minimumFractionDigits: 1,
    })}%`,
    na: false,
  };
}

function calculateCurrentSplitMonthlyPct(counts) {
  if (!counts) return null;
  const monthly = Number(counts.monthly ?? 0);
  const yearly = Number(counts.yearly ?? 0);
  const total = monthly + yearly;
  if (total <= 0) return null;
  return (monthly / total) * 100;
}

function appendOverallCurrentTrialToSubRow(tbody, platforms, trialMetrics) {
  const tr = document.createElement("tr");
  tr.className = "overall-calculated-row overall-current-trial-to-sub-row";

  const labelTd = document.createElement("td");
  labelTd.textContent = "Current Trial -> Sub";
  labelTd.className = "overall-label";
  tr.appendChild(labelTd);

  const pct = trialMetrics?.trial_to_sub_after_d3?.value ?? null;
  const formatted = formatPctValue(pct);

  for (const { id } of platforms) {
    const td = document.createElement("td");
    td.className = "overall-calculated-cell";
    if (id === "total") {
      td.textContent = formatted.text;
      if (formatted.na) td.classList.add("na");
    } else {
      td.textContent = "—";
      td.classList.add("na");
    }
    tr.appendChild(td);
  }

  appendOverallNotesCell(
    tr,
    "Free trial stats: opens after D3 / trial started (selected range)",
  );
  tbody.appendChild(tr);
}

function appendOverallCurrentSplitRow(tbody, platforms, subscriptionPlanSplit) {
  const tr = document.createElement("tr");
  tr.className = "overall-calculated-row overall-current-split-row";

  const labelTd = document.createElement("td");
  labelTd.textContent = "Current split";
  labelTd.className = "overall-label";
  tr.appendChild(labelTd);

  const splitByPlatform = {
    total: subscriptionPlanSplit?.total || null,
    ios: subscriptionPlanSplit?.ios || null,
    android: subscriptionPlanSplit?.android || null,
  };

  for (const { id } of platforms) {
    const td = document.createElement("td");
    td.className = "overall-calculated-cell";
    const pct = calculateCurrentSplitMonthlyPct(splitByPlatform[id]);
    const formatted = formatPctValue(pct);
    td.textContent = formatted.na ? formatted.text : `${formatted.text} monthly`;
    if (formatted.na) td.classList.add("na");
    tr.appendChild(td);
  }

  appendOverallNotesCell(
    tr,
    "purchase_success: monthly / (monthly + yearly) × 100 (display only)",
  );
  tbody.appendChild(tr);
}

function appendOverallValueCell(tr, value, { conversion = false } = {}) {
  const td = document.createElement("td");
  if (conversion) {
    td.textContent = value.text;
    if (value.na) td.className = "na";
  } else if (value == null) {
    td.textContent = "—";
    td.className = "na";
  } else {
    td.textContent = Number(value).toLocaleString("nl-NL");
  }
  tr.appendChild(td);
}

function renderOverall(overall, overallByPlatform, subscriptionPlanSplit, trialMetrics) {
  const head = document.getElementById("overall-head");
  const tbody = document.getElementById("overall-rows");
  head.replaceChildren();
  tbody.replaceChildren();

  const platforms = [
    { id: "total", label: "totaal", data: overall },
    {
      id: "ios",
      label: "iOS",
      data: (overallByPlatform || []).find(
        (entry) => String(entry.platform || "").toLowerCase() === "ios",
      ),
    },
    {
      id: "android",
      label: "Android",
      data: (overallByPlatform || []).find(
        (entry) => String(entry.platform || "").toLowerCase() === "android",
      ),
    },
  ];

  const splitByPlatform = {
    total: subscriptionPlanSplit?.total || null,
    ios: subscriptionPlanSplit?.ios || null,
    android: subscriptionPlanSplit?.android || null,
  };

  const metricRows = [
    ...OVERALL_STEPS.map(([key, label]) => ({
      label,
      valueFor: (data) => (data ? data[key] : null),
    })),
    {
      label: "monthly trial started",
      valueFor: (_data, platformId) =>
        splitByPlatform[platformId]?.monthly ?? null,
      note: "purchase_success with selected_plan = monthly",
    },
    {
      label: "yearly trial started",
      valueFor: (_data, platformId) =>
        splitByPlatform[platformId]?.yearly ?? null,
      note: "purchase_success with selected_plan = yearly",
    },
    {
      label: "Onboarding -> Paywall",
      valueFor: (data) =>
        formatConversionPct(data?.paywall_views, data?.survey_started),
      conversion: true,
      note: "(paywall views / survey started) × 100",
    },
    {
      label: "Paywall -> Free trial",
      valueFor: (data) =>
        formatConversionPct(data?.subscriptions, data?.paywall_views),
      conversion: true,
      note: "(Trial Started / paywall views) × 100",
    },
    {
      label: "Onboarding -> Trial",
      valueFor: (data) =>
        formatConversionPct(data?.subscriptions, data?.survey_started),
      conversion: true,
      note: "(Trial Started / survey started) × 100",
    },
  ];

  const cornerTh = document.createElement("th");
  cornerTh.textContent = "";
  head.appendChild(cornerTh);

  for (const { label } of platforms) {
    const th = document.createElement("th");
    th.textContent = label;
    head.appendChild(th);
  }

  const notesTh = document.createElement("th");
  notesTh.textContent = "notes";
  notesTh.className = "overall-notes-head";
  head.appendChild(notesTh);

  for (const metricRow of metricRows) {
    const tr = document.createElement("tr");

    const labelTd = document.createElement("td");
    labelTd.textContent = metricRow.label;
    labelTd.className = "overall-label";
    tr.appendChild(labelTd);

    for (const { id, data } of platforms) {
      appendOverallValueCell(tr, metricRow.valueFor(data, id), {
        conversion: metricRow.conversion,
      });
    }

    appendOverallNotesCell(tr, metricRow.note || "");
    tbody.appendChild(tr);
  }

  appendOverallSpacerRow(tbody, platforms);
  appendOverallEditableRows(tbody, platforms, subscriptionPlanSplit, trialMetrics);
}

function renderRows(sources) {
  const tbody = document.getElementById("rows");
  tbody.replaceChildren();

  for (const source of sources) {
    const tr = document.createElement("tr");
    tr.dataset.sourceId = source.id;

    const nameTd = document.createElement("td");
    const label = document.createElement("span");
    label.className = "source-label";
    label.textContent = source.label;
    nameTd.appendChild(label);

    const meta = document.createElement("span");
    meta.className = "source-meta";
    meta.textContent = SOURCE_META[source.id] || source.id;
    nameTd.appendChild(meta);
    tr.appendChild(nameTd);

    for (const key of METRIC_KEYS) {
      appendMetricCell(tr, source[key]);
    }

    tbody.appendChild(tr);
  }
}

function patchSourceRow(source) {
  const tbody = document.getElementById("rows");
  const existing = tbody.querySelector(`tr[data-source-id="${source.id}"]`);
  if (!existing) {
    renderRows([...(window.__lastSources || []).filter((s) => s.id !== source.id), source]);
    return;
  }
  const next = document.createElement("tr");
  next.dataset.sourceId = source.id;

  const nameTd = document.createElement("td");
  const label = document.createElement("span");
  label.className = "source-label";
  label.textContent = source.label;
  nameTd.appendChild(label);
  const meta = document.createElement("span");
  meta.className = "source-meta";
  meta.textContent = SOURCE_META[source.id] || source.id;
  nameTd.appendChild(meta);
  next.appendChild(nameTd);

  for (const key of METRIC_KEYS) {
    appendMetricCell(next, source[key]);
  }
  existing.replaceWith(next);
}

function renderSurveySteps(steps) {
  const tbody = document.getElementById("survey-rows");
  tbody.replaceChildren();
  for (const step of steps || []) {
    const tr = document.createElement("tr");
    const screenTd = document.createElement("td");
    screenTd.textContent = step.screen;
    tr.appendChild(screenTd);
    const viewsTd = document.createElement("td");
    viewsTd.textContent = Number(step.views || 0).toLocaleString("nl-NL");
    tr.appendChild(viewsTd);
    tbody.appendChild(tr);
  }
}

function formatRateFraction(value) {
  if (value == null || Number.isNaN(Number(value))) {
    return { text: "—", na: true };
  }
  const pct = Number(value) * 100;
  return {
    text: `${pct.toLocaleString("nl-NL", {
      maximumFractionDigits: 1,
      minimumFractionDigits: 1,
    })}%`,
    na: false,
  };
}

function renderSurveyMcqOutcomes(rows) {
  const tbody = document.getElementById("mcq-outcome-rows");
  if (!tbody) return;
  tbody.replaceChildren();

  for (const row of rows || []) {
    const tr = document.createElement("tr");

    const stepTd = document.createElement("td");
    stepTd.textContent = row.step_name || "—";
    tr.appendChild(stepTd);

    const answerTd = document.createElement("td");
    answerTd.textContent = row.answer_value || "—";
    tr.appendChild(answerTd);

    const usersTd = document.createElement("td");
    usersTd.textContent = Number(row.users_selected || 0).toLocaleString("nl-NL");
    tr.appendChild(usersTd);

    for (const key of ["subscription_rate", "survey_completion_rate"]) {
      const td = document.createElement("td");
      const formatted = formatRateFraction(row[key]);
      td.textContent = formatted.text;
      if (formatted.na) td.className = "na";
      tr.appendChild(td);
    }

    const subsTd = document.createElement("td");
    subsTd.textContent = Number(row.subscription_count || 0).toLocaleString("nl-NL");
    tr.appendChild(subsTd);

    tbody.appendChild(tr);
  }
}

function renderPlanSelectedRow(rowEl, label, counts) {
  const plans = ["monthly", "quarterly", "yearly", "lifetime"];
  rowEl.replaceChildren();

  const labelTd = document.createElement("td");
  labelTd.textContent = label;
  rowEl.appendChild(labelTd);

  for (const plan of plans) {
    const td = document.createElement("td");
    const value = counts ? counts[plan] : null;
    if (value == null) {
      td.textContent = "—";
      td.className = "na";
    } else {
      td.textContent = Number(value).toLocaleString("nl-NL");
    }
    rowEl.appendChild(td);
  }
}

function renderPlanSelected(planSelected) {
  const selectedRow = document.getElementById("plan-selected-row");
  const uniqueRow = document.getElementById("plan-selected-unique-row");
  if (!selectedRow || !uniqueRow) return;

  const legacyCounts =
    planSelected &&
    planSelected.monthly != null &&
    planSelected.selected == null
      ? planSelected
      : null;

  renderPlanSelectedRow(
    selectedRow,
    "selected",
    legacyCounts || planSelected?.selected || null,
  );
  renderPlanSelectedRow(uniqueRow, "unique", planSelected?.unique || null);
}

const TRIAL_METRIC_ROWS = [
  ["trial_starters", "Trial started"],
  ["app_open_d1", "App open D+1"],
  ["app_open_d2", "App open D+2"],
  ["app_open_d3", "App open D+3"],
  ["app_open_total_after_d3", "Total opens after D3"],
  ["trial_to_sub_after_d3", "Trial -> Sub"],
  ["app_open_d4", "App open D+4"],
  ["app_open_d5", "App open D+5"],
  ["app_open_d6", "App open D+6"],
  ["app_open_d7", "App open D+7"],
  ["app_open_d10", "App open D+10"],
  ["app_open_d14", "App open D+14"],
  ["plan_generations_completed", "Plan generations completed"],
  ["no_trial_came_back_after_12h", "No trial -> Came back after 12 hours"],
  ["no_trial_trial_after_12h", "No trial -> Trial after 12 hours"],
  ["workout_started_trial", "Workout 1 started"],
  ["workout_2nd_started_trial", "Workout 2 started"],
  ["workout_3rd_started_trial", "Workout 3 started"],
  ["workout_5_started_trial", "Workout 5 started"],
  ["workout_7_started_trial", "Workout 7 started"],
  ["workout_10_started_trial", "Workout 10 started"],
  ["workout_15_started_trial", "Workout 15 started"],
  ["workout_20_started_trial", "Workout 20 started"],
  ["active_min_d1", "Active min D+1"],
  ["active_min_d2", "Active min D+2"],
  ["active_min_d3", "Active min D+3"],
  ["notification_open_rate", "Notification opens"],
];

const TRIAL_PCT_METRICS = new Set(["trial_to_sub_after_d3"]);

function renderTrialMetrics(trialMetrics) {
  const tbody = document.getElementById("trial-metrics-rows");
  if (!tbody) return;
  tbody.replaceChildren();

  for (const [key, label] of TRIAL_METRIC_ROWS) {
    if (key === "plan_generations_completed") {
      const headerTr = document.createElement("tr");
      headerTr.className = "trial-metrics-section-row";
      const headerTd = document.createElement("td");
      headerTd.colSpan = 2;
      headerTd.textContent = "No trial (after plan generation)";
      headerTr.appendChild(headerTd);
      tbody.appendChild(headerTr);
    }

    const metric = trialMetrics?.[key] || null;
    const tr = document.createElement("tr");

    const labelTd = document.createElement("td");
    labelTd.textContent = label;
    tr.appendChild(labelTd);

    const valueTd = document.createElement("td");
    if (!metric || metric.value == null) {
      valueTd.textContent = "n/a";
      valueTd.className = "na";
    } else if (TRIAL_PCT_METRICS.has(key)) {
      valueTd.textContent = formatExactPct(metric.value);
    } else {
      valueTd.textContent = Number(metric.value).toLocaleString("nl-NL");
    }
    tr.appendChild(valueTd);

    tbody.appendChild(tr);
  }
}

function formatDayLabel(isoDay) {
  const [y, m, d] = isoDay.split("-").map(Number);
  const date = new Date(Date.UTC(y, m - 1, d));
  return date.toLocaleDateString("nl-NL", {
    day: "numeric",
    month: "short",
    timeZone: "UTC",
  });
}

function formatExactPct(value) {
  if (value == null) return "—";
  return `${Number(value).toLocaleString("nl-NL", {
    maximumFractionDigits: 2,
    minimumFractionDigits: 0,
  })}%`;
}

function formatPctAxis(value) {
  return `${value.toLocaleString("nl-NL", {
    maximumFractionDigits: value < 10 ? 1 : 0,
  })}%`;
}

function niceMaxPct(values) {
  const max = Math.max(0, ...values.filter((v) => v != null));
  if (max <= 0) return 5;
  if (max <= 5) return 5;
  if (max <= 10) return 10;
  if (max <= 25) return 25;
  if (max <= 50) return 50;
  if (max <= 75) return 75;
  return 100;
}

function renderLineChart(containerId, rows, valueKey, stroke) {
  const el = document.getElementById(containerId);
  if (!el) return;
  el.replaceChildren();

  const points = (rows || []).map((row) => ({
    day: row.day,
    value: row[valueKey],
    label: formatDayLabel(row.day),
  }));

  if (!points.length) {
    const empty = document.createElement("p");
    empty.className = "chart-empty";
    empty.textContent = "Geen data in deze periode.";
    el.appendChild(empty);
    return;
  }

  const width = 560;
  const height = 260;
  const pad = { top: 20, right: 18, bottom: 56, left: 56 };
  const plotW = width - pad.left - pad.right;
  const plotH = height - pad.top - pad.bottom;
  const yMax = niceMaxPct(points.map((p) => p.value));
  const n = points.length;
  const xAt = (i) =>
    pad.left + (n === 1 ? plotW / 2 : (i / (n - 1)) * plotW);
  const yAt = (v) => {
    const safe = v == null ? 0 : v;
    return pad.top + plotH - (safe / yMax) * plotH;
  };

  const wrap = document.createElement("div");
  wrap.className = "chart-wrap";

  const tooltip = document.createElement("div");
  tooltip.className = "chart-tooltip";
  tooltip.hidden = true;

  const ns = "http://www.w3.org/2000/svg";
  const svg = document.createElementNS(ns, "svg");
  svg.setAttribute("viewBox", `0 0 ${width} ${height}`);
  svg.setAttribute("preserveAspectRatio", "xMidYMid meet");
  svg.setAttribute("class", "chart-svg");

  // Y-axis title
  const yTitle = document.createElementNS(ns, "text");
  yTitle.setAttribute("class", "chart-axis-title");
  yTitle.setAttribute("fill", "#d7dbe3");
  yTitle.setAttribute("text-anchor", "middle");
  yTitle.setAttribute(
    "transform",
    `translate(14 ${pad.top + plotH / 2}) rotate(-90)`,
  );
  yTitle.textContent = "Conversie (%)";
  svg.appendChild(yTitle);

  // X-axis title
  const xTitle = document.createElementNS(ns, "text");
  xTitle.setAttribute("class", "chart-axis-title");
  xTitle.setAttribute("fill", "#d7dbe3");
  xTitle.setAttribute("text-anchor", "middle");
  xTitle.setAttribute("x", String(pad.left + plotW / 2));
  xTitle.setAttribute("y", String(height - 8));
  xTitle.textContent = "Datum";
  svg.appendChild(xTitle);

  // Y grid + labels
  for (let i = 0; i <= 4; i++) {
    const frac = i / 4;
    const y = pad.top + plotH * (1 - frac);
    const tick = yMax * frac;

    const line = document.createElementNS(ns, "line");
    line.setAttribute("x1", String(pad.left));
    line.setAttribute("x2", String(width - pad.right));
    line.setAttribute("y1", String(y));
    line.setAttribute("y2", String(y));
    line.setAttribute("class", "chart-grid");
    svg.appendChild(line);

    const tickMark = document.createElementNS(ns, "line");
    tickMark.setAttribute("x1", String(pad.left - 4));
    tickMark.setAttribute("x2", String(pad.left));
    tickMark.setAttribute("y1", String(y));
    tickMark.setAttribute("y2", String(y));
    tickMark.setAttribute("class", "chart-tick");
    svg.appendChild(tickMark);

    const text = document.createElementNS(ns, "text");
    text.setAttribute("x", String(pad.left - 8));
    text.setAttribute("y", String(y + 3.5));
    text.setAttribute("text-anchor", "end");
    text.setAttribute("class", "chart-axis");
    text.setAttribute("fill", "#e8eaed");
    text.textContent = formatPctAxis(tick);
    svg.appendChild(text);
  }

  // X baseline
  const xAxis = document.createElementNS(ns, "line");
  xAxis.setAttribute("x1", String(pad.left));
  xAxis.setAttribute("x2", String(width - pad.right));
  xAxis.setAttribute("y1", String(pad.top + plotH));
  xAxis.setAttribute("y2", String(pad.top + plotH));
  xAxis.setAttribute("class", "chart-tick");
  svg.appendChild(xAxis);

  const yAxis = document.createElementNS(ns, "line");
  yAxis.setAttribute("x1", String(pad.left));
  yAxis.setAttribute("x2", String(pad.left));
  yAxis.setAttribute("y1", String(pad.top));
  yAxis.setAttribute("y2", String(pad.top + plotH));
  yAxis.setAttribute("class", "chart-tick");
  svg.appendChild(yAxis);

  const defined = points
    .map((p, i) => ({ ...p, i }))
    .filter((p) => p.value != null);

  if (defined.length >= 2) {
    const pathD = defined
      .map((p, idx) => {
        const cmd = idx === 0 ? "M" : "L";
        return `${cmd}${xAt(p.i).toFixed(1)} ${yAt(p.value).toFixed(1)}`;
      })
      .join(" ");
    const path = document.createElementNS(ns, "path");
    path.setAttribute("d", pathD);
    path.setAttribute("fill", "none");
    path.setAttribute("stroke", stroke);
    path.setAttribute("stroke-width", "2.25");
    path.setAttribute("stroke-linejoin", "round");
    path.setAttribute("stroke-linecap", "round");
    svg.appendChild(path);

    const areaD = `${pathD} L${xAt(defined[defined.length - 1].i).toFixed(1)} ${
      pad.top + plotH
    } L${xAt(defined[0].i).toFixed(1)} ${pad.top + plotH} Z`;
    const area = document.createElementNS(ns, "path");
    area.setAttribute("d", areaD);
    area.setAttribute("fill", stroke);
    area.setAttribute("opacity", "0.12");
    svg.appendChild(area);
  }

  const labelEvery = n > 16 ? 2 : 1;
  const rotateLabels = n > 10;

  function showTooltip(point, svgX, svgY) {
    tooltip.hidden = false;
    tooltip.innerHTML = `<strong>${formatExactPct(point.value)}</strong><span>${point.label}</span>`;
    positionTooltip(svgX, svgY);
  }

  function positionTooltip(svgX, svgY) {
    const svgRect = svg.getBoundingClientRect();
    const wrapRect = wrap.getBoundingClientRect();
    const scaleX = svgRect.width / width;
    const scaleY = svgRect.height / height;
    const left = svgRect.left - wrapRect.left + svgX * scaleX;
    const top = svgRect.top - wrapRect.top + svgY * scaleY;

    const tipW = tooltip.offsetWidth || 72;
    const tipH = tooltip.offsetHeight || 44;
    const gap = 10;

    let x = left;
    let y = top - tipH - gap;
    let placeBelow = false;

    if (y < 4) {
      y = top + gap + 8;
      placeBelow = true;
    }

    const minX = tipW / 2 + 4;
    const maxX = wrapRect.width - tipW / 2 - 4;
    x = Math.min(maxX, Math.max(minX, x));

    tooltip.style.left = `${x}px`;
    tooltip.style.top = `${y}px`;
    tooltip.classList.toggle("is-below", placeBelow);
  }

  function hideTooltip() {
    tooltip.hidden = true;
  }

  points.forEach((p, idx) => {
    const x = xAt(idx);
    const y = p.value != null ? yAt(p.value) : null;

    const tickMark = document.createElementNS(ns, "line");
    tickMark.setAttribute("x1", String(x));
    tickMark.setAttribute("x2", String(x));
    tickMark.setAttribute("y1", String(pad.top + plotH));
    tickMark.setAttribute("y2", String(pad.top + plotH + 4));
    tickMark.setAttribute("class", "chart-tick");
    svg.appendChild(tickMark);

    if (idx % labelEvery === 0 || idx === n - 1) {
      const text = document.createElementNS(ns, "text");
      text.setAttribute("class", "chart-axis");
      text.setAttribute("fill", "#e8eaed");
      text.textContent = p.label;
      if (rotateLabels) {
        text.setAttribute("text-anchor", "end");
        text.setAttribute(
          "transform",
          `translate(${x} ${pad.top + plotH + 14}) rotate(-35)`,
        );
      } else {
        text.setAttribute("x", String(x));
        text.setAttribute("y", String(pad.top + plotH + 16));
        text.setAttribute("text-anchor", "middle");
      }
      svg.appendChild(text);
    }

    if (p.value != null && y != null) {
      const hit = document.createElementNS(ns, "circle");
      hit.setAttribute("cx", String(x));
      hit.setAttribute("cy", String(y));
      hit.setAttribute("r", "14");
      hit.setAttribute("class", "chart-hit");

      const dot = document.createElementNS(ns, "circle");
      dot.setAttribute("cx", String(x));
      dot.setAttribute("cy", String(y));
      dot.setAttribute("r", n === 1 ? "5.5" : "4");
      dot.setAttribute("fill", stroke);
      dot.setAttribute("class", "chart-dot");
      dot.style.pointerEvents = "none";

      hit.addEventListener("mouseenter", () => {
        dot.setAttribute("r", "6.5");
        dot.setAttribute("stroke", "#ffffff");
        dot.setAttribute("stroke-width", "1.5");
        showTooltip(p, x, y);
      });
      hit.addEventListener("mouseleave", () => {
        dot.setAttribute("r", n === 1 ? "5.5" : "4");
        dot.removeAttribute("stroke");
        dot.removeAttribute("stroke-width");
        hideTooltip();
      });

      svg.appendChild(hit);
      svg.appendChild(dot);
    }
  });

  wrap.appendChild(svg);
  wrap.appendChild(tooltip);
  el.appendChild(wrap);
}

function renderDailyConversionCharts(rows) {
  const section = document.querySelector(".charts-section");
  const { from, to } = getSelectedRange();
  const preset = detectPreset(from, to);
  const hide = preset === "today" || preset === "yesterday";

  if (section) {
    section.hidden = hide;
  }
  if (hide) return;

  renderLineChart(
    "chart-onboarding-paywall",
    rows,
    "onboarding_to_paywall_pct",
    "#6ea8fe",
  );
  renderLineChart(
    "chart-paywall-sub",
    rows,
    "paywall_to_sub_pct",
    "#7dd3a7",
  );
  renderLineChart(
    "chart-trial-sub",
    rows,
    "trial_to_sub_after_d3_pct",
    "#c084fc",
  );
}



async function loadAscSearch(from, to, token) {
  try {
    const params = new URLSearchParams({ from, to });
    const res = await fetch(`/api/asc-search?${params}`, { cache: "no-store" });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = await res.json();
    if (token !== loadToken) return;
    if (data.source) {
      patchSourceRow(data.source);
      window.__lastSources = (window.__lastSources || []).map((s) =>
        s.id === data.source.id ? data.source : s,
      );
    }
  } catch (err) {
    if (token !== loadToken) return;
    console.error(err);
    patchSourceRow({
      id: "asc_search",
      label: "App Store Search",
      impressions: { value: null, status: "error" },
      product_page_views: { value: null, status: "error" },
      clicks: { value: null, status: "error" },
      downloads: { value: null, status: "error" },
      app_opens: { value: null, status: "unavailable" },
      paywall_views: { value: null, status: "unavailable" },
      subscriptions: { value: null, status: "unavailable" },
    });
  }
}

async function loadFunnel() {
  const statusEl = document.getElementById("status");
  const refreshBtn = document.getElementById("refresh");
  const applyBtn = document.getElementById("apply-range");
  const { from, to } = getSelectedRange();

  if (!from || !to) {
    statusEl.classList.add("error");
    statusEl.textContent = "Kies een from- en to-datum.";
    return;
  }
  if (to < from) {
    statusEl.classList.add("error");
    statusEl.textContent = "To moet op of na from liggen.";
    return;
  }

  const token = ++loadToken;
  refreshBtn.disabled = true;
  applyBtn.disabled = true;
  statusEl.classList.remove("error");
  statusEl.textContent = "";
  setActivePreset(detectPreset(from, to));

  const params = new URLSearchParams({ from, to });

  try {
    const res = await fetch(`/api/funnel?${params}`, { cache: "no-store" });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = await res.json();
    if (token !== loadToken) return;

    window.__lastSources = data.sources || [];
    renderOverall(
      data.overall || null,
      data.overall_by_platform || [],
      data.subscription_plan_split || null,
      data.trial_metrics || null,
    );
    renderDailyConversionCharts(data.daily_conversions || []);
    renderRows(window.__lastSources);
    renderSurveySteps(data.survey_steps || []);
    renderPlanSelected(data.plan_selected || null);
    renderTrialMetrics(data.trial_metrics || null);
    renderSurveyMcqOutcomes(data.survey_mcq_outcomes || []);

    if (data.error) {
      statusEl.classList.add("error");
      statusEl.textContent = data.error;
    } else if (!data.configured) {
      statusEl.classList.add("error");
      statusEl.textContent =
        "Zet SUPABASE_URL + SUPABASE_ANON_KEY in DASHBOARD/.env";
    } else {
      statusEl.textContent = "";
    }

    // Slow ASC metrics load in the background.
    if (data.asc_deferred !== false) {
      void loadAscSearch(from, to, token);
    }
  } catch (err) {
    if (token !== loadToken) return;
    statusEl.classList.add("error");
    statusEl.textContent =
      "Kon /api/funnel niet laden. Start met: python3 server.py";
    console.error(err);
  } finally {
    if (token === loadToken) {
      refreshBtn.disabled = false;
      applyBtn.disabled = false;
    }
  }
}

function applyPreset(preset) {
  const range = presetRange(preset);
  setRangeInputs(range.from, range.to);
  setActivePreset(preset);
  loadFunnel();
}

document.getElementById("refresh").addEventListener("click", loadFunnel);
document.getElementById("apply-range").addEventListener("click", () => {
  setActivePreset(detectPreset(getSelectedRange().from, getSelectedRange().to));
  loadFunnel();
});

document.querySelectorAll(".preset").forEach((btn) => {
  btn.addEventListener("click", () => applyPreset(btn.dataset.preset));
});

["from", "to"].forEach((id) => {
  document.getElementById(id).addEventListener("change", () => {
    const { from, to } = getSelectedRange();
    setActivePreset(detectPreset(from, to));
  });
});

applyPreset("last_week");
