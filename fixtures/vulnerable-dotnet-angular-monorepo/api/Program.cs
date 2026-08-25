var builder = WebApplication.CreateBuilder(args);
builder.Services.AddAuthorization();
builder.Services.AddHttpClient();

var app = builder.Build();
app.UseAuthorization();

var orders = new List<Order>
{
    new(1, "tenant-a", "Starter plan", 120),
    new(2, "tenant-b", "Enterprise plan", 990)
};

var users = new List<AppUser>
{
    new(1, "owner@example.test", "tenant-a", true),
    new(2, "member@example.test", "tenant-b", false)
};

// VULN SEC-001: authenticated caller controls tenantId instead of deriving it from trusted claims.
app.MapGet("/api/orders/{id:int}", (int id, string tenantId) =>
{
    var order = orders.FirstOrDefault(x => x.Id == id && x.TenantId == tenantId);
    return order is null ? Results.NotFound() : Results.Ok(order);
}).RequireAuthorization();

// VULN SEC-002: frontend hides this route from non-admin users, but the API only requires authentication.
app.MapGet("/api/admin/users", () => Results.Ok(users))
    .RequireAuthorization();

// VULN SEC-003: caller can mass-assign the privileged IsAdmin property.
app.MapPut("/api/users/{id:int}", (int id, UserUpdateRequest request) =>
{
    var user = users.FirstOrDefault(x => x.Id == id);
    if (user is null) return Results.NotFound();

    user.Email = request.Email;
    user.IsAdmin = request.IsAdmin;
    return Results.Ok(user);
}).RequireAuthorization();

// VULN SEC-004: arbitrary user-controlled URL is fetched server-side without allow-listing or address validation.
app.MapGet("/api/proxy", async (string url, IHttpClientFactory clients) =>
{
    var client = clients.CreateClient();
    var body = await client.GetStringAsync(url);
    return Results.Text(body);
}).RequireAuthorization();

app.Run();

public sealed record Order(int Id, string TenantId, string Description, decimal Total);

public sealed class AppUser(int id, string email, string tenantId, bool isAdmin)
{
    public int Id { get; } = id;
    public string Email { get; set; } = email;
    public string TenantId { get; } = tenantId;
    public bool IsAdmin { get; set; } = isAdmin;
}

public sealed record UserUpdateRequest(string Email, bool IsAdmin);
