// patch-redacted-thinking.mjs
// Postinstall patch: adds redacted_thinking handling to vendored qoder-agent-sdk
import { readFileSync, writeFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const sdkPath = join(__dirname, '..', 'node_modules', 'opencode-qoder-auth', 'dist', 'src', 'vendor', 'qoder-agent-sdk.mjs');

try {
  let code = readFileSync(sdkPath, 'utf-8');

  // Check if already patched
  if (code.includes('redacted_thinking')) {
    console.log('[patch-redacted-thinking] already patched, skipping');
    process.exit(0);
  }

  // Add redacted_thinking case before the default case of parseContentBlock
  const needle = `    default:
      return {
        type: "text",
        text: JSON.stringify(block)
      }`;
  const replacement = `    case "redacted_thinking":
      try {
        const decoded = atob(block.data);
        return { type: "thinking", thinking: decoded };
      } catch(e) {
        return { type: "thinking", thinking: "[redacted thinking]" };
      }
    default:
      return {
        type: "text",
        text: JSON.stringify(block)
      }`;

  if (!code.includes(needle)) {
    console.error('[patch-redacted-thinking] ERROR: could not find parseContentBlock default case');
    process.exit(1);
  }

  code = code.replace(needle, replacement);
  writeFileSync(sdkPath, code, 'utf-8');
  console.log('[patch-redacted-thinking] patched successfully');
} catch (e) {
  console.error('[patch-redacted-thinking] failed:', e.message);
  process.exit(1);
}
