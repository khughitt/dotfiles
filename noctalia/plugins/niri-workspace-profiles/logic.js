.pragma library

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

  if (!Array.isArray(data)) {
    return { profiles: [], error: 'not an array' };
  }

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

function normalizeText(value) {
  return String(value || '').toLowerCase();
}

function resolveProfile(name, profiles) {
  if (typeof name !== 'string') {
    return null;
  }

  for (var i = 0; i < profiles.length; i++) {
    if (profiles[i].id === name) {
      return profiles[i];
    }
  }

  var base = name.replace(/-\d+$/, '');
  if (base === name) {
    return null;
  }

  for (var j = 0; j < profiles.length; j++) {
    if (profiles[j].id === base) {
      return profiles[j];
    }
  }

  return null;
}

function filterWorkspaces(workspaces, opts) {
  var result = workspaces.slice(0, 0);
  var screenName = normalizeText(opts && opts.screenName);
  var focusedOutput = normalizeText(opts && opts.focusedOutput);
  var globalWorkspaces = !!(opts && opts.globalWorkspaces);
  var followFocusedScreen = !!(opts && opts.followFocusedScreen);
  var hideUnoccupied = !!(opts && opts.hideUnoccupied);

  for (var i = 0; i < workspaces.length; i++) {
    var ws = workspaces[i];
    var output = normalizeText(ws && ws.output);
    var matchesScreen = globalWorkspaces
      || (followFocusedScreen && output === focusedOutput)
      || (!followFocusedScreen && output === screenName);

    if (!matchesScreen) {
      continue;
    }

    if (hideUnoccupied && !ws.isOccupied && !ws.isFocused) {
      continue;
    }

    result.push(ws);
  }

  return result;
}

function firstTextCharacter(text, fallback) {
  var value = String(text || '');
  if (value.length === 0) {
    return fallback;
  }
  return value.charAt(0).toUpperCase();
}

function workspaceGlyph(ws) {
  if (ws && ws.idx !== undefined && ws.idx !== null) {
    return String(ws.idx);
  }
  return '.';
}

function buildCells(workspaces, profiles) {
  var result = [];

  for (var i = 0; i < workspaces.length; i++) {
    var ws = workspaces[i];
    var profile = resolveProfile(ws.name, profiles);
    var label = profile ? profile.label : (ws.name || String(ws.idx || ''));
    var icon = profile && typeof profile.icon === 'string' ? profile.icon : '';

    result.push({
      id: ws.id,
      idx: ws.idx,
      name: ws.name || '',
      output: ws.output || '',
      hasProfile: !!profile,
      ring: profile ? profile.ring : null,
      glyph: profile ? (icon.length > 0 ? icon : firstTextCharacter(label, workspaceGlyph(ws))) : workspaceGlyph(ws),
      label: label,
      isFocused: !!ws.isFocused,
      isOccupied: !!ws.isOccupied,
      isUrgent: !!ws.isUrgent,
    });
  }

  return result;
}

function parseHexColor(hex) {
  if (typeof hex !== 'string') {
    return null;
  }

  var value = hex.trim();
  var match3 = /^#([0-9a-fA-F]{3})$/.exec(value);
  if (match3) {
    return {
      r: parseInt(match3[1].charAt(0) + match3[1].charAt(0), 16),
      g: parseInt(match3[1].charAt(1) + match3[1].charAt(1), 16),
      b: parseInt(match3[1].charAt(2) + match3[1].charAt(2), 16),
    };
  }

  var match6 = /^#([0-9a-fA-F]{6})$/.exec(value);
  if (!match6) {
    return null;
  }

  return {
    r: parseInt(match6[1].slice(0, 2), 16),
    g: parseInt(match6[1].slice(2, 4), 16),
    b: parseInt(match6[1].slice(4, 6), 16),
  };
}

function channelLuminance(value) {
  var normalized = value / 255;
  if (normalized <= 0.03928) {
    return normalized / 12.92;
  }
  return Math.pow((normalized + 0.055) / 1.055, 2.4);
}

function pickForeground(ring) {
  var rgb = parseHexColor(ring);
  if (!rgb) {
    return '#ffffff';
  }

  var luminance = 0.2126 * channelLuminance(rgb.r)
    + 0.7152 * channelLuminance(rgb.g)
    + 0.0722 * channelLuminance(rgb.b);
  return luminance > 0.35 ? '#000000' : '#ffffff';
}
