import Ajv from "ajv";
import addFormats from "ajv-formats";
import { readFileSync } from "fs";
import { join } from "path";
import { describe, it, expect } from "vitest";

const schemaPath = join(__dirname, "../../contracts/checkup-event.schema.json");
const examplePath = join(
  __dirname,
  "../../contracts/examples/checkup-event.example.json",
);

const schema = JSON.parse(readFileSync(schemaPath, "utf-8"));
const example = JSON.parse(readFileSync(examplePath, "utf-8"));

const ajv = new Ajv({ allErrors: true });
addFormats(ajv);
const validate = ajv.compile(schema);

describe("checkup-event.schema.json", () => {
  it("accepts the example payload", () => {
    const valid = validate(example);
    expect(valid).toBe(true);
  });

  it("accepts minimal payload (required fields only)", () => {
    const minimal = {
      event_id: "00000000-0000-0000-0000-000000000001",
      project: "TestProject",
      agent_target: "@checkup-agent",
      page_url: "http://localhost:3000/test",
      user_text: "Something is broken",
      timestamp: "2026-05-08T00:00:00Z",
    };
    expect(validate(minimal)).toBe(true);
  });

  it("accepts payload with empty annotations array", () => {
    const withEmptyAnnotations = {
      event_id: "00000000-0000-0000-0000-000000000002",
      project: "TestProject",
      agent_target: "@checkup-agent",
      page_url: "http://localhost:3000/test",
      user_text: "Minor issue",
      timestamp: "2026-05-08T00:00:00Z",
      annotations: [],
    };
    expect(validate(withEmptyAnnotations)).toBe(true);
  });

  it("rejects payload missing required field (project)", () => {
    const missingProject = {
      event_id: "00000000-0000-0000-0000-000000000003",
      agent_target: "@checkup-agent",
      page_url: "http://localhost:3000/test",
      user_text: "Missing project",
      timestamp: "2026-05-08T00:00:00Z",
    };
    expect(validate(missingProject)).toBe(false);
  });

  it("rejects payload missing required field (event_id)", () => {
    const missingId = {
      project: "TestProject",
      agent_target: "@checkup-agent",
      page_url: "http://localhost:3000/test",
      user_text: "Missing id",
      timestamp: "2026-05-08T00:00:00Z",
    };
    expect(validate(missingId)).toBe(false);
  });

  it("rejects payload missing required field (timestamp)", () => {
    const missingTimestamp = {
      event_id: "00000000-0000-0000-0000-000000000004",
      project: "TestProject",
      agent_target: "@checkup-agent",
      page_url: "http://localhost:3000/test",
      user_text: "Missing timestamp",
    };
    expect(validate(missingTimestamp)).toBe(false);
  });

  it("rejects invalid annotation kind", () => {
    const badAnnotation = {
      event_id: "00000000-0000-0000-0000-000000000005",
      project: "TestProject",
      agent_target: "@checkup-agent",
      page_url: "http://localhost:3000/test",
      user_text: "Bad annotation",
      timestamp: "2026-05-08T00:00:00Z",
      annotations: [{ kind: "invalid_kind", geometry: {}, text: "" }],
    };
    expect(validate(badAnnotation)).toBe(false);
  });

  it("rejects legacy agent_target values", () => {
    const legacy = {
      event_id: "00000000-0000-0000-0000-000000000006",
      project: "TestProject",
      agent_target: "solo-web-deadbeef",
      page_url: "http://localhost:3000/test",
      user_text: "Wrong target",
      timestamp: "2026-05-08T00:00:00Z",
    };
    expect(validate(legacy)).toBe(false);
  });
});
