const baseUrl = "https://aihub.pascal-lab.net/v1";
const geminiBaseUrl = "https://aihub.pascal-lab.net/v1beta";
const codexApiKey = "$AIHUB_CODEX_API_KEY";
const deepseekApiKey = "$AIHUB_DEEPSEEK_API_KEY";
const geminiApiKey = "$AIHUB_GEMINI_API_KEY";

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

// Gemini goes through AIHub's native Google endpoint (/v1beta), which speaks the
// Google Generative AI API instead of the OpenAI-compatible one.
async function fetchGeminiModels(apiKey, signal) {
  const response = await fetch(`${geminiBaseUrl}/models`, {
    headers: { "x-goog-api-key": apiKey },
    signal,
  });

  // If the gateway does not expose the native Google listing for this key, fall
  // back to the OpenAI-compatible one, which AIHub also filters by key scope.
  if (!response.ok) {
    const fallback = await fetchModels(apiKey, signal);
    return fallback.filter((model) => (model.id ?? model.name ?? "").includes("gemini"));
  }

  const payload = await response.json();
  // Google's native shape is `{ models: [...] }`; tolerate an OpenAI-style
  // `{ data: [...] }` in case the gateway normalizes the listing.
  return payload.models ?? payload.data ?? [];
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

// Gemini models mirror pi's built-in Google catalog: thinking cannot be turned
// off, and Gemini 3 Pro only exposes low/high.
const geminiModelSpecs = [
  {
    // gemini-4-argon exposes low/medium/high (as in pi's opencode catalog).
    match: /^gemini-4/,
    contextWindow: 1048576,
    maxTokens: 65536,
    thinkingLevelMap: {
      off: null,
      minimal: null,
      low: "low",
      medium: "medium",
      high: "high",
      xhigh: null,
      max: null,
    },
  },
  {
    match: /^gemini-3(\.\d+)?-pro/,
    contextWindow: 1048576,
    maxTokens: 65536,
    thinkingLevelMap: { off: null, minimal: null, low: "LOW", medium: null, high: "HIGH" },
  },
  {
    match: /^gemini-3/,
    contextWindow: 1048576,
    maxTokens: 65536,
    thinkingLevelMap: { off: null },
  },
  {
    match: /^gemini-2\.5/,
    contextWindow: 1048576,
    maxTokens: 65536,
  },
  {
    match: /^gemma/,
    contextWindow: 262144,
    maxTokens: 32768,
    thinkingLevelMap: { off: null, minimal: "MINIMAL", low: null, medium: null, high: "HIGH" },
  },
];
const geminiFallbackSpec = {
  contextWindow: 1048576,
  maxTokens: 65536,
  thinkingLevelMap: { off: null },
};

// Models that exist in the Gemini catalog but are not usable for chat.
const nonChatModel = /embedding|imagen|veo|tts|live|aqa|computer-use/;

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
    api: "openai-responses",
    apiKey: deepseekApiKey,
    authHeader: true,
    // AIHub exposes DeepSeek through the OpenAI Responses-compatible endpoint.
    // Keep the developer-role override for this proxy; Responses handles output
    // token limits and reasoning payloads itself.
    compat: {
      supportsDeveloperRole: false,
    },
    async refreshModels({ signal }) {
      const models = await fetchModels(process.env.AIHUB_DEEPSEEK_API_KEY, signal);
      return models
        .filter((model) => model.id.toLowerCase().includes("deepseek"))
        .map(toModel);
    },
  });

  pi.registerProvider("aihub-gemini", {
    baseUrl: geminiBaseUrl,
    api: "google-generative-ai",
    apiKey: geminiApiKey,
    async refreshModels({ signal }) {
      const models = await fetchGeminiModels(process.env.AIHUB_GEMINI_API_KEY, signal);
      return models
        .filter((model) => {
          const methods = model.supportedGenerationMethods;
          if (Array.isArray(methods) && !methods.includes("generateContent")) return false;
          return !nonChatModel.test(model.name ?? model.id ?? "");
        })
        .map((model) => {
          const name = String(model.name ?? model.id);
          const id = name.replace(/^models\//, "");
          const spec = geminiModelSpecs.find(({ match }) => match.test(id)) ?? geminiFallbackSpec;
          return {
            id,
            name: id,
            reasoning: true,
            input: ["text", "image"],
            contextWindow: Math.min(model.inputTokenLimit ?? spec.contextWindow, spec.contextWindow),
            maxTokens: Math.min(model.outputTokenLimit ?? spec.maxTokens, spec.maxTokens),
            ...(spec.thinkingLevelMap ? { thinkingLevelMap: spec.thinkingLevelMap } : {}),
            cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
          };
        });
    },
  });
}
