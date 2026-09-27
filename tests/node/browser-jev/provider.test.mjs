import assert from "node:assert/strict";
import test from "node:test";
import { decideWithCloudflare } from "../../../agent-marketplace/packages/utils-agent/skills/browser-jev/scripts/jev/cloudflare.mjs";

const accountId = "0123456789abcdef0123456789abcdef";
const token = "test-provider-secret";
const input = {
  state: { goal: "Open Filters", controls: [{ id: "filters", name: "Filters" }] },
  questions: {
    operation: {
      type: "choice",
      instructions: "Choose the next operation.",
      criteria: { CLICK: "Click a permitted control", DONE: "The goal is satisfied" },
    },
    click_target: {
      type: "choice",
      instructions: "Choose the control that opens Filters.",
      criteria: { filters: "Filters button", help: "Help link" },
    },
  },
};

function envelope() {
  return {
    result: {
      state: "Completed",
      result: {
        model: "jev-1.13.0",
        answers: {
          operation: { type: "choice", choice: "CLICK", confidence: 0.9, probabilities: { CLICK: 0.95, DONE: 0.05 } },
          click_target: { type: "choice", choice: "filters", confidence: 1, probabilities: { help: 0, filters: 1 } },
        },
        usage: { input_tokens: 495, output_tokens: 67 },
      },
      gatewayMetadata: { keySource: "Unified" },
    },
    success: true,
    errors: [],
    messages: [],
  };
}

test("sends the documented Cloudflare request and returns the completed nested choices", async () => {
  const signal = new AbortController().signal;
  const result = await decideWithCloudflare(input, {
    token, accountId, signal,
    fetchImpl: async (url, options) => {
      assert.equal(url, `https://api.cloudflare.com/client/v4/accounts/${accountId}/ai/run`);
      assert.equal(options.method, "POST");
      assert.equal(options.redirect, "error");
      assert.equal(options.signal, signal);
      assert.equal(new Headers(options.headers).get("authorization"), `Bearer ${token}`);
      assert.equal(new Headers(options.headers).get("content-type"), "application/json");
      assert.deepEqual(JSON.parse(options.body), { model: "typesafe/jev", input });
      return Response.json(envelope());
    },
  });
  assert.deepEqual(result, envelope().result.result);
});

const invalidEnvelopes = [
  ["outer failure", (body) => { body.success = false; }],
  ["queued inference", (body) => { body.result.state = "Queued"; }],
  ["absent completion", (body) => { delete body.result.state; }],
  ["flat response", (body) => { body.result = body.result.result; }],
  ["error with success", (body) => { body.errors = [{ message: token }]; }],
  ["missing answer", (body) => { delete body.result.result.answers.click_target; }],
  ["unknown answer", (body) => { body.result.result.answers.extra = body.result.result.answers.operation; }],
  ["unknown choice", (body) => { body.result.result.answers.operation.choice = "DELETE"; }],
  ["wrong answer type", (body) => { body.result.result.answers.operation.type = "score"; }],
  ["missing probability", (body) => { delete body.result.result.answers.operation.probabilities.DONE; }],
  ["extra probability", (body) => { body.result.result.answers.operation.probabilities.DELETE = 0; }],
  ["negative probability", (body) => { body.result.result.answers.operation.probabilities.DONE = -0.05; }],
  ["nonfinite probability", (body) => { body.result.result.answers.operation.probabilities.CLICK = Infinity; }],
  ["string probability", (body) => { body.result.result.answers.operation.probabilities.CLICK = "0.95"; }],
  ["unnormalized distribution", (body) => { body.result.result.answers.operation.probabilities.CLICK = 0.5; }],
  ["choice is not argmax", (body) => { body.result.result.answers.operation.choice = "DONE"; }],
  ["missing confidence", (body) => { delete body.result.result.answers.operation.confidence; }],
  ["nonfinite confidence", (body) => { body.result.result.answers.operation.confidence = Infinity; }],
  ["confidence exceeds one", (body) => { body.result.result.answers.operation.confidence = 1.1; }],
  ["negative confidence", (body) => { body.result.result.answers.operation.confidence = -1; }],
  ["missing usage", (body) => { delete body.result.result.usage; }],
  ["missing token count", (body) => { delete body.result.result.usage.output_tokens; }],
  ["negative tokens", (body) => { body.result.result.usage.input_tokens = -1; }],
  ["fractional tokens", (body) => { body.result.result.usage.input_tokens = 1.5; }],
  ["unsafe token integer", (body) => { body.result.result.usage.input_tokens = Number.MAX_SAFE_INTEGER + 1; }],
  ["absent resolved model", (body) => { delete body.result.result.model; }],
  ["malformed model", (body) => { body.result.result.model = "<script>"; }],
];

for (const [name, mutate] of invalidEnvelopes) {
  test(`rejects ${name} without exposing response content`, async () => {
    const body = envelope();
    mutate(body);
    body.debug = token;
    await assert.rejects(
      decideWithCloudflare(input, { token, accountId, fetchImpl: async () => Response.json(body) }),
      (error) => error.code === "provider_response_invalid" && !String(error).includes(token),
    );
  });
}

