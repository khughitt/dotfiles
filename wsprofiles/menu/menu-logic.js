.pragma library

// Pure selector logic, shared by shell.qml (QML import) and node tests.
// Classic QML JS library: top-level function declarations, no ESM export.

function parseProfiles(text) {
  if (typeof text !== 'string' || text.trim() === '') {
    return { profiles: [], error: 'empty' };
  }
  var data;
  try {
    data = JSON.parse(text);
  } catch (e) {
    return { profiles: [], error: 'invalid json' };
  }
  if (!Array.isArray(data)) return { profiles: [], error: 'not an array' };
  for (var i = 0; i < data.length; i++) {
    var p = data[i];
    if (!p || typeof p !== 'object'
        || typeof p.id !== 'string'
        || typeof p.label !== 'string'
        || typeof p.ring !== 'string') {
      return { profiles: [], error: 'bad profile shape at index ' + i };
    }
  }
  return { profiles: data, error: null };
}

function clampHighlight(highlight, profileCount) {
  if (highlight < 0) return 0;
  if (highlight > profileCount) return profileCount; // profileCount == "+ new" index
  return highlight;
}

function keyToAction(key, modifiers, state) {
  var profiles = state.profiles;
  var highlight = state.highlight;
  var shift = !!(modifiers && modifiers.shift);
  var newIndex = profiles.length; // index of the "+ new" row

  if (key === 'Escape') return { type: 'hide' };
  if (key === '+') return { type: 'editor' };

  if (/^[1-9]$/.test(key)) {
    var idx = Number(key) - 1;
    if (idx >= profiles.length) return null;
    return shift ? { type: 'new', id: profiles[idx].id }
                 : { type: 'open', id: profiles[idx].id };
  }

  if (key === 'Down' || (key === 'Tab' && !shift)) {
    return { type: 'move', highlight: highlight >= newIndex ? 0 : highlight + 1 };
  }
  if (key === 'Up' || (key === 'Tab' && shift)) {
    return { type: 'move', highlight: highlight <= 0 ? newIndex : highlight - 1 };
  }

  if (key === 'Enter') {
    if (highlight === newIndex) return { type: 'editor' };
    var p = profiles[highlight];
    if (!p) return null;
    return shift ? { type: 'new', id: p.id } : { type: 'open', id: p.id };
  }

  return null;
}
