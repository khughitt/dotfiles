import { existsSync, readFileSync, writeFileSync, unlinkSync } from 'node:fs';
import { generateKdl } from './kdl.js';
import { viewModel } from './viewmodel.js';

export function serializeViewModel(catalog) {
  return JSON.stringify(viewModel(catalog), null, 2) + '\n';
}

function readOrNull(path) {
  return existsSync(path) ? readFileSync(path, 'utf8') : null;
}

// "Previous contents" includes absence: a file that did not exist before is
// removed on restore, never left holding a never-accepted config.
function restore(path, prev) {
  if (prev === null) {
    if (existsSync(path)) unlinkSync(path);
  } else {
    writeFileSync(path, prev);
  }
}

function attachRollbackErrors(error, rollbackErrors) {
  if (rollbackErrors.length === 0 || (typeof error !== 'object' && typeof error !== 'function') || error === null) return;
  try {
    Object.defineProperty(error, 'rollbackErrors', {
      value: rollbackErrors,
      configurable: true,
    });
  } catch {
    // Diagnostics must never replace the primary failure.
  }
}

// The KDL and JSON form one artifact transaction. Capture both prior contents
// before writing either; on any failure (a write throwing, or loadConfig
// rejecting) restore both and rethrow so the caller skips the catalog swap.
export async function applyCatalog({ catalog, kdlPath, jsonPath, loadConfig }) {
  const prevKdl = readOrNull(kdlPath);
  const prevJson = readOrNull(jsonPath);
  let reloadAttempted = false;
  try {
    writeFileSync(kdlPath, generateKdl(catalog));
    writeFileSync(jsonPath, serializeViewModel(catalog));
    reloadAttempted = true;
    await loadConfig();
  } catch (e) {
    const rollbackErrors = [];
    for (const [path, prev] of [[kdlPath, prevKdl], [jsonPath, prevJson]]) {
      try {
        restore(path, prev);
      } catch (rollbackError) {
        rollbackErrors.push(rollbackError);
      }
    }
    attachRollbackErrors(e, rollbackErrors);
    // Only re-reload when niri may already have loaded the rejected config. If a
    // write threw before the reload, niri still runs the previous config, which
    // now matches the restored files, so no reload is needed.
    if (reloadAttempted) {
      try { await loadConfig(); } catch { /* caller logs the primary failure */ }
    }
    throw e;
  }
}