test("returns only validated model, choices, and usage", async () => {
  const body = envelope();
  body.result.result.debug = "raw provider content";
  body.result.result.usage.debug = "raw provider content";
  body.result.result.answers.operation.explanation = "raw provider content";
  assert.deepEqual(
    await decideWithCloudflare(input, { token, accountId, fetchImpl: async () => Response.json(body) }),
    envelope().result.result,
  );
});

for (const status of [302, 401, 402, 429, 500, 503]) {
  test(`reports HTTP ${status} once without returning error bodies`, async () => {
    let requests = 0;
    await assert.rejects(decideWithCloudflare(input, {
      token, accountId,
      fetchImpl: async () => { requests += 1; return new Response(token, { status }); },
    }), { code: `provider_http_${status}`, message: `provider_http_${status}` });
    assert.equal(requests, 1);
  });
}

test("hides transport exception details and does not retry", async () => {
  let requests = 0;
  await assert.rejects(decideWithCloudflare(input, {
    token, accountId,
    fetchImpl: async () => { requests += 1; throw new Error(`${token} provider body`); },
  }), { code: "provider_transport", message: "provider_transport" });
  assert.equal(requests, 1);
});

test("malformed JSON fails without returning provider bytes", async () => {
  await assert.rejects(decideWithCloudflare(input, {
    token, accountId, fetchImpl: async () => new Response(token),
  }), { code: "provider_response_invalid", message: "provider_response_invalid" });
});

test("bounds response bytes even when Content-Length is absent or false", async () => {
  for (const headers of [{}, { "content-length": "1" }]) {
    let canceled = false;
    const stream = new ReadableStream({
      pull(controller) { controller.enqueue(new Uint8Array(300_000)); },
      cancel() { canceled = true; },
    });
    await assert.rejects(decideWithCloudflare(input, {
      token, accountId, fetchImpl: async () => new Response(stream, { headers }),
    }), { code: "provider_response_too_large" });
    assert.equal(canceled, true);
  }
});

test("cancellation before dispatch makes no request", async () => {
  const controller = new AbortController();
  controller.abort(new Error(token));
  let requested = false;
  await assert.rejects(decideWithCloudflare(input, {
    token, accountId, signal: controller.signal,
    fetchImpl: async () => { requested = true; return Response.json(envelope()); },
  }), { code: "provider_aborted", message: "provider_aborted" });
  assert.equal(requested, false);
});

test("cancellation during transport returns without waiting for a response", async () => {
  const controller = new AbortController();
  let dispatch;
  const dispatched = new Promise((resolve) => { dispatch = resolve; });
  const request = decideWithCloudflare(input, {
    token, accountId, signal: controller.signal,
    fetchImpl: () => { dispatch(); return new Promise(() => {}); },
  });
  await dispatched;
  controller.abort(new Error(token));
  await assert.rejects(request, { code: "provider_aborted", message: "provider_aborted" });
});

test("cancellation during an unfinished response cancels the stream", async () => {
  const controller = new AbortController();
  let canceled = false;
  const stream = new ReadableStream({
    pull() { controller.abort(new Error(token)); },
    cancel() { canceled = true; },
  });
  await assert.rejects(decideWithCloudflare(input, {
    token, accountId, signal: controller.signal, fetchImpl: async () => new Response(stream),
  }), { code: "provider_aborted", message: "provider_aborted" });
  assert.equal(canceled, true);
});

for (const [name, options] of [
  ["missing token", { token: "" }],
  ["token header injection", { token: "secret\r\nheader: value" }],
  ["account path injection", { accountId: "account/../../evil" }],
  ["unknown model", { model: "somewhere/other" }],
]) {
  test(`rejects ${name} before I/O`, async () => {
    let requested = false;
    await assert.rejects(decideWithCloudflare(input, {
      token, accountId, ...options,
      fetchImpl: async () => { requested = true; return Response.json(envelope()); },
    }), { code: "provider_config_invalid", message: "provider_config_invalid" });
    assert.equal(requested, false);
  });
}

for (const [name, request] of [
  ["missing state", { questions: input.questions }],
  ["missing questions", { state: input.state }],
  ["empty questions", { state: input.state, questions: {} }],
  ["unsupported question type", { state: input.state, questions: { operation: { type: "score", criteria: [] } } }],
  ["empty choices", { state: input.state, questions: { operation: { type: "choice", instructions: "Choose", criteria: {} } } }],
  ["oversized state", { ...input, state: "x".repeat(1_000_001) }],
]) {
  test(`rejects ${name} before I/O`, async () => {
    let requested = false;
    await assert.rejects(decideWithCloudflare(request, {
      token, accountId,
      fetchImpl: async () => { requested = true; return Response.json(envelope()); },
    }), { code: "provider_request_invalid", message: "provider_request_invalid" });
    assert.equal(requested, false);
  });
}
