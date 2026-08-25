export function adminGuard(): boolean {
  // VULN SEC-002 counterpart: UI-only authorization based on mutable browser state.
  return window.localStorage.getItem('isAdmin') === 'true';
}
