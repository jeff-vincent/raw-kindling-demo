using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

var connectionString = Environment.GetEnvironmentVariable("DATABASE_URL")
    ?? "Host=localhost;Database=analytics;Username=postgres;Password=postgres";

builder.Services.AddDbContext<AnalyticsContext>(opt => opt.UseNpgsql(connectionString));
var app = builder.Build();

using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AnalyticsContext>();
    try { db.Database.EnsureCreated(); }
    catch (Exception ex) { Console.WriteLine($"DB init warning: {ex.Message}"); }
}

app.MapGet("/health", () => Results.Json(new { status = "ok", service = "analytics" }));

app.MapGet("/analytics/events", async (AnalyticsContext db) =>
{
    var events = await db.Events.OrderByDescending(e => e.Timestamp).Take(100).ToListAsync();
    return Results.Json(events);
});

app.MapPost("/analytics/events", async (AnalyticsContext db, [FromBody] AnalyticsEvent evt) =>
{
    evt.Id = Guid.NewGuid();
    evt.Timestamp = DateTime.UtcNow;
    db.Events.Add(evt);
    await db.SaveChangesAsync();
    return Results.Created($"/analytics/events/{evt.Id}", evt);
});

app.MapGet("/analytics/summary", async (AnalyticsContext db) =>
{
    var total = await db.Events.CountAsync();
    var byType = await db.Events.GroupBy(e => e.EventType)
        .Select(g => new { Type = g.Key, Count = g.Count() })
        .ToListAsync();
    return Results.Json(new { totalEvents = total, byType });
});

var port = Environment.GetEnvironmentVariable("PORT") ?? "3007";
app.Run($"http://0.0.0.0:{port}");

public class AnalyticsEvent
{
    public Guid Id { get; set; }
    public string EventType { get; set; } = "";
    public string UserId { get; set; } = "";
    public string Payload { get; set; } = "";
    public DateTime Timestamp { get; set; }
}

public class AnalyticsContext : DbContext
{
    public AnalyticsContext(DbContextOptions<AnalyticsContext> options) : base(options) { }
    public DbSet<AnalyticsEvent> Events { get; set; }
}
