const baseUrl = "https://aihub.pascal-lab.net/v1";
const codexApiKey = "$AIHUB_CODEX_API_KEY";
const deepseekApiKey = "$AIHUB_DEEPSEEK_API_KEY";

async function fetchModels(apiKey, signal) {
  const response = await fetch(`${baseUrl}/models`, {
    headers: { Authorization: `Bearer ${apiKey}` },
    signal,
  });
  if (!response.ok) {
    throw new Error(`AIHub model discovery failed: HTTP ${response.status}`);
  }

  const payload = await response.json();
  return payload.data ?? [];
}

// AIHub proxies upstream models that pi already knows, so mirror the real
// windows and reasoning controls instead of flattening every model to one
// 128k/16k non-reasoning default. Values come from pi's built-in catalog
// (the `openai` and `opencode-go` deepseek entries).
const modelSpecs = [
  {
    // deepseek-v4-flash / deepseek-v4.1-flash expose low/high/max thinking.
    match: /^deepseek-v4(\.\d+)?-flash$/,
    contextWindow: 1000000,
    maxTokens: 384000,
    reasoning: true,
    thinkingLevelMap: { minimal: null, low: "low", medium: null, high: "high", max: "max" },
  },
  {
    // deepseek-v4-pro only exposes high/max.
    match: /^deepseek-v4/,
    contextWindow: 1000000,
    maxTokens: 384000,
    reasoning: true,
    thinkingLevelMap: { minimal: null, low: null, medium: null, high: "high", max: "max" },
  },
  {
    // gpt-6-astra cannot disable thinking.
    match: /^gpt-6/,
    contextWindow: 272000,
    maxTokens: 128000,
    reasoning: true,
    thinkingLevelMap: {
      off: null,
      minimal: null,
      low: "low",
      medium: "medium",
      high: "high",
      xhigh: "xhigh",
      max: "max",
    },
  },
  {
    // gpt-5.6-* (and codex-*) use OpenAI reasoning efforts; "off" maps to none.
    match: /^(gpt-5\.6|codex-)/,
    contextWindow: 272000,
    maxTokens: 128000,
    reasoning: true,
    thinkingLevelMap: {
      off: "none",
      minimal: null,
      low: "low",
      medium: "medium",
      high: "high",
      xhigh: "xhigh",
      max: "max",
    },
  },
];
const fallbackSpec = { contextWindow: 128000, maxTokens: 16384, reasoning: false };

function toModel(model) {
  const spec = modelSpecs.find(({ match }) => match.test(model.id)) ?? fallbackSpec;
  return {
    id: model.id,
    name: model.id,
    reasoning: spec.reasoning,
    input: ["text"],
    contextWindow: spec.contextWindow,
    maxTokens: spec.maxTokens,
    ...(spec.thinkingLevelMap ? { thinkingLevelMap: spec.thinkingLevelMap } : {}),
    cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
  };
}

export default function (pi) {
  pi.registerProvider("aihub-codex", {
    baseUrl,
    api: "openai-responses",
    apiKey: codexApiKey,
    authHeader: true,
    // Responses reasoning is controlled per model via thinkingLevelMap; only the
    // developer role needs overriding for this proxy.
    compat: {
      supportsDeveloperRole: false,
    },
    async refreshModels({ signal }) {
      const models = await fetchModels(process.env.AIHUB_CODEX_API_KEY, signal);
      return models
        .filter((model) => model.owned_by === "openai" || model.id.startsWith("gpt-") || model.id.startsWith("codex-"))
        .map(toModel);
    },
  });

  pi.registerProvider("aihub-deepseek", {
    baseUrl,
    api: "openai-completions",
    apiKey: deepseekApiKey,
    authHeader: true,
    // DeepSeek's native chat API: thinking is toggled with `thinking: { type }`,
    // it uses `max_tokens`, and replayed assistant turns need reasoning_content.
    compat: {
      thinkingFormat: "deepseek",
      supportsDeveloperRole: false,
      supportsStore: false,
      maxTokensField: "max_tokens",
      requiresReasoningContentOnAssistantMessages: true,
    },
    async refreshModels({ signal }) {
      const models = await fetchModels(process.env.AIHUB_DEEPSEEK_API_KEY, signal);
      return models
        .filter((model) => model.id.toLowerCase().includes("deepseek"))
        .map(toModel);
    },
  });
}
