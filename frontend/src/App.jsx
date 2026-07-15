import React, { useEffect, useState } from "react";

const API_URL = import.meta.env.VITE_API_URL || "http://localhost:4000";

export default function App() {
  const [posts, setPosts] = useState([]);
  const [title, setTitle] = useState("");
  const [content, setContent] = useState("");
  const [query, setQuery] = useState("");
  const [status, setStatus] = useState("");

  async function loadPosts() {
    const res = await fetch(`${API_URL}/api/posts`);
    const data = await res.json();
    setPosts(data.posts || []);
  }

  useEffect(() => {
    loadPosts();
  }, []);

  async function handleCreate(e) {
    e.preventDefault();
    if (!title || !content) return;
    setStatus("Submitting...");
    await fetch(`${API_URL}/api/posts`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ title, content }),
    });
    setTitle("");
    setContent("");
    setStatus("Queued! It will appear in a moment (processed async by worker).");
    // give the worker a moment to process, then refresh
    setTimeout(loadPosts, 1500);
  }

  async function handleSearch(e) {
    e.preventDefault();
    if (!query) {
      loadPosts();
      return;
    }
    const res = await fetch(`${API_URL}/api/posts/search?q=${encodeURIComponent(query)}`);
    const data = await res.json();
    setPosts(data.posts || []);
  }

  return (
    <div className="container">
      <h1>Posts</h1>

      <form onSubmit={handleCreate} className="card">
        <h2>New Post</h2>
        <input
          type="text"
          placeholder="Title"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
        />
        <textarea
          placeholder="Content"
          value={content}
          onChange={(e) => setContent(e.target.value)}
        />
        <button type="submit">Create Post</button>
        {status && <p className="status">{status}</p>}
      </form>

      <form onSubmit={handleSearch} className="card">
        <input
          type="text"
          placeholder="Search posts..."
          value={query}
          onChange={(e) => setQuery(e.target.value)}
        />
        <button type="submit">Search</button>
      </form>

      <div className="list">
        {posts.length === 0 && <p>No posts yet.</p>}
        {posts.map((p) => (
          <div key={p.id} className="post">
            <h3>{p.title}</h3>
            <p>{p.content}</p>
            <small>{new Date(p.created_at).toLocaleString()}</small>
          </div>
        ))}
      </div>
    </div>
  );
}
