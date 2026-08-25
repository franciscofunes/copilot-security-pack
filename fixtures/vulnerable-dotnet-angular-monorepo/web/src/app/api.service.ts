export class ApiService {
  async loadOrder(orderId: number, selectedTenantId: string): Promise<unknown> {
    // SEC-001 counterpart: tenant selection is supplied by the browser to the API.
    const response = await fetch(`/api/orders/${orderId}?tenantId=${encodeURIComponent(selectedTenantId)}`);
    return response.json();
  }

  async loadAdminUsers(): Promise<unknown> {
    // SEC-002 counterpart: caller assumes the route guard is the authorization boundary.
    const response = await fetch('/api/admin/users');
    return response.json();
  }

  async updateUser(id: number, email: string, isAdmin: boolean): Promise<unknown> {
    // SEC-003 counterpart: privileged field is sent directly from UI state.
    const response = await fetch(`/api/users/${id}`, {
      method: 'PUT',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ email, isAdmin })
    });
    return response.json();
  }
}
