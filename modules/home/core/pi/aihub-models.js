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

function toModel(model) {
  return {
    id: model.id,
    name: model.id,
    input: ["text"],
    contextWindow: 128000,
    maxTokens: 16384,
    cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
  };
}

export default function (pi) {
  pi.registerProvider("aihub-codex", {
    baseUrl,
    api: "openai-responses",
    apiKey: codexApiKey,
    authHeader: true,
    compat: {
      supportsDeveloperRole: false,
      supportsReasoningEffort: false,
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
    compat: {
      thinkingFormat: "deepseek",
      supportsDeveloperRole: false,
    },
    async refreshModels({ signal }) {
      const models = await fetchModels(process.env.AIHUB_DEEPSEEK_API_KEY, signal);
      return models
        .filter((model) => model.id.toLowerCase().includes("deepseek"))
        .map(toModel);
    },
  });
}
