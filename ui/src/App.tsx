import { useState, useEffect } from "react";

interface Task {
  id: string;
  title: string;
  description: string;
  status: string;
  created_at: string;
  completed_at: string | null;
}

interface Summary {
  total: number;
  completed: number;
  pending: number;
}

const API_URL = import.meta.env.VITE_API_URL || "";

export default function App() {
  const [tasks, setTasks] = useState<Task[]>([]);
  const [summary, setSummary] = useState<Summary | null>(null);
  const [newTitle, setNewTitle] = useState("");
  const [loading, setLoading] = useState(true);

  const fetchTasks = async () => {
    const res = await fetch(`${API_URL}/api/tasks`);
    const data = await res.json();
    setTasks(data);
    setLoading(false);
  };

  const fetchSummary = async () => {
    const res = await fetch(`${API_URL}/api/tasks/summary`);
    const data = await res.json();
    setSummary(data);
  };

  useEffect(() => {
    fetchTasks();
    fetchSummary();
  }, []);

  const createTask = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newTitle.trim()) return;

    await fetch(`${API_URL}/api/tasks`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ title: newTitle }),
    });

    setNewTitle("");
    fetchTasks();
    fetchSummary();
  };

  const completeTask = async (id: string) => {
    await fetch(`${API_URL}/api/tasks/${id}/complete`, { method: "PATCH" });
    fetchTasks();
    fetchSummary();
  };

  return (
    <div style={{ maxWidth: 720, margin: "2rem auto", fontFamily: "system-ui" }}>
      <h1>📋 Task Manager</h1>

      {summary && (
        <div style={{ display: "flex", gap: "1rem", marginBottom: "1.5rem" }}>
          <div style={cardStyle}>
            <strong>{summary.total}</strong> total
          </div>
          <div style={cardStyle}>
            <strong>{summary.pending}</strong> pending
          </div>
          <div style={cardStyle}>
            <strong>{summary.completed}</strong> done
          </div>
        </div>
      )}

      <form onSubmit={createTask} style={{ display: "flex", gap: "0.5rem", marginBottom: "1.5rem" }}>
        <input
          value={newTitle}
          onChange={(e) => setNewTitle(e.target.value)}
          placeholder="New task..."
          style={{ flex: 1, padding: "0.5rem" }}
        />
        <button type="submit" style={{ padding: "0.5rem 1rem" }}>
          Add Task
        </button>
      </form>

      {loading ? (
        <p>Loading...</p>
      ) : (
        <ul style={{ listStyle: "none", padding: 0 }}>
          {tasks.map((task) => (
            <li
              key={task.id}
              style={{
                padding: "0.75rem",
                borderBottom: "1px solid #eee",
                display: "flex",
                justifyContent: "space-between",
                alignItems: "center",
                opacity: task.status === "completed" ? 0.6 : 1,
              }}
            >
              <div>
                <strong>{task.title}</strong>
                <br />
                <small style={{ color: "#888" }}>
                  {task.status} · {new Date(task.created_at).toLocaleDateString()}
                </small>
              </div>
              {task.status !== "completed" && (
                <button onClick={() => completeTask(task.id)}>✅ Complete</button>
              )}
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

const cardStyle: React.CSSProperties = {
  padding: "1rem",
  border: "1px solid #ddd",
  borderRadius: "8px",
  textAlign: "center",
  flex: 1,
};
