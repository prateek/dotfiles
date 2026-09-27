import { acp, action, defineFlow } from "acpx/flows";
import { createSkillFlow } from "./skill-rewrite-flows.mjs";

export default createSkillFlow({ acp, action, defineFlow });
