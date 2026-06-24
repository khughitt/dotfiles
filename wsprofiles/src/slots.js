export function slotName(id, instance) {
  return instance === 1 ? id : `${id}-${instance}`;
}

export function listSlots(profile) {
  const slots = [];
  for (let i = 1; i <= profile.instances; i++) {
    slots.push({ name: slotName(profile.id, i), instance: i });
  }
  return slots;
}

export function buildSlotMap(catalog) {
  const map = new Map();
  for (const profile of catalog.profiles) {
    for (const { name, instance } of listSlots(profile)) {
      map.set(name, { profileId: profile.id, instance });
    }
  }
  return map;
}
