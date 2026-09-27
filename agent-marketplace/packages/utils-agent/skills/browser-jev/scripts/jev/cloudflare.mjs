const MAX_BYTES = 1_000_000;

function failure(code) {
  return Object.assign(new Error(code), { code });
}

function record(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function sameKeys(value, expected) {
  return record(value)
    && Object.keys(value).length === expected.length
    && expected.every((key) => Object.hasOwn(value, key));
}

function probability(value) {
  return typeof value === "number" && Number.isFinite(value) && value >= 0 && value <= 1;
}

function decode(body, questions) {
  const invalid = () => failure("provider_response_invalid");
  if (!record(body) || body.success !== true || body.result?.state !== "Completed"
      || (body.errors !== undefined && (!Array.isArray(body.errors) || body.errors.length))) {
    throw invalid();
  }
  const result = body.result.result;
  if (!record(result) || typeof result.model !== "string"
      || !/^[a-zA-Z0-9._/-]{1,100}$/.test(result.model)
      || !sameKeys(result.answers, Object.keys(questions)) || !record(result.usage)) {
    throw invalid();
  }
  const usage = {};
  for (const key of ["input_tokens", "output_tokens"]) {
    if (!Number.isSafeInteger(result.usage[key]) || result.usage[key] < 0) throw invalid();
    usage[key] = result.usage[key];
  }
  const answers = Object.fromEntries(Object.entries(questions).map(([name, question]) => {
    const answer = result.answers[name];
    const choices = Object.keys(question.criteria);
    if (!record(answer) || answer.type !== "choice" || !choices.includes(answer.choice)
        || !probability(answer.confidence) || !sameKeys(answer.probabilities, choices)) {
      throw invalid();
    }
    const values = Object.values(answer.probabilities);
    if (!values.every(probability) || Math.abs(values.reduce((sum, value) => sum + value, 0) - 1) > 0.02
        || values.some((value) => value > answer.probabilities[answer.choice])) {
      throw invalid();
    }
    return [name, {
      type: "choice", choice: answer.choice, confidence: answer.confidence,
      probabilities: Object.fromEntries(choices.map((choice) => [choice, answer.probabilities[choice]])),
    }];
  }));
  return { model: result.model, answers, usage };
}

function requestBody(input, model) {
  const invalid = () => failure("provider_request_invalid");
  if (!record(input) || !(record(input.state) || typeof input.state === "string")
      || !record(input.questions) || !Object.keys(input.questions).length) throw invalid();
  for (const question of Object.values(input.questions)) {
    if (!record(question) || question.type !== "choice" || typeof question.instructions !== "string"
        || !record(question.criteria) || !Object.keys(question.criteria).length
        || !Object.values(question.criteria).every((value) => typeof value === "string")) throw invalid();
  }
  let body;
  try {
    body = JSON.stringify({ model, input: { state: input.state, questions: input.questions } });
  } catch {
    throw invalid();
  }
  if (Buffer.byteLength(body) > MAX_BYTES) throw invalid();
  return body;
}

async function abortable(operation, signal) {
  if (!signal) return operation;
  let onAbort;
  const canceled = new Promise((_, reject) => {
    onAbort = () => reject(failure("provider_aborted"));
    signal.addEventListener("abort", onAbort, { once: true });
    if (signal.aborted) onAbort();
  });
  try {
    return await Promise.race([operation, canceled]);
  } finally {
    signal.removeEventListener("abort", onAbort);
  }
}

function discard(body) {
  void body?.cancel().catch(() => {});
}

async function readBody(response, signal) {
  if (!response.body) throw failure("provider_response_invalid");
  if (Number(response.headers.get("content-length")) > MAX_BYTES) {
    discard(response.body);
    throw failure("provider_response_too_large");
  }
  const reader = response.body.getReader();
  const chunks = [];
  let size = 0;
  try {
    while (true) {
      let next;
      try {
        next = await abortable(reader.read(), signal);
      } catch {
        throw failure(signal?.aborted ? "provider_aborted" : "provider_transport");
      }
      if (next.done) break;
      size += next.value.byteLength;
      if (size > MAX_BYTES) throw failure("provider_response_too_large");
      chunks.push(next.value);
    }
  } catch (error) {
    discard(reader);
    throw error;
  } finally {
    reader.releaseLock();
  }
  try {
    return JSON.parse(Buffer.concat(chunks).toString("utf8"));
  } catch {
    throw failure("provider_response_invalid");
  }
}

export async function decideWithCloudflare(input, options = {}) {
  if (!record(options)) throw failure("provider_config_invalid");
  const { token, accountId, model = "typesafe/jev", signal, fetchImpl = globalThis.fetch } = options;
  if (typeof token !== "string" || !/^[\x21-\x7e]{1,4096}$/.test(token)
      || typeof accountId !== "string" || !/^[a-fA-F0-9]{32}$/.test(accountId)
      || model !== "typesafe/jev" || typeof fetchImpl !== "function"
      || (signal !== undefined && !(signal instanceof AbortSignal))) {
    throw failure("provider_config_invalid");
  }
  const body = requestBody(input, model);
  if (signal?.aborted) throw failure("provider_aborted");
  let response;
  try {
    response = await abortable(fetchImpl(
      `https://api.cloudflare.com/client/v4/accounts/${accountId}/ai/run`,
      {
        method: "POST",
        headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
        redirect: "error", signal, body,
      },
    ), signal);
  } catch {
    throw failure(signal?.aborted ? "provider_aborted" : "provider_transport");
  }
  if (!(response instanceof Response)) throw failure("provider_response_invalid");
  if (response.redirected) {
    discard(response.body);
    throw failure("provider_response_invalid");
  }
  if (response.status !== 200) {
    discard(response.body);
    throw failure(`provider_http_${response.status}`);
  }
  return decode(await readBody(response, signal), input.questions);
}
