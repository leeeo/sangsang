import { analyzeSample, createReportWorkbook, createSampleWorkbook } from "../src/workbooks";

const result = await analyzeSample();
switch (result.kind) {
  case "valid":
    await Bun.write(new URL("../evidence/sample.xlsx", import.meta.url), createSampleWorkbook());
    await Bun.write(new URL("../evidence/settlement.xlsx", import.meta.url), createReportWorkbook(result));
    console.info("FIXTURES_READY: sample.xlsx and settlement.xlsx");
    break;
  case "invalid":
    throw new TypeError(`The synthetic sample is invalid: ${JSON.stringify(result.issues)}`);
  default: {
    const unreachable: never = result;
    throw new TypeError(`Unexpected settlement: ${String(unreachable)}`);
  }
}
